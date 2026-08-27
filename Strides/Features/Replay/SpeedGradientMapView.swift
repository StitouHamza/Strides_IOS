//
//  SpeedGradientMapView.swift
//  Strides
//
//  Features/Replay — reusable static route map whose polyline is colored by the
//  speed at each point. Used by the post-run summary and as the replay base layer.
//

import SwiftUI
import MapKit
import CoreLocation

struct SpeedGradientMapView: View {
    let trajectory: [TrajectoryPoint]
    /// If non-nil, only segments up to this index are drawn (used by the replay trail).
    var drawUpTo: Int? = nil
    var interactive: Bool = true

    @State private var position: MapCameraPosition = .automatic

    private var upperBound: Int {
        let count = trajectory.count
        guard count > 1 else { return 0 }
        let limit = drawUpTo ?? count
        return max(0, min(limit, count) - 1)
    }

    var body: some View {
        Map(position: $position, interactionModes: interactive ? .all : []) {
            ForEach(0..<upperBound, id: \.self) { idx in
                let p1 = trajectory[idx]
                let p2 = trajectory[idx + 1]
                MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                    .stroke(StridesPalette.speedColor(forMPS: p2.speedMPS), lineWidth: 5)
            }
            if let start = trajectory.first {
                Annotation("Start", coordinate: start.coordinate) {
                    Circle()
                        .fill(StridesPalette.electricCyan)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let end = trajectory.last, trajectory.count > 1 {
                Annotation("Finish", coordinate: end.coordinate) {
                    Circle()
                        .fill(StridesPalette.voltageOrange)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }
}

/// Great-circle bearing (degrees, 0 = north) between two coordinates.
func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let deg = atan2(y, x) * 180 / .pi
    return (deg + 360).truncatingRemainder(dividingBy: 360)
}
