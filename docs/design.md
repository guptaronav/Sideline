# Sideline: personas, user journeys, and screens

Status: draft, 2026-10-25. The working demo is the Demo tab of `prototype/index.html`. It is the design reference for the Flutter build.

## 1. Intent

Sideline helps coaches, players, and clinicians spot a possible sports concussion early and manage recovery, using eye-movement and pupil measurements from an iPhone's front camera, run through the OculoDx knowledge graph and its concussion model.

It does three things:

1. **Flag.** After a hit, a 2-minute check runs the graph's tests and model. If the result is off, the app gives one instruction: remove from play and get evaluated. If pupils are unequal by more than 1 mm, it says call 911.
2. **Track.** During recovery, the player runs one check a day. The measurements move them through the graduated return-to-learn and return-to-sport steps.
3. **Hand off.** After two clean checks in a row, a licensed clinician gets the report, makes the clearance decision on iPad, and the app records it.

### Hard lines

- Sideline never diagnoses a concussion and never clears a player. A "no change detected" result never reads as "safe to play".
- Results come from catalog thresholds and the model. The player's baseline is shown alongside for context.
- Emergency signs always outrank everything else on screen.
- **Measurements decide, not answers.** Every result comes from the OculoDx knowledge graph: sensors, tests, observations, computers, features, biomarkers, then the model. No decision uses what the player says, because players under-report to keep playing. The coach is never asked to judge a concussion.
- **A consumer sports app, not a business tool.** Coach and player apps are bold and colorful: a dark field background, each school's team colors, italic scoreboard type, jersey-number badges, a "comeback plan" step ring, and a trail of daily check results. Safety states keep fixed meanings across teams: red for 911, orange for remove from play, and no green "all clear". The wording stays exact even where the look is energetic. Nothing celebrates a result the clinician hasn't signed off.
- Clinician iPad views use the same brand on a lighter, calmer layout.

### Non-goals for v1

- Club, youth (under 13), college, and professional sport. US high school only.
- Android. The checks need the iPhone TrueDepth front camera.
- Severe TBI monitoring in EMS or ICU settings (the `severe-tbi-plr` condition). The pupil measurements overlap, but the setting, users, and stakes are different.
- Replacing the clinician's own exam, SCAT6, or imaging.

## 2. Users

Three user groups, two personas each. Parents/guardians and athletic directors receive notifications and records but do not use the app.

| Group | Persona | Role in the app |
|---|---|---|
| Coach | Dana, volunteer head coach, no athletic trainer | Runs sideline checks, logs removals |
| Coach | Marcus, certified athletic trainer | Runs baselines and checks for a whole school, manages recovery |
| Player | Jalen, varsity player who hides symptoms | Records baseline, is checked, does daily recovery checks |
| Player | Priya, player with a second concussion, slow recovery | Daily checks, symptom log, return to school |
| Clinician | Dr. Ruiz, primary-care pediatrician | Reviews report, makes and signs the clearance decision |
| Clinician | Dr. Okafor, sports medicine clinic | Oversees many schools, runs in-clinic checks, manages cases |

## 3. Personas

### Dana Whitfield, volunteer head coach (primary persona)

