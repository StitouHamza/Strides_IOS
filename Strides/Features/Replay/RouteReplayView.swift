//
//  RouteReplayView.swift
//  Strides
//
//  Features/Replay — interactive 3D flyover playback. A MapKit camera tracks the
//  runner's position along the route with a low pitch for a cinematic cockpit feel,
//  while a growing speed-gradient trail draws behind it.
//

import SwiftUI
import MapKit
import Combine

struct RouteReplayView: View {
    let run: CompletedRun

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var index: Int = 0
    @State private var isPlaying = false

    // ~0.1s per frame; each frame advances one recorded point.
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var pointCount: Int { run.trajectory.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            StridesPalette.canvas.ignoresSafeArea()

            if pointCount > 1 {
                Map(position: $position, interactionModes: []) {
                    ForEach(0..<max(0, index), id: \.self) { idx in
                        let p1 = run.trajectory[idx]
                        let p2 = run.trajectory[idx + 1]
                        MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                            .stroke(StridesPalette.speedColor(forMPS: p2.speedMPS), lineWidth: 6)
                    }
                    if index < pointCount {
                        Annotation("", coordinate: run.trajectory[index].coordinate) {
                            ZStack {
                                Circle().fill(StridesPalette.voltageOrange.opacity(0.3)).frame(width: 34, height: 34)
                                Circle().fill(StridesPalette.voltageOrange).frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .ignoresSafeArea()

                controls
            } else {
                emptyState
            }

            closeButton
        }
        .onReceive(ticker) { _ in
            guard isPlaying, pointCount > 1 else { return }
            advance()
        }
        .onAppear {
            frameCamera(at: 0)
            isPlaying = true
        }
    }

    // MARK: - Playback

    private func advance() {
        if index >= pointCount - 1 {
            isPlaying = false          // reached the finish
            return
        }
        index += 1
        frameCamera(at: index)
    }

    private func frameCamera(at i: Int) {
        guard pointCount > 1 else { return }
        let coord = run.trajectory[min(i, pointCount - 1)].coordinate
        let lookAhead = run.trajectory[min(i + 1, pointCount - 1)].coordinate
        let heading = bearing(from: coord, to: lookAhead)
        withAnimation(.linear(duration: 0.1)) {
            position = .camera(
                MapCamera(centerCoordinate: coord, distance: 420, heading: heading, pitch: 60)
            )
        }
    }

    private func restart() {
        index = 0
        frameCamera(at: 0)
        isPlaying = true
    }

    // MARK: - Subviews

    private var controls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(StridesPalette.voltageOrange)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 6)

            HStack {
                Text(StridesPalette.speedLabel(forMPS: run.trajectory[min(index, pointCount - 1)].speedMPS))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    if index >= pointCount - 1 {
                        restart()
                    } else {
                        isPlaying.toggle()
                    }
                } label: {
                    Image(systemName: index >= pointCount - 1 ? "arrow.counterclockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.title2)
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(StridesPalette.voltageOrange)
                        .clipShape(Circle())
                }
                Spacer()
                Text(String(format: "%.2f km", coveredDistanceKm))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            Spacer()
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "map").font(.largeTitle).foregroundColor(.gray)
            Text("No route recorded")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.white)
            Text("Run with GPS to unlock 3D flyover.")
                .font(.subheadline).foregroundColor(.gray)
        }
    }

    private var progressFraction: CGFloat {
        guard pointCount > 1 else { return 0 }
        return CGFloat(index) / CGFloat(pointCount - 1)
    }

    private var coveredDistanceKm: Double {
        run.distanceKm * Double(progressFraction)
    }
}
