//
//  LiveActivityController.swift
//  Strides
//
//  Features/ActivityKit — app-side lifecycle for the running Live Activity.
//  Starts the activity when a run begins, pushes state updates as telemetry
//  changes, and ends it when the run stops.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<RunActivityAttributes>?

    /// Whether the user has Live Activities enabled for this app.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(routeName: String, initialState state: RunActivityAttributes.ContentState) {
        guard isAvailable else { return }
        // Avoid stacking duplicates if one is already live.
        guard activity == nil else {
            update(state)
            return
        }
        let attributes = RunActivityAttributes(routeName: routeName)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("LiveActivity: failed to start — \(error)")
        }
    }

    func update(_ state: RunActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end(finalState state: RunActivityAttributes.ContentState) {
        guard let activity else { return }
        let current = activity
        self.activity = nil
        Task {
            await current.end(.init(state: state, staleDate: nil), dismissalPolicy: .default)
        }
    }
}
