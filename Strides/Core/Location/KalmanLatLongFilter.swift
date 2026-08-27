//
//  KalmanLatLongFilter.swift
//  Strides
//
//  Core/Location — GPS noise reducer.
//

import Foundation
import CoreLocation

/// 2D Kalman filter for smoothing noisy GPS points at pedestrian speeds.
final class KalmanLatLongFilter {
    private var minAccuracy: Double
    private var qMetresPerSecond: Double
    private var timestamp: TimeInterval = 0
    private var latitude: Double = 0
    private var longitude: Double = 0
    private var variance: Double = -1

    init(qMetresPerSecond: Double = 3.0, minAccuracy: Double = 1.0) {
        self.qMetresPerSecond = qMetresPerSecond
        self.minAccuracy = minAccuracy
    }

    func process(coordinate: CLLocationCoordinate2D, accuracy: Double, timestamp: TimeInterval) -> CLLocationCoordinate2D {
        let acc = max(accuracy, minAccuracy)

        if variance < 0 {
            // Initialize
            self.timestamp = timestamp
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
            self.variance = acc * acc
            return coordinate
        }

        let duration = timestamp - self.timestamp
        if duration > 0 {
            self.variance += duration * qMetresPerSecond * qMetresPerSecond / 1000.0
            self.timestamp = timestamp
        }

        let k = self.variance / (self.variance + acc * acc)
        self.latitude += k * (coordinate.latitude - self.latitude)
        self.longitude += k * (coordinate.longitude - self.longitude)
        self.variance *= (1.0 - k)

        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}
