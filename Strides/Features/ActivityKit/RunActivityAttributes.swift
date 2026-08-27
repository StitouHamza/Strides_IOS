//
//  RunActivityAttributes.swift
//  Strides
//
//  Features/ActivityKit — the Live Activity data contract.
//
//  ⚠️ SHARED TYPE: this file must belong to BOTH the `Strides` app target AND the
//  `StridesWidgetExtension` target. ActivityKit matches the running activity to the
//  widget by this exact type, so the same source has to compile into both modules.
//  (In Xcode: select this file ▸ File Inspector ▸ Target Membership ▸ tick
//  `StridesWidgetExtension`.)
//
//  It intentionally depends only on Foundation + ActivityKit — no SwiftUI, no other
//  app code — so it drops into the widget target without dragging anything along.
//

import Foundation
import ActivityKit

public struct RunActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentPace: String
        public var distanceKm: Double
        public var ghostDeltaSeconds: Int // +/- delta against personal best

        public init(currentPace: String, distanceKm: Double, ghostDeltaSeconds: Int) {
            self.currentPace = currentPace
            self.distanceKm = distanceKm
            self.ghostDeltaSeconds = ghostDeltaSeconds
        }
    }

    public var routeName: String

    public init(routeName: String) {
        self.routeName = routeName
    }
}
