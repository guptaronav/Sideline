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

## Brand
Design system PDF: `docs/brand/sideline-design-system.pdf` (rationale, logo, lockups, app icon, clear space, misuse).
- Symbol and lockups: `Brand/*.svg`. The lockup wordmark is live text until it is outlined for release.
- App icon (light, dark, tinted): `Sideline/Assets.xcassets/AppIcon.appiconset`. Regenerate everything with
  `python3 -I Brand/make_brand_assets.py` (needs Pillow).
- In code: `SidelineSymbol` and `SidelineLockup` in `Sideline/Brand.swift`.
- Rules: the symbol is always ink or paper, never flag-colored; keep the sideline vertical; clear space is one pupil diameter.
- Not yet applied: the PDF's style guide and screens sections were not in the export, so type, color and layout tokens are unchanged.

## Safety rules baked into the copy
The app never says "cleared", "safe to play" or "no concussion". It reports measurements,
says "remove from play", and records a provider's decision. Return to play stays with a
qualified healthcare provider.
