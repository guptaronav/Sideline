# Claude Design prompt: Sideline logo, style guide and UI refinement

Paste everything below the line into Claude Design. Attach screenshots of the running app if you have them.

---

You are the lead product designer for **Sideline**, an iPhone app that helps coaches, athletes and healthcare providers handle possible concussions in youth sports. Design a logo, a complete style guide, and refined UI for the three role dashboards. The result should look like a calm, serious, award-worthy health product, not a template.

## What the product is (and is not)
- A coach runs a 20-second eye-tracking and pupil check on the sideline. The check is compared with that athlete's own preseason baseline.
- If something is off, the app says one thing: **"Remove from play."** It never diagnoses, and it never clears an athlete to play.
- Recovery is tracked against the athlete's own baseline range and through six graduated return-to-sport steps.
- Only a healthcare provider can record a return-to-play sign-off. The app records the provider's decision and keeps a log.
- Audience: school coaches and athletic trainers, student athletes (middle and high school), parents, and clinicians. Many people use it in stressful moments, outdoors, with one hand.
- Entered in the Congressional App Challenge, so it must also read clearly in a 3-minute demo video.

## Three roles, one design language
1. **Athlete:** own recovery, today's symptom check-in, steps, plain-language "what happens next". Second person, calm, never alarming.
2. **Coach:** roster grouped by urgency, sideline check, result screen, send-to-provider. Fast, glanceable, large touch targets.
3. **Provider:** case queue, injury-day vs. baseline, recovery trend, decision panel with a deliberate confirmation for sign-off. Dense, precise, clinical but humane.

## Current design direction (keep the spirit, improve the execution)
- Concept: a trainer's clipboard and field markings. Paper, ink, and yard-line hash marks.
- Palette (light / dark): paper `#F2EFE8` / `#111312`, card `#FAF8F3` / `#1A1D1B`, ink `#16181A` / `#EDEAE2`, muted `#6A6E6B` / `#9A9E99`, rule `#D6D1C5` / `#2D312E`, flag (vermilion) `#CF4419` / `#F0693A`, steady (pine) `#2E5B4D` / `#86B8A5`. The capture viewport is always dark `#0E100F`.
- Type: serif display for headlines, SF Pro for body, SF Mono for measurements, uppercase tracked eyebrows.
- Corners are tight (about 4 pt). Hairline rules instead of heavy cards.
- Flag color means "act now" and is used sparingly. Steady means "within the athlete's own range", never "safe to play".

## Deliverable 1: Logo
- A **wordmark** for "Sideline" and a **symbol** that works alone as an app icon.
- Ideas to explore (pick the strongest, show 3 rough directions first, then refine one): a hash-mark sideline crossing an eye or pupil; a pupil that doubles as a yard-line marker; the "i" in Sideline as a vertical field line. It must read at 29 px and at billboard size.
- No clichés: no brain icons, no red crosses, no generic eye icons, no shield or heart shapes, no stock "medical" blue.
- Provide: primary lockup (symbol + wordmark), stacked lockup, symbol only, one-color black, one-color white, reversed on flag color.
- Provide the **iOS app icon** (1024 px, no transparency, full-bleed square) plus how it looks on a home screen in light, dark and tinted modes.
- Give clear-space rules, minimum sizes, and a short "misuse" panel.
- Export as clean SVG paths.

## Deliverable 2: Style guide (one scrollable page)
1. **Brand idea and voice:** three adjectives, a one-line positioning statement, and a tone of voice table by role (athlete, coach, provider).
2. **Language rules:** words we use and never use. Use: "possible signs", "remove from play", "get evaluated", "within your range", "provider sign-off". Never use: "diagnosis", "cleared", "safe to play", "no concussion", "recovered", "healed", "passed".
3. **Color:** tokens for light and dark with semantic names (surface, surface-raised, text-primary, text-secondary, rule, flag, steady, viewport). Show contrast ratios (aim for WCAG AA minimum, AAA for body text). Show how to use color in charts.
4. **Typography:** a type scale with sizes, weights, line heights and tracking. Include Dynamic Type behavior up to the largest accessibility size.
5. **Spacing, grid and layout:** a base unit, a spacing scale, screen margins, and safe areas.
6. **Components:** buttons (solid, outline, destructive-confirm), status tags, list rows, cards/panels, metric range bars, trend chart, six-step ladder, event timeline, symptom score control, role switcher, confirmation dialog, empty states, error states.
7. **Iconography:** a small custom icon set in one stroke weight (about 12 icons), consistent with the hash-mark motif.
8. **Motion:** durations and easing for navigation, the eye-tracking capture, and the "Remove from play" result. Include a reduced-motion alternative for each.
9. **Accessibility:** VoiceOver labels for charts and range bars, color is never the only signal, minimum 44 pt targets, and legible outdoors in sunlight.
10. **SwiftUI handoff:** a table of tokens with names and values, ready to paste into a `Theme.swift` file.

## Deliverable 3: UI refinement
Redesign these screens at iPhone 15 Pro size, in light and dark mode, using the style guide:
- Role gate ("Who's using Sideline?")
- Coach roster
- Sideline check: intro, pursuit capture, light-reflex capture
- Result ("Remove from play.")
- Athlete detail (coach view) and Athlete dashboard
- Symptom check-in
- Provider queue and case view with the decision panel
- Provider report (one-page, printable)

For each screen, list what you changed and why (hierarchy, scannability, one-handed reach, outdoor legibility).

## Quality bar
- It must **not** look generic or AI-generated: no default card grids with uniform shadows, no purple gradients, no emoji, no stock illustrations, no centered hero with a gradient blob.
- Show real hierarchy, intentional spacing rhythm, strong typographic contrast, and restraint with color.
- Every screen should still make sense in grayscale.
- Use realistic content (fictional names, plausible numbers). Label simulated data as simulated.
- Do not claim any clinical accuracy or regulatory status anywhere in the design.

## Output format
Start with a short design rationale (under 150 words). Then the logo exploration, the style guide, and the screens. End with a prioritized list of the 10 highest-impact UI changes to implement first.