- **Who:** 41, history teacher, head coach of girls' varsity soccer at a 600-student rural public high school. She/her.
- **Setting:** The school has no athletic trainer, like about 31% of US public high schools ([ATLAS census](https://ryortho.com/2019/12/one-in-three-u-s-high-schools-do-not-have-athletic-trainer/)). At away games she is often the only adult on the bench. Fields have weak cell signal.
- **Device:** Her own iPhone. Has never used a medical app.
- **Goals:** Never miss an injured player. Never be the person who decides a player is fine. Show she followed state law if anyone asks.
- **Fears:** A player gets hurt worse because she missed it. An angry parent when she pulls a starter in a playoff game. Being blamed for a wrong reading.
- **What she needs from Sideline:** One clear instruction she can act on in seconds. Works with no signal. A record she can show the athletic director. Red flags she cannot miss.
- **What failure looks like for her:** The app gives a reassuring result, she sends the player back in, and the player is hurt again. Or the app is so fiddly she stops using it by week three.

### Marcus Bell, certified athletic trainer

- **Who:** 33, ATC, the only full-time athletic trainer at a 1,600-student suburban high school with about 400 athletes across 12 fall teams. He/him.
- **Setting:** On game nights he covers football while soccer plays on the far field. He relies on coaches to send him players. Already keeps records in an athletic training EMR.
- **Goals:** Baseline every athlete before the first game without losing a week to it. Objective data he can hand to physicians. A defensible log. Know the status of every injured athlete at a glance.
- **Fears:** A coach on another field misses a hit. Phone data that is too noisy to trust. Another system that does not talk to his EMR.
- **What he needs:** Bulk baseline sessions (a whole team in one room). A roster view across all teams. Data quality indicators on every reading. Export. The ability to manage return-to-sport stages where his state allows athletic trainers to do so.
- **What failure looks like for him:** Baselines of bad quality that make every later comparison meaningless, or duplicate data entry.

### Jalen Brooks, player who hides symptoms

- **Who:** 17, junior running back, being recruited by two colleges. He/him.
- **Setting:** Uses his own iPhone. His parents are supportive but not technical.
- **Goals:** Play every snap. Keep his recruiting film going.
- **Behavior that matters:** Would not report a headache in a big game. Might try to do badly on his baseline so a later check looks normal, a known problem with baseline testing called sandbagging. Wants to rush through recovery steps.
- **What he needs:** A check that is quick and fair, and results explained without talking down to him. In recovery, a clear view of what stage he is on and why he cannot skip ahead.
- **What the design must protect against:** Sandbagged baselines (quality checks on baseline capture). Under-reported symptoms (the check does not depend on what he says). Gaming daily checks (checks must be his face, with capture quality recorded).
- **What failure looks like:** He returns to contact too soon. Or he sees the app as the enemy and finds ways around it.

### Priya Nair, player with a slow recovery

- **Who:** 15, sophomore midfielder, second concussion in two years. She/her.
- **Setting:** Her mother is closely involved and anxious. Priya is struggling with schoolwork since the injury.
- **Goals:** Understand what is happening to her. Get back to class first, then to soccer. See that she is improving.
- **Fears:** Permanent damage. Falling behind at school. Being pushed back too early.
- **What she needs:** Plain, calm explanations. A daily symptom check-in that takes a minute. Return-to-learn steps alongside return-to-sport steps. Progress shown as distance from her own baseline, with honest wording when it stalls.
- **What failure looks like:** Alarming language makes her anxiety worse, or the app shows only sport steps and ignores school.
- **Note:** She is a minor. Her parent gives consent and receives notifications.

### Dr. Elena Ruiz, primary-care pediatrician

- **Who:** Pediatrician at a community practice. Sees a few concussions a month, mostly families walking in with a clearance form from the school. She/her.
- **Setting:** 15-minute visits. Not a concussion specialist. Does not want another app installed.
- **Goals:** Make a sound clearance decision quickly. Meet her state's written-clearance requirement.
- **Fears:** Clearing a child too early. Data she does not understand being presented as more certain than it is.
- **What she needs:** A one-page report she can read in two minutes: baseline vs. today for each measure, data quality, symptom trend, the return-to-sport stage history, and a plain statement of what the measurements are and their limits. Opens from a secure link in a browser. Sign-off in two taps with her credentials recorded.
- **What failure looks like:** A report that looks like a diagnosis, or one she has to call the school to interpret.

### Dr. Tom Okafor, sports medicine physician

- **Who:** Leads a sports medicine clinic contracted to six high schools. Works with athletic trainers and physical therapists. In season, 20 or more concussion cases a week. He/him.
- **Setting:** Already owns clinic-grade tools. Runs preseason physicals, where baselines could be captured.
- **Goals:** See every open case across his schools. Triage who needs an in-person visit. Run checks in clinic. Assign return-to-sport stages remotely. Sign off in batches.
- **Fears:** Alert fatigue. Phone data of unknown accuracy driving decisions.
- **What he needs:** A multi-school case list. Raw measurements with quality indicators, not just green and red. In-clinic check mode on a clinic iPhone. Stage assignment. Export to his EMR.
- **What failure looks like:** A dashboard full of flags he cannot trust, so he ignores it.

## 4. Grounding facts the design depends on

Sources are listed so each claim can be checked. "Secondary" means taken from a summary, not the primary text.

**Law and protocol**
- All 50 states and DC have a youth sports concussion law. The common elements are annual education with a signed information sheet, removal from play when a concussion is suspected, and written clearance by a licensed provider before return ([WA Lystedt law summary](https://lawfilesext.leg.wa.gov/biennium/2009-10/Htm/Bill%20Reports/House/1824.E%20HBR%20APH%2009.htm), secondary).
- Who may clear varies by state. Some states require a physician; others also allow NPs, PAs, or athletic trainers, sometimes under physician supervision ([Network for Public Health Law summary](https://www.networkforphl.org/wp-content/uploads/2019/11/Summary-of-State-Laws-Addressing-Concussions-in-Youth-Sports-5-28-19.pdf), secondary). **The app must treat the allowed clearing credential as a per-state setting.** A full state table is still to be built.
- Return to sport (Amsterdam 2022, secondary summary): 1 symptom-limited activity, 2 aerobic exercise (light, then moderate), 3 individual sport-specific exercise, 4 non-contact training, 5 full-contact practice, 6 return to sport. At least 24 hours per step ([CDC](https://cdc.gov/heads-up/guidelines/returning-to-sports.html)). Step back if symptoms return.
- Return to learn: 1 relative rest for 24 to 48 hours, 2 school-type activities at home, 3 part-time school, 4 full-time school. Return to learn should be complete before return-to-sport steps 4 to 6 (secondary summary).
- The exact point in the Amsterdam sequence where written clearance is required is not verified. **My call for the design: clearance is required before step 5 (full contact), and state law can require it earlier.**

**Emergency signs** ([CDC HEADS UP](https://www.cdc.gov/heads-up/signs-symptoms/index.html)): seizures; cannot recognize people or places; repeated vomiting; unusual behavior, increasing confusion or agitation; loss of consciousness, increasing drowsiness, or cannot be woken; slurred speech, weakness, numbness, or poor coordination; a headache that gets worse and does not go away; **one pupil larger than the other**, or double vision.

**Regulation and privacy**
- EyeBOX, a clinic eye-tracking device, was granted FDA De Novo in 2018 under product code QEA, 21 CFR 882.1455, "brain injury adjunctive interpretive oculomotor assessment aid" ([FDA](https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfPMN/denovo.cfm?ID=DEN170091)). Sideline flags possible concussion from eye signals for lay users, so it is very likely a regulated device, whatever the "never diagnoses" wording says. Screen copy in the prototype is written as if it will be reviewed by FDA.
- Records a public school holds fall under FERPA; records a clinic holds fall under HIPAA ([ED/HHS joint guidance](https://studentprivacy.ed.gov/resources/joint-guidance-application-ferpa-and-hipaa-student-health-records)). The design keeps school-side and clinic-side data roles distinct.

**Scale of the problem**
- About 40 to 50% of high school concussions go unreported, supported by several studies (secondary).
- The "1.6 to 3.8 million a year" figure counts sports and recreation traumatic brain injuries, not only concussions. Pitch copy should say that.

## 5. What OculoDx can do today

Checked against the iOS code in `apps/sensors-testing/OculoSense` on 2026-10-25.

| Test | Duration | Measures | State |
|---|---|---|---|
| Light Response | 15 s, three screen flashes | Pupil light reflex (amplitude, latency), pupil asymmetry | Works. Noise floor about 0.15 to 0.3 mm. |
| Follow the Dot | 75 s | Smooth pursuit gain, a rough saccade velocity, fixation stability | Works. Saccade velocity is crude; there is no step-target stimulus. |
| Hold & Look | 30 s | Blink rate, fixation stability, pupil asymmetry | Works. |
| DVA/GST (head-turn) | about 60 s | Gaze stabilization | Test screen works. The gaze-stabilization measurement itself is not built. |

Not built yet, and needed by Sideline:
- **Per-player baseline comparison.** Every threshold in the code and catalog today is a population norm.
- **A concussion model on the phone.** The catalog model `concussion-oculomotor-screen-v1` is planned and unvalidated, uses population cut-offs, and ignores the pupil measures the condition lists as required.
- **A chained concussion check.** The screening runner exists for other conditions but has no concussion entry, and it cannot chain DVA/GST yet.

### Checks, built from the knowledge graph

Source: `apps/admin-portal/data/research`, commit 785e3dff. Durations are the catalog's own.

| Test | Code | Seconds | Sensors | Biomarkers produced (feature status) |
|---|---|---|---|---|
| Light Response | TST-00006 | 15 | SRC-00019 TrueDepth camera, SRC-00018 IR depth, SRC-00016 OLED | BMK-00075 pupil asymmetry, BMK-00069 PLR amplitude, BMK-00071 PLR latency, BMK-00017 constriction velocity (all computed) |
| Follow the Dot | TST-00002 | 75 | SRC-00003 ARKit gaze, SRC-00002 ARKit face, SRC-00016 OLED | BMK-00080 saccade peak velocity, BMK-00084 smooth pursuit gain (computed) |
| Hold and Look | TST-00005 | 30 | TrueDepth, ARKit face and gaze | BMK-00006 blink rate, BMK-00024 fixation stability (computed) |
| Head Turn (DVA/GST) | TST-00004 | 60 | SRC-00003, SRC-00016 | BMK-00159 gaze stabilization (FTR-00162 planned, no computer) |

- **Sideline check:** Light Response, Follow the Dot, Hold and Look. 120 s of capture. Hold and Look is required because blink rate is a model input.
- **Full check** (baselines, daily recovery, in clinic): the sideline tests plus Head Turn. 180 s of capture. Head Turn is recorded but cannot score until FTR-00162 is built.
- Read Aloud is not used: no TBI condition in the graph references it.

### Decision rules

The model is `concussion-oculomotor-screen-v1`, run exactly as the catalog defines it. It has four domains: saccade < 350°/s, pursuit gain < 0.80, gaze stabilization < 95°/s, and blink < 10 or > 25 per minute. Three or more flags give probability 0.75, one or two give 0.40, and none gives 0.05. The vestibular domain cannot flag yet.

Sideline product rules on top of the graph (these are not catalog content):

1. **Could not measure:** any sideline biomarker returns null. The feature `missing_policy` returns null when capture quality is too low.
2. **Call 911:** pupil asymmetry (BMK-00075) over 1.0 mm. This is the CND-00260 red flag "anisocoria over 1 mm".
3. **Remove from play:** model probability 0.40 or higher, or a CND-00066 required biomarker outside its catalog reference range.
4. **No change detected:** otherwise. It never reads as safe.

A **Call 911** button stays on screen for what the coach can see and no sensor can measure: a seizure, a player knocked out, repeated vomiting, or loss of movement.

### Recovery rules (product rules)

- Return-to-learn and return-to-sport step 2 start after 48 hours, by time alone (Amsterdam 2022 relative rest).
- After that, a daily full check with no model flags and in-range pupils moves both ladders up one step the next day. A check with 3 or more flags moves them back one step. Anything in between holds.
- Sport step 4 needs full-time school. Step 5 needs a clinician's signature.
- **Ready for review:** two consecutive clean checks after step 4 has started.

### Baseline

The catalog has no per-athlete baseline model; every threshold is a population norm. So decisions use catalog thresholds, and the athlete's baseline is shown for context only. The baseline also has one decision role: a baseline that already trips the model, or has required biomarkers out of range with good capture, is flagged as possible low effort (sandbagging), and the trainer can ask for a retake. A baseline-relative model is a gap to add to the graph.

## 6. User journeys

Each journey lists who acts, what they see, and where it can go wrong. Screen IDs refer to section 7.

### J1. Preseason setup and baselines

| # | Actor | Step | Screen | Risk and design response |
|---|---|---|---|---|
| 1 | Marcus or Dana | Creates the school, picks the state, imports or types the roster | C-Setup | State sets who may clear. Wrong state means wrong rules, so it is confirmed twice. |
| 2 | App | Sends each parent the state information sheet and a consent request; players 18 or over consent themselves | Parent link (web) | No consent means no baseline. The roster shows who is missing. |
| 3 | Player | Records a full baseline on their own phone at home, or in a group session run by Marcus, or at Dr. Okafor's preseason physical | P-Baseline | Sandbagging and poor capture. Each test shows a quality score; poor quality asks for a retake; a baseline far below population norms is marked for review. |
| 4 | Coach | Sees roster status: baseline done, needs retake, missing consent | C-Roster | A player with no baseline can still be checked, but the result says it compares against population ranges only, which is weaker. |

### J2. Sideline check after a hit

| # | Actor | Step | Screen | Risk and design response |
|---|---|---|---|---|
| 1 | Dana | Taps "Check a player", picks the player | C-Roster | Speed matters. Recent and starting players are listed first. |
| 2 | App | No questions. Setup steps only, with a Call 911 button always visible | C-Check | The coach never judges the player. |
| 3 | Dana | Holds the phone at arm's length, screen facing the player, for the 2-minute check. Audio and vibration mark start, halfway, and done, because she cannot see the screen | C-Check | Sun glare, helmet, sweat. The app tells her to move to shade and remove the helmet before starting. |
| 4 | App | Runs the model and the decision rules (section 5) and shows one of four outcomes, with the flags that fired and each value's measurement chain | C-Result | See outcomes below. |
| 5 | Dana | Logs the decision. If removed, the parent is notified and a case opens | C-Result, C-Case | A removal cannot be undone by the coach. Only a clinician can close a case. |

The four outcomes:

1. **Emergency.** Pupil asymmetry over 1.0 mm (CND-00260), or the coach pressed Call 911. "Call 911 now." Shows the measured value and the baseline value if there is one.
2. **Remove from play.** Model probability 0.40 or higher, or a CND-00066 required biomarker outside its catalog range. "Remove from play. Get evaluated by a healthcare provider today." Shows the probability, which domains flagged, each value against its threshold with its BMK code, and the measurement chain.
3. **No change detected.** Model probability 0.05 and pupils in range. "This does not rule out a concussion." Large button: "Remove anyway". No green colour, no check mark.
4. **Could not measure.** A sideline biomarker came back null because capture quality was too low. "Retry in shade, or treat as suspected and remove." Two retries at most.

### J3. Removal and handoff

| # | Actor | Step | Screen | Risk and design response |
|---|---|---|---|---|
| 1 | App | Opens a case with the timestamp, check data, outcome, and who ran it | C-Case | Audit trail starts here. |
| 2 | App | Sends the parent a message with what happened, emergency signs to watch for overnight, and how to book an evaluation | Parent message | Parent does not have the app. The message works by SMS and email. |
| 3 | Player | Sees "Your recovery has started", with return-to-learn step 1 and the symptom check-in | P-Home | Day-one tone is calm, not alarming. |
| 4 | Clinician | Receives the case if the school has a linked clinic (Dr. Okafor), or when the family shares a secure link with their own doctor (Dr. Ruiz) | D-Cases or D-Report | Doctors without the app still get a usable report in the browser. |

### J4. Recovery

| # | Actor | Step | Screen | Risk and design response |
|---|---|---|---|---|
| 1 | Player | From day 2, one full check a day (3 minutes). No symptom questionnaire. | P-Check | Checks are taken from the player's own face, with capture quality recorded. A player can ask to be checked, which can only hold them back. |
| 2 | App | Shows the model probability by day and key biomarkers against the model thresholds and the baseline | P-Progress | Stalls are shown as measurements, not judgments. |
| 3 | App | Moves both ladders by the recovery rules in section 5 and states why each day ("Yesterday's check had 3 or more flags. Back one step.") | P-Stages | Jalen cannot talk his way up a step. |
| 4 | Coach or Marcus | Sees the player's current stage and what they may do at practice today | C-Case | The coach sees restrictions, not detailed health data. |
| 5 | Clinician | Sees daily data, can change the stage, add notes, or ask for an in-clinic visit | D-Case | Dr. Okafor watches many cases. Cases sort by those needing attention. |

### J5. Clearance

| # | Actor | Step | Screen | Risk and design response |
|---|---|---|---|---|
| 1 | App | After two consecutive clean checks (no model flags, pupils in range) with step 4 started, it prepares the report: model by day, all biomarkers with catalog ranges, the full measurement chain, and the model's limits | D-Report | The app never says "ready to play". It says "ready for clinician review". Symptoms are assessed in the clinician's exam. |
| 2 | Clinician | Reviews the report, can examine the player, and decides: clear for full contact, not yet, or refer on | D-Report | Only a credential allowed by the school's state can sign. The app checks the credential type. |
| 3 | App | Records the decision with name, credential, licence number, timestamp, and the report version reviewed | D-Signoff | This is the written clearance the law requires. |
| 4 | Player and coach | See "Cleared by Dr. Ruiz for step 5: full-contact practice" and continue to step 6 | P-Stages, C-Case | Return to play still follows steps 5 and 6. |
| 5 | Athletic director | Gets the closed case in the school log | Export | Timestamped, read-only record. |

### J6. Second hit during recovery

If a player in an open case is checked again on the sideline, the result compares against the original pre-injury baseline, not the recovering values, and the case reopens at step 1. The coach sees "This player has an open concussion case" before the check starts.

## 7. Screens

**Coach app (Dana, Marcus)**
- C-Setup: school, state, teams, roster import
- C-Roster: players, with baseline status and open cases
- C-How: how the check works (tests, biomarkers, decision rules)
- C-Check: setup, guided 2-minute check with audio and vibration cues, Call 911 always visible
- C-Result: one of four outcomes
- C-Case: timeline, current stage, practice restrictions
- C-Log: school's timestamped record and export

**Player app (Jalen, Priya)**
- P-Onboard: consent status, what the app is and is not
- P-Baseline: full check with quality feedback and retakes
- P-Home: today's tasks
- P-Ask: ask to be checked (optional, can only hold the player back)
- P-Check: daily full check
- P-Progress: model probability by day, biomarker trends
- P-Stages: return-to-learn and return-to-sport steps

**Devices:** coaches and players use iPhone (TrueDepth front camera). Clinicians use iPad: Dr. Okafor in the iPad app, where an iPad Pro's TrueDepth camera runs in-clinic checks; Dr. Ruiz opens a shared link in Safari on her iPad with no account.

**Clinician (iPad)**
- D-Cases: case list across schools, sorted by need
- D-Case: daily data, notes, stage changes
- D-Report: one-page clearance report
- D-Signoff: decision and credential capture
- D-ClinicCheck: run a full check in clinic

One app with a role chosen at sign-in. Clinicians without an account get D-Report and D-Signoff from a secure link.

## 8. Prototype plan

A single self-contained HTML page with an iPhone frame and a persona switcher (six personas). Scripted data, no backend. It covers J1 to J6 end to end. The sideline check is simulated: a moving dot and screen flashes, then a chooser lets the reviewer pick which of the four outcomes to see. Published as a private link for sharing.

**Audience and purpose (decided):** coaches and players see it first. It is a fully working, demo-ready app running on demo data, and it is the design reference for the real app, which will be built in Flutter later. Screens, states, wording, and the data it implies should be treated as the spec. Clinician views are included so the story ends at sign-off. Wording is written for a 15-year-old and a volunteer coach first.

Prototype file: `prototype/index.html`.

Prototype decisions (my calls, open to change):

- **One shared case.** All personas act on the same scripted season. A day control ("Day 0, Day 1, ...") moves time forward, so the 24-hour rule, stage changes, and sign-off show up for every persona. Switching from Dana to Priya to Dr. Ruiz follows one case end to end.
- **Surfaces outside the phone.** Dr. Ruiz's report and sign-off render in a browser-window frame. Parent SMS and email, and the athletic director export, appear in a side panel labelled "Sent outside the app". Dr. Okafor uses the phone frame for in-clinic checks and the browser frame for his case list.
- **No-baseline result.** Not a fifth outcome. Outcomes 2 and 3 carry a fixed banner: "No baseline on file. Compared with typical ranges for this age, which is less reliable." The roster shows the player with a warning before the check.
- **Cues during the check.** Real audio tones and a spoken cue through the browser, plus a large visual cue for the reviewer. Vibration is called where the browser supports it. The iOS build needs its own haptic and audio spec.
- **Numbers.** Real-looking values in real units (pupil asymmetry in mm, light reflex amplitude in mm and latency in ms, pursuit gain as a ratio, saccade velocity in degrees per second, blink rate per minute), each shown as baseline vs. today vs. the player's normal range. Every data screen carries a "Sample data" label.
- **State rules.** One state, Maryland: a licensed physician, or a PA or NP under physician delegation, may sign. The state setting is visible in setup but fixed in the prototype. The full state table is an open item.
- **Clearance point.** Before return-to-sport step 5, as set in section 4.
- **No symptom list.** Superseded: decisions use measurements only (section 1).
- **Scenario picker.** After a demo check, the presenter picks what happened to the player (concussed, pupils unequal, not concussed, glare). The app then runs the real model and rules on matching demo values. Only the values are scripted, never the outcome.
- **On a real iPhone** the app fills the screen, with a bar at the top to switch persona and day.

## 9. Open items

- State-by-state clearance credential table.
- Where in the return-to-sport sequence written clearance is required (Amsterdam 2022 text not yet read in full).
- FDA pathway decision: 510(k) under QEA, or a narrower claim.
- Pupil accuracy outdoors in daylight. The current pupil method uses a dark-pixel threshold and may not work in sunlight on a sideline.
- Graph gaps Sideline depends on: FTR-00162 gaze stabilization has no computer; no baseline-relative model; no numeric threshold for a fixed pupil; `head-sway-v1` (balance) is computed but no test feeds it; the model is planned and unvalidated (expected AUC 0.73).
- The return-to-sport protocol (Amsterdam 2022) and state laws gate progression on symptoms. Sideline gates on measurements and leaves symptoms to the clinician's exam. This needs clinician sign-off.
- Catalog fixes: mark `concussion-or-mtbi-acute` as longitudinal, and add the pupil biomarkers to `concussion-oculomotor-screen-v1`'s inputs.
