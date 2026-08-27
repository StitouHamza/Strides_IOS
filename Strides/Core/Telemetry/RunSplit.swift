//
//  RunSplit.swift
//  Strides
//
//  Core/Telemetry — per-kilometer split computation.
//

import Foundation
import CoreLocation

struct RunSplit: Identifiable, Codable {
    let id = UUID()
    let index: Int                 // 1-based km number
    let distanceKm: Double         // usually 1.0; the final split may be partial
    let durationSeconds: TimeInterval

    /// Pace normalized to seconds per full kilometer.
    var paceSecondsPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return durationSeconds / distanceKm
    }

    var paceFormatted: String {
        guard paceSecondsPerKm > 0 else { return "--:--" }
        let m = Int(paceSecondsPerKm) / 60
        let s = Int(paceSecondsPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    /// A partial trailing split (e.g. the last 0.42 km) is flagged for the UI.
    var isPartial: Bool { distanceKm < 0.999 }
}

enum SplitCalculator {
    /// Walks the trajectory accumulating distance, emitting one split each time a
    /// kilometer boundary is crossed. The crossing timestamp is linearly
    /// interpolated within the segment that straddles the boundary.
    static func compute(from points: [TrajectoryPoint]) -> [RunSplit] {
        guard points.count > 1 else { return [] }

        var splits: [RunSplit] = []
        var cumulativeDistance = 0.0
        var kmIndex = 1
        var lastSplitTime = points[0].timestamp
        var lastSplitDistance = 0.0

        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]

            let segStart = cumulativeDistance
            let segDistance = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            let segEnd = segStart + segDistance

            // A single segment can cross more than one boundary if GPS dropped points.
            while segDistance > 0 && segEnd >= Double(kmIndex) * 1000.0 {
                let boundary = Double(kmIndex) * 1000.0
                let fraction = (boundary - segStart) / segDistance
                let crossTime = a.timestamp.addingTimeInterval(
                    b.timestamp.timeIntervalSince(a.timestamp) * fraction
                )
                let duration = crossTime.timeIntervalSince(lastSplitTime)
                splits.append(RunSplit(index: kmIndex, distanceKm: 1.0, durationSeconds: duration))
                lastSplitTime = crossTime
                lastSplitDistance = boundary
                kmIndex += 1
            }

            cumulativeDistance = segEnd
        }

        // Trailing partial kilometer (ignore sub-50m remainders as GPS jitter).
        let remaining = cumulativeDistance - lastSplitDistance
        if remaining > 50, let last = points.last {
            let duration = last.timestamp.timeIntervalSince(lastSplitTime)
            splits.append(RunSplit(index: kmIndex, distanceKm: remaining / 1000.0, durationSeconds: duration))
        }

        return splits
    }
}
