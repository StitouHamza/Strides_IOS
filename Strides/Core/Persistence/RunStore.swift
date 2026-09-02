//
//  RunStore.swift
//  Strides
//
//  Core/Persistence — lightweight on-disk history of completed runs (JSON in the
//  app's Documents directory). Source of the "personal best" ghost.
//

import Foundation

@Observable
final class RunStore {
    static let shared = RunStore()

    private(set) var runs: [CompletedRun] = []

    /// Runs shorter than this are ignored when choosing a ghost (jitter / test runs).
    private let minGhostDistanceMeters = 300.0

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("strides_runs.json")
    }()

    /// Rolling snapshot of the run currently in progress (crash recovery).
    private let inProgressURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("strides_active_run.json")
    }()

    /// Minimum distance for a recovered run to be worth keeping.
    private let minRecoverableMeters = 100.0

    init() {
        load()
    }

    func save(_ run: CompletedRun) {
        runs.append(run)
        persist()
    }

    /// All stored runs, newest first.
    func allRuns() -> [CompletedRun] {
        runs.sorted { $0.date > $1.date }
    }

    func delete(_ run: CompletedRun) {
        runs.removeAll { $0.id == run.id }
        persist()
    }

    // MARK: - Crash recovery

    /// Overwrites the in-progress snapshot. Called periodically during a run.
    func saveInProgress(_ run: CompletedRun) {
        do {
            let data = try JSONEncoder().encode(run)
            try data.write(to: inProgressURL, options: .atomic)
        } catch {
            print("RunStore: failed to snapshot in-progress run — \(error)")
        }
    }

    func clearInProgress() {
        try? FileManager.default.removeItem(at: inProgressURL)
    }

    /// If a run was interrupted (app killed mid-run), returns it once and clears
    /// the snapshot. Returns nil if there's nothing worth recovering.
    func consumePendingRun() -> CompletedRun? {
        guard FileManager.default.fileExists(atPath: inProgressURL.path) else { return nil }
        defer { clearInProgress() }
        do {
            let data = try Data(contentsOf: inProgressURL)
            let run = try JSONDecoder().decode(CompletedRun.self, from: data)
            return run.totalDistanceMeters >= minRecoverableMeters ? run : nil
        } catch {
            print("RunStore: failed to read pending run — \(error)")
            return nil
        }
    }

    /// Fastest (lowest average pace) qualifying run — the ghost you race against.
    func personalBest() -> CompletedRun? {
        runs
            .filter { $0.trajectory.count > 1 && $0.totalDistanceMeters >= minGhostDistanceMeters }
            .min { $0.avgPaceSecondsPerKm < $1.avgPaceSecondsPerKm }
    }

    func isPersonalBest(_ run: CompletedRun) -> Bool {
        personalBest()?.id == run.id
    }

    // MARK: - Disk

    private func persist() {
        do {
            let data = try JSONEncoder().encode(runs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("RunStore: failed to persist runs — \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            runs = try JSONDecoder().decode([CompletedRun].self, from: data)
        } catch {
            print("RunStore: failed to load runs — \(error)")
        }
    }
}
