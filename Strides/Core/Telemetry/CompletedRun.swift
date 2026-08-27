//
//  CompletedRun.swift
//  Strides
//
//  Core/Telemetry — immutable record of a finished run, produced when a session
//  stops. Feeds the post-run summary, replay, and shareable recap card.
//

import Foundation
import CoreLocation

struct CompletedRun: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let trajectory: [TrajectoryPoint]
    let totalDistanceMeters: Double
    let durationSeconds: TimeInterval
    let avgCadenceSPM: Int
    let splits: [RunSplit]

    var distanceKm: Double { totalDistanceMeters / 1000.0 }

    /// Sum of positive altitude deltas along the route.
    var elevationGainMeters: Double {
        guard trajectory.count > 1 else { return 0 }
        var gain = 0.0
        for i in 1..<trajectory.count {
            let delta = trajectory[i].altitude - trajectory[i - 1].altitude
            if delta > 0 { gain += delta }
        }
        return gain
    }

    var avgPaceSecondsPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return durationSeconds / distanceKm
    }

    var avgPaceFormatted: String {
        guard avgPaceSecondsPerKm > 0 else { return "--:--" }
        let m = Int(avgPaceSecondsPerKm) / 60
        let s = Int(avgPaceSecondsPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// Adapts this record into the value type the Instagram recap card consumes.
    func toRunSummary() -> RunSummary {
        RunSummary(
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            avgPaceFormatted: avgPaceFormatted,
            avgCadenceSPM: avgCadenceSPM,
            elevationGainMeters: elevationGainMeters,
            dateLabel: Self.dateFormatter.string(from: date).uppercased()
        )
    }
}
