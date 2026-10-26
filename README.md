# Sideline

Concussion checks and comeback plans for teams, from the phone's camera. A coach runs a short eye and
pupil check right after a hit. The athlete takes a daily check while they recover. A healthcare provider
reviews the measurements and decides each step back to play.

Every test, biomarker and threshold comes from the OculoDx knowledge graph
(sensors → tests → observations → features → biomarkers → models). Sideline asks no questions about
symptoms: decisions rest on measured biomarkers against the athlete's own baseline.

## Who uses it

| Role | Device | What they do |
|---|---|---|
| Coach or instructor | iPhone (iPhone Duo for the demo) | Sees the roster, runs a sideline check after a hit, follows who is due or overdue a test |
| Athlete | iPhone (iPhone 17 Pro Max for the demo) | Records a baseline once, takes the daily check while recovering, sees their biomarkers |
| Healthcare provider | iPad, landscape | Works a case queue, reviews biomarker history, approves each return-to-sport step and signs off |

## The tests

Four camera tests, each from the OculoDx catalog with its real duration:

| Test | Code | What it measures | Biomarkers |
|---|---|---|---|
| Light Response | TST-00006 | How the pupils react to light | PLR amplitude (BMK-00069), pupil asymmetry (BMK-00075) |
| Follow the Dot | TST-00002 | Eye tracking and quick eye jumps | Saccade peak velocity (BMK-00080), smooth pursuit gain (BMK-00084) |
| Hold & Look | TST-00005 | Blinking and gaze steadiness | Blink rate (BMK-00006) |
| Close-up Eye Photo | TST-00001 | The front of each eye, rear camera, for eye injuries | Saved for the clinician |

Dynamic Visual Acuity (TST-00004) runs as practice in the baseline. Its feature is planned in the catalog,
so it does not score yet.

- **Sideline check** (coach, after a hit): Light Response, Follow the Dot, Hold & Look, Close-up Eye Photo.
- **Baseline** (athlete, once): Light Response, Follow the Dot, Hold & Look, Dynamic Visual Acuity.
- **Daily check** (athlete, while recovering): Light Response, Follow the Dot, Hold & Look. About 2 minutes.

Each check walks the athlete through it: a camera-style positioning screen with a countdown, a
"Next up" card before each test, an eyes-tracked indicator, pause, and a retake when the camera
loses the eyes.

## How results are decided

- **Concussion model** (`concussion-oculomotor-screen-v1`): flags saccade velocity below 350 °/s, pursuit
  gain below 0.80, gaze stabilization below 95 °/s, and blink rate below 10 or above 25 per minute.
  Three or more flags give 0.75, one or two give 0.40, none gives 0.05.
- **Emergency rule**: pupil asymmetry above 1.0 mm after a head injury (CND-00260) means call emergency services.
- **Personal baseline**: each athlete records one dated baseline. It covers every sport and team they
  play. Daily results show each biomarker as "At your normal", below normal, or past the threshold.
- **Return to sport**: six graduated steps (2022 Amsterdam consensus). A daily check back at the
  athlete's normal moves them up a step. Two clean checks in a row send a report to the provider, who
  signs before full contact and competition.

## Test schedule

The app tracks when each athlete last tested and whether a test is due:

- Recovering athletes take the daily check every day. It shows as overdue after a missed day.
- New athletes need a baseline within 7 days of joining. Baselines renew after a year.
- Coaches see due and overdue tests on the roster; the team header counts overdue tests.

## Apple Health

Athletes can connect Apple Health from their home screen or account settings.

- **Writes**: each check and the baseline are saved to Health as clinical documents (CDA). Each holds the
  five biomarkers with their catalog codes, today's value, the baseline, the threshold and the step
  decision. Find them in Health under Clinical Documents.
- **Reads**: sleep, heart rate variability, resting heart rate and workouts. Workouts are checked against
  the athlete's current step, for example heart rate kept under the step 2 limit.

## Accounts and settings

- Sign in with Apple, Google or email. New users register as a coach (creates a team and an invite code),
  an athlete (joins with a team code, with parent or guardian consent under 18), or a provider.
- Every user has an account screen: profile photo, name, notifications, privacy, help, sign out.
- Athletes pick every sport they play from 50 sports, each with its own silhouette.

## Demo accounts

Any password works.

| Account | Email | Lands on |
|---|---|---|
| Sid Gupta, instructor, Ridgeline Academy | `sid@ridgelineacademy.com` | Youth and Teens martial arts rosters |
| Andre Hayes, head coach, Chesapeake State | `andre@chessu.edu` | Men's basketball roster |
| Dr. Tom Okafor, team physician | `tom@chessu.edu` | Provider case queue |
| Priya Nair, athlete | `priya@ridgelineacademy.com` | Recovering at step 2, daily check due |
| Jalen Brooks, athlete | `jalen@chessu.edu` | No baseline yet |

Each simulator can launch straight into an account: `-demoAccount coach | player | doctor` or an account
id (`sid`, `hayes`, `okafor`, `priya`, `jalen`). Long-press the Sideline logo on the sign-in screen to
choose the account "Continue with Apple" uses.

## Run

```bash
xcodegen generate                 # after adding files; spec in project.yml
open Sideline.xcodeproj           # pick a simulator, press Run
```

Simulators used for the demo: iPhone Duo (coach), iPhone 17 Pro Max (athlete), iPad Pro 13-inch in
landscape (provider). On iPad and the unfolded Duo, coach and provider screens use a split view.

Player photos live in `pics/` as `firstname.png`; the app uses face-cropped copies in the asset catalog
named `photo-firstname`.

## Code map

- `Graph.swift`: the OculoDx catalog snapshot (tests, biomarkers, thresholds, the concussion model).
- `Models.swift`: accounts, teams, athletes, sessions, the store, and the test schedule.
- `CheckView.swift`: the check flow and its results.
- `RosterView.swift`, `AthleteView.swift`: the coach.
- `AthleteDashboardView.swift`: the athlete.
- `ProviderDashboardView.swift`: the provider.
- `AppleHealthView.swift`, `HealthBridge.swift`: Apple Health.
- `RoleGateView.swift`, `RegistrationView.swift`, `ProfileView.swift`: sign-in, registration, account.
- `Theme.swift`, `Avatar.swift`, `Brand.swift`: design tokens, photos, team art, brand.

## Brand

Design system PDF: `docs/brand/sideline-design-system.pdf`.
- Symbol and lockups: `Brand/*.svg`. In code: `SidelineSymbol` and `SidelineLockup` in `Sideline/Brand.swift`.
- App icon (light, dark, tinted): `Sideline/Assets.xcassets/AppIcon.appiconset`. Regenerate with
  `python3 -I Brand/make_brand_assets.py` (needs Pillow).
- Colors: navy brand, electric blue for "your normal", orange only for alerts.

## Safety language

The app never says "cleared", "safe to play" or "no concussion". It reports measurements, says
"remove from play", and records a provider's decision. Return to play stays with a qualified
healthcare provider.
