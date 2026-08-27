//
//  RunningTelemetryManager.swift
//  Strides
//
//  Core/Location — Location & tracking engine.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftUI

struct TrajectoryPoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let speedMPS: Double
    let altitude: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum RunPhase { case idle, running, paused }

@Observable
final class RunningTelemetryManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let kalmanFilter = KalmanLatLongFilter()

    // Public Observables
    var phase: RunPhase = .idle
    /// A session exists (running or paused).
    var isActive: Bool { phase != .idle }
    /// Actively recording (kept for existing HUD/map call sites).
    var isRunning: Bool { phase == .running }

    // Location authorization
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    /// Granted only "While Using" — background tracking will pause when locked.
    var locationWhenInUseOnly: Bool { authorizationStatus == .authorizedWhenInUse }

    var currentSpeedMPS: Double = 0.0
    var rollingPaceFormatted: String = "--:--"
    var totalDistanceMeters: Double = 0.0
    var activeDurationSeconds: TimeInterval = 0.0
    var currentCadenceSPM: Int = 0
    var trajectory: [TrajectoryPoint] = []

    /// Set when a session stops; drives the post-run summary / replay / share flow.
    var lastCompletedRun: CompletedRun?

    // Ghost racing
    var isGhostActive: Bool = false
    var ghostName: String?
    var ghostDeltaSeconds: Int = 0            // negative = ahead of PB, positive = behind
    var ghostDistanceMeters: Double = 0
    var ghostCoordinate: CLLocationCoordinate2D?

    private var timer: Timer?
    private var speedWindow: [Double] = []
    private var sessionStartDate: Date = Date()
    private var cadenceSum: Int = 0
    private var cadenceSamples: Int = 0
    private var ghostEngine: GhostEngine?
    private let runStore = RunStore.shared
    /// After a resume, skip the first distance delta so the paused gap isn't counted.
    private var skipNextDistanceDelta = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 2.0 // Meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func startSession() {
        guard !locationDenied else { return }
        trajectory.removeAll()
        totalDistanceMeters = 0.0
        activeDurationSeconds = 0.0
        cadenceSum = 0
        cadenceSamples = 0
        sessionStartDate = Date()
        lastCompletedRun = nil
        skipNextDistanceDelta = false
        phase = .running

        // Load a ghost (personal best) to race against, if one exists.
        ghostDeltaSeconds = 0
        ghostDistanceMeters = 0
        ghostCoordinate = nil
        if let pb = runStore.personalBest() {
            let engine = GhostEngine(ghost: pb)
            ghostEngine = engine.isValid ? engine : nil
            isGhostActive = engine.isValid
            ghostName = engine.isValid ? "PB · \(pb.avgPaceFormatted)/km" : nil
        } else {
            ghostEngine = nil
            isGhostActive = false
            ghostName = nil
        }

        LiveActivityController.shared.start(
            routeName: "Outdoor Run",
            initialState: currentActivityState()
        )

        locationManager.startUpdatingLocation()
        startPedometer()
        startTimer()
    }

    /// Pause: stop accumulating time/distance and quiet the sensors, but keep the
    /// session and all recorded data intact so it can resume instantly.
    func pauseSession() {
        guard phase == .running else { return }
        phase = .paused
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
        LiveActivityController.shared.update(currentActivityState())
    }

    /// Resume from a pause. The first incoming fix won't add the gap distance.
    func resumeSession() {
        guard phase == .paused else { return }
        phase = .running
        skipNextDistanceDelta = true
        locationManager.startUpdatingLocation()
        startPedometer()
        startTimer()
    }

    private func startPedometer() {
        guard CMPedometer.isCadenceAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let self, let cadence = data?.currentCadence else { return }
            DispatchQueue.main.async {
                let spm = Int(cadence.doubleValue * 60)
                self.currentCadenceSPM = spm
                self.cadenceSum += spm
                self.cadenceSamples += 1
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.activeDurationSeconds += 1.0
            self.updateGhost()
            // Throttle Live Activity refreshes to every 2s to save battery.
            if Int(self.activeDurationSeconds) % 2 == 0 {
                LiveActivityController.shared.update(self.currentActivityState())
            }
            // Crash-safe autosave: snapshot the in-progress run every 10s.
            if Int(self.activeDurationSeconds) % 10 == 0 {
                self.runStore.saveInProgress(self.currentSnapshot())
            }
        }
    }

    /// Builds a CompletedRun from the current live telemetry (used for autosave
    /// snapshots and the final saved run).
    private func currentSnapshot() -> CompletedRun {
        let avgCadence = cadenceSamples > 0 ? cadenceSum / cadenceSamples : currentCadenceSPM
        return CompletedRun(
            date: sessionStartDate,
            trajectory: trajectory,
            totalDistanceMeters: totalDistanceMeters,
            durationSeconds: activeDurationSeconds,
            avgCadenceSPM: avgCadence,
            splits: SplitCalculator.compute(from: trajectory)
        )
    }

    /// Snapshot of the current telemetry as a Live Activity content state.
    private func currentActivityState() -> RunActivityAttributes.ContentState {
        RunActivityAttributes.ContentState(
            currentPace: rollingPaceFormatted,
            distanceKm: totalDistanceMeters / 1000.0,
            ghostDeltaSeconds: ghostDeltaSeconds
        )
    }

    /// Recomputes the live ghost delta and the ghost's map position for the current
    /// covered distance / elapsed time.
    private func updateGhost() {
        guard let engine = ghostEngine else { return }
        ghostDeltaSeconds = engine.timeDelta(
            runnerDistance: totalDistanceMeters,
            runnerElapsed: activeDurationSeconds
        )
        ghostDistanceMeters = engine.ghostDistance(atElapsed: activeDurationSeconds)
        ghostCoordinate = engine.ghostCoordinate(atElapsed: activeDurationSeconds)
    }

    func stopSession() {
        phase = .idle
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil

        let run = currentSnapshot()
        lastCompletedRun = run
        runStore.save(run)
        runStore.clearInProgress()

        LiveActivityController.shared.end(finalState: currentActivityState())

        isGhostActive = false
        ghostEngine = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Ignore fixes while paused (or before a session starts).
        guard phase == .running else { return }

        for location in locations {
            guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 15 else { continue }

            let smoothedCoord = kalmanFilter.process(
                coordinate: location.coordinate,
                accuracy: location.horizontalAccuracy,
                timestamp: location.timestamp.timeIntervalSince1970
            )

            if let last = trajectory.last {
                if skipNextDistanceDelta {
                    // First fix after a resume: anchor here without counting the gap.
                    skipNextDistanceDelta = false
                } else {
                    let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    let currentLoc = CLLocation(latitude: smoothedCoord.latitude, longitude: smoothedCoord.longitude)
                    let delta = currentLoc.distance(from: lastLoc)
                    totalDistanceMeters += delta
                }
            }

            let validSpeed = max(location.speed, 0.0)
            self.currentSpeedMPS = validSpeed

            let point = TrajectoryPoint(
                id: UUID(),
                latitude: smoothedCoord.latitude,
                longitude: smoothedCoord.longitude,
                speedMPS: validSpeed,
                altitude: location.altitude,
                timestamp: location.timestamp
            )
            trajectory.append(point)

            updateRollingPace(speed: validSpeed)
        }
        updateGhost()
    }

    private func updateRollingPace(speed: Double) {
        speedWindow.append(speed)
        if speedWindow.count > 10 { speedWindow.removeFirst() }

        let avgSpeed = speedWindow.reduce(0, +) / Double(speedWindow.count)
        guard avgSpeed > 0.5 else {
            rollingPaceFormatted = "--:--"
            return
        }

        let secondsPerKm = 1000.0 / avgSpeed
        let min = Int(secondsPerKm) / 60
        let sec = Int(secondsPerKm) % 60
        rollingPaceFormatted = String(format: "%d'%02d\"", min, sec)
    }
}
