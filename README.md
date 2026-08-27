# Strides

A telemetry-first outdoor running companion for iPhone — a dark, supercar-cockpit
HUD for your runs, with real-time pace gauges, speed-gradient route maps, ghost
racing against your personal best, and Dynamic Island / Lock Screen Live Activities.

## Features

- **Live cockpit HUD** — instant pace gauge, speed-gradient live map, cadence.
- **High-precision GPS** — CoreLocation stream with a Kalman filter to smooth
  pedestrian-speed noise.
- **Ghost Racing** — race your personal-best trajectory in real time; see how many
  seconds you're ahead/behind at the same distance.
- **Post-run recap** — speed-gradient route, per-kilometer splits, and an
  interactive 3D flyover replay (MapKit camera).
- **Shareable recap cards** — 1080×1920 Instagram-Story image via `ImageRenderer`.
- **Live Activities** — Dynamic Island + Lock Screen telemetry while you run.
- **Run history** — persisted locally, with crash-safe autosave and recovery.
- **Pause / resume** with paused-gap handling, and graceful location-permission states.

## Architecture

SwiftUI + Observation (`@Observable`), iOS 18+, clean layering:

```
Strides/
├── Core/
│   ├── Location/     Kalman filter, CoreLocation tracking engine
│   ├── Telemetry/    splits, CompletedRun model
│   ├── GhostEngine/  spatial/temporal trajectory matching
│   └── Persistence/  on-disk run history + personal best
├── Shared/           color palette / hex utilities
├── Features/
│   ├── LiveHUD/       live cockpit dashboard
│   ├── Replay/        gradient map, 3D flyover, run summary
│   ├── History/       past runs list
│   ├── ActivityKit/   Live Activity attributes + lifecycle
│   └── Shareable/     Instagram recap card renderer
└── StridesWidget/     Live Activity widget (Dynamic Island + Lock Screen)
```

## Requirements

- Xcode 17+
- iOS 18.0+
- A physical device for full GPS, cadence, and Live Activity behavior
  (the simulator can feed a route via **Features ▸ Location**).

## Status

Feature-complete MVP. Deferred for a wider release: HealthKit sync, miles/km
toggle, app icon, and on-device testing.
