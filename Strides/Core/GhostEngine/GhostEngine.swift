//
//  GhostEngine.swift
//  Strides
//
//  Core/GhostEngine — races the live runner against a historical trajectory.
//
//  The engine precomputes, for the ghost run, two parallel profiles indexed by
//  trajectory point: cumulative distance (m) and elapsed time (s) from the start.
//  From these it answers the two questions ghost racing needs, in real time:
//
//   • timeDelta(runnerDistance:runnerElapsed:) — at the distance the runner has
//     covered, how much sooner/later did the ghost reach it? (the "+/- vs ghost")
//   • ghostCoordinate(atElapsed:) — where is the ghost on the map right now?
//

import Foundation
import CoreLocation

final class GhostEngine {
    let ghost: CompletedRun
    private let points: [TrajectoryPoint]
    private let cumulativeDistance: [Double]  // meters, per point
    private let elapsed: [Double]             // seconds since start, per point

    var totalDistanceMeters: Double { cumulativeDistance.last ?? 0 }
    var totalDurationSeconds: Double { elapsed.last ?? 0 }
    var isValid: Bool { points.count > 1 }

    init(ghost: CompletedRun) {
        self.ghost = ghost
        self.points = ghost.trajectory

        var dist: [Double] = []
        var time: [Double] = []
        dist.reserveCapacity(points.count)
        time.reserveCapacity(points.count)

        var running = 0.0
        let start = points.first?.timestamp ?? Date()
        for i in points.indices {
            if i > 0 {
                let a = points[i - 1], b = points[i]
                running += CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
            dist.append(running)
            time.append(points[i].timestamp.timeIntervalSince(start))
        }
        self.cumulativeDistance = dist
        self.elapsed = time
    }

    // MARK: - Queries

    /// Ghost's elapsed time when it had covered `distance` meters.
    func ghostTime(atDistance distance: Double) -> Double {
        guard isValid else { return 0 }
        if distance <= 0 { return 0 }
        if distance >= totalDistanceMeters { return totalDurationSeconds }
        let i = upperIndex(in: cumulativeDistance, value: distance)
        return interpolate(distance,
                           x0: cumulativeDistance[i - 1], x1: cumulativeDistance[i],
                           y0: elapsed[i - 1], y1: elapsed[i])
    }

    /// Distance (m) the ghost had covered at a given elapsed time.
    func ghostDistance(atElapsed t: Double) -> Double {
        guard isValid else { return 0 }
        if t <= 0 { return 0 }
        if t >= totalDurationSeconds { return totalDistanceMeters }
        let i = upperIndex(in: elapsed, value: t)
        return interpolate(t,
                           x0: elapsed[i - 1], x1: elapsed[i],
                           y0: cumulativeDistance[i - 1], y1: cumulativeDistance[i])
    }

    /// Interpolated ghost position at a given elapsed time — the on-map ghost marker.
    func ghostCoordinate(atElapsed t: Double) -> CLLocationCoordinate2D? {
        guard isValid else { return nil }
        if t <= 0 { return points.first?.coordinate }
        if t >= totalDurationSeconds { return points.last?.coordinate }
        let i = upperIndex(in: elapsed, value: t)
        let f = fraction(t, x0: elapsed[i - 1], x1: elapsed[i])
        let a = points[i - 1], b = points[i]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * f,
            longitude: a.longitude + (b.longitude - a.longitude) * f
        )
    }

    /// Seconds the runner is ahead (negative) or behind (positive) the ghost, at
    /// the runner's current covered distance. This is the headline "vs GHOST" number.
    func timeDelta(runnerDistance: Double, runnerElapsed: Double) -> Int {
        guard isValid else { return 0 }
        let ghostElapsedAtDistance = ghostTime(atDistance: runnerDistance)
        return Int((runnerElapsed - ghostElapsedAtDistance).rounded())
    }

    // MARK: - Numeric helpers

    /// First index `i` such that `array[i] >= value` (array is monotonically increasing).
    private func upperIndex(in array: [Double], value: Double) -> Int {
        var lo = 0, hi = array.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if array[mid] < value { lo = mid + 1 } else { hi = mid }
        }
        return max(1, lo)
    }

    private func fraction(_ v: Double, x0: Double, x1: Double) -> Double {
        let denom = x1 - x0
        return denom == 0 ? 0 : (v - x0) / denom
    }

    private func interpolate(_ v: Double, x0: Double, x1: Double, y0: Double, y1: Double) -> Double {
        y0 + (y1 - y0) * fraction(v, x0: x0, x1: x1)
    }
}
