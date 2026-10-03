# Sideline (mock)

A SwiftUI demo of the Sideline concept for video use. **Nothing here is real:** the eye-tracking
capture is scripted, no camera is used, and every athlete and measurement is fictional.

## Run
```bash
sudo xcodebuild -license accept   # once, if Xcode asks
open Sideline.xcodeproj           # pick an iPhone simulator, press Run
```
Regenerate the project after adding files: `xcodegen generate` (spec in `project.yml`).

## Demo path (matches the video roadmap)
1. Roster: Devon K. is already flagged; Marcus T. and Sam O. have a baseline.
2. Tap **Marcus T. → Run sideline check**: pursuit (6 s), light reflex (4.5 s), then the result.
3. Result says only "Remove from play." Tap **Log removal and notify guardian**.
4. Tap **Elena V.**: three in-range days appear, so **Send report to provider** is offered.
5. Open the report: measurements only, provider decision pending.

## Design
Paper, ink, one flag color (vermilion), one steady color (pine). Serif headlines, monospaced
measurements, yard-line hash marks as dividers. Tokens live in `Theme.swift`.

## Safety rules baked into the copy
The app never says "cleared", "safe to play" or "no concussion". It reports measurements,
says "remove from play", and records a provider's decision. Return to play stays with a
qualified healthcare provider.
