//
//  Replay3DFlyoverView.swift
//  Strides
//

import SwiftUI
import MapKit
import Combine

struct Replay3DFlyoverView: View {
    let run: CompletedRun
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var isPlaying: Bool = true
    @State private var playbackRate: Double = 1.0
    @State private var cameraPosition: MapCameraPosition = .automatic

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            StridesPalette.canvas.ignoresSafeArea()

            // 3D Map View
            Map(position: $cameraPosition) {
                if !run.trajectory.isEmpty {
                    let visibleTrail = Array(run.trajectory.prefix(currentIndex + 1))
                    ForEach(0..<max(0, visibleTrail.count - 1), id: \.self) { idx in
                        let p1 = visibleTrail[idx]
                        let p2 = visibleTrail[idx + 1]
                        MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                            .stroke(StridesPalette.speedColor(forMPS: p2.speedMPS), lineWidth: 5)
                    }

                    if let current = run.trajectory[safe: currentIndex] {
                        Annotation("Runner", coordinate: current.coordinate) {
                            Circle()
                                .fill(StridesPalette.voltageOrange)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: StridesPalette.voltageOrange, radius: 8)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // Tactical Overlay Heads-up
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("TACTICAL REPLAY")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // Playback Control HUD
                VStack(spacing: 12) {
                    // Progress Scrubber
                    Slider(
                        value: Binding(
                            get: { Double(currentIndex) },
                            set: { currentIndex = Int($0) }
                        ),
                        in: 0...Double(max(run.trajectory.count - 1, 1))
                    )
                    .tint(StridesPalette.voltageOrange)

                    HStack {
                        Button {
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 46, height: 46)
                                .background(StridesPalette.elevated)
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button {
                            playbackRate = playbackRate == 1.0 ? 2.0 : (playbackRate == 2.0 ? 4.0 : 1.0)
                        } label: {
                            Text("\(Int(playbackRate))X")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .foregroundColor(StridesPalette.voltageOrange)
                                .frame(width: 46, height: 46)
                                .background(StridesPalette.elevated)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium))
                .overlay(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium).stroke(StridesTheme.hairlineBorder, lineWidth: 1))
                .padding(16)
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying, !run.trajectory.isEmpty else { return }
            let step = Int(1 * playbackRate)
            if currentIndex + step < run.trajectory.count {
                currentIndex += step
                updateCamera(to: run.trajectory[currentIndex])
            } else {
                isPlaying = false
            }
        }
    }

    private func updateCamera(to point: TrajectoryPoint) {
        withAnimation(.easeOut(duration: 0.1)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: point.coordinate,
                    distance: 400,
                    heading: 45,
                    pitch: 65
                )
            )
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
