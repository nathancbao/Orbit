# Milestone 2 User Interview Summary

## Iteration 1 — Ben, Alex, Elena

### What We Learned
- **Terminology is the #1 problem.** All three users were confused by "Missions," "Signals," and "Pods." Nobody could tell the difference between Missions and Signals without explanation.
- **First impression is off.** Users thought the app was astrology-related, a game, or a calendar — the space/planet theme is misleading. None immediately identified it as a social/activity app.
- **AI suggestions are well-received.** All three found the AI useful and trustworthy. Users want suggestions based on past activity and other users' behavior.
- **Navigation is unclear.** Users struggled to find where to create events. Naming conventions made it hard to get to the planning area.
- **Users want their own events visible.** Elena couldn't find her own created mission in the app.

### Key Feedback
- Need a tutorial or onboarding walkthrough explaining terminology
- Consider combining Missions and Signals into one concept
- Add filters for events (by type, by class, etc.)
- Discovery page needs icons and better visual hierarchy
- Photo upload broken (Elena)

### Average Difficulty: 2.5 / 5

### Changes Made After Iteration 1
- Began rethinking terminology clarity (Missions vs Signals)
- Noted need for onboarding/tutorial flow
- Identified photo upload bug

---

## Iteration 2 — Raeann, Lisa, Lauren

### What We Learned
- **Terminology still confusing.** Even after iteration 1 awareness, all three users still struggled with Missions, Signals, and Pods. The terms are not self-explanatory.
- **First impressions improved slightly.** Lisa correctly identified it as a social/matching app. Raeann and Lauren still guessed astrology or a game.
- **AI trust is consistent.** Users find suggestions trustworthy and useful. Lisa wanted the ability to dismiss a recommendation and get a new one. Lauren wanted suggestions based on interests and past events.
- **Safety and accountability matter.** Lisa raised safety concerns — wants social media links on profiles, friend requests, and strikes for no-shows. Raeann wants admin/owner controls over who joins.
- **UI discoverability issues.** Lauren found the mission color legend confusing and misplaced. Raeann wanted more space utilized in the discovery page.

### Key Feedback
- Tutorials still the top request
- Admin controls: owner approval for who joins, kick permissions
- Safety features: social media on profiles, no-show accountability/strikes
- Dismiss + regenerate for AI recommendations
- Login page should indicate school affiliation
- Legend placement and mission colors need rework

### Average Difficulty: 2.2 / 5

### Changes Made After Iteration 2
- Prioritized onboarding/tutorial implementation
- Noted safety feature requests for future roadmap
- Identified need for admin controls on pods/missions

---

## Iteration 3 — Nathan, Adam, Ai Linh

### What We Learned
- **First impressions significantly improved.** Nathan correctly identified it as a social/events/groups app. Adam said "an app meant to connect me with similar communities/people." Ai Linh said it "connects me to do different things" and felt like she was "about to network." This is a major improvement over Iteration 1.
- **Core task is now completable.** Nathan figured out event creation after a few minutes of exploring, comparing the UX favorably to Instagram/Facebook. Adam rated ease of use 4/5 coming in blind. Ai Linh rated difficulty at just 1/5 — she navigated the discovery page, joined a pod, and filled out time independently.
- **Onboarding still requested.** All three users asked for a guided tour or quick overview — but could complete tasks without one. Ai Linh suggested a step-by-step tutorial and short summary sentences explaining Missions vs Signals.
- **AI is useful but slow.** Nathan reported suggestions not loading half the time. When they do load, they're helpful but limited by sparse profile data. Adam found them "very helpful." Ai Linh found AI useful — she wanted to use it to get to know group members.
- **Terminology still an issue for some.** Ai Linh found the difference between Signals and Missions unclear, and said adding Signals wasn't clear. This echoes earlier iterations.
- **Trust and safety concerns persist.** Ai Linh said she would be "wary of trusting people" — reinforcing Lisa's safety concerns from Iteration 2. She also suggested more extensive profiles to build trust.
- **Voyage button is unclear.** Adam didn't know what it does.
- **Dark mode is broken.** Nathan found it severely breaks the UI.
- **Custom interests don't surface.** Adam noted custom interest tags don't appear at the top.

### Key Feedback
- Discovery page should show joinable events, not just templates for creating
- Button labels for creating Signals/Missions need clarity
- Fix dark mode UI parity
- Fix profile picture upload
- Cancel vs create button not working (Ai Linh)
- Guided tour would help but is less critical now — app is more intuitive
- Voyage button purpose unclear
- Photo sharing at end of events — "Do you wanna share photos to public? People can see and see if they want to join" (Ai Linh)
- More extensive profiles to build trust
- Incentives to keep users engaged / upgrade
- Short summary sentence for Missions and Signals to clarify the difference

### Average Difficulty: 2.5 / 5 (Nathan), 4 / 5 ease (Adam), 1 / 5 (Ai Linh)

### Changes Made After Iteration 3
- Identified dark mode as critical UI bug
- Flagged AI loading performance for backend investigation
- Noted Voyage button needs clearer purpose or labeling
- Cancel vs create button bug identified
- Trust/safety and more extensive profiles noted for roadmap

---

## Cross-Iteration Trends

| Theme | Iteration 1 | Iteration 2 | Iteration 3 |
|-------|------------|------------|------------|
| First impression accuracy | Low (astrology, game) | Mixed (1/3 correct) | High (3/3 correct) |
| Terminology confusion | Severe | Still present | Less critical but still noted (Ai Linh) |
| AI usefulness | Positive | Positive | Positive (but slow loading) |
| Task completion | Struggled | Needed help | Completed independently |
| Tutorial request | Universal | Universal | Still wanted but less urgent |
| Trust/safety concerns | Not raised | Raised (Lisa) | Reinforced (Ai Linh) |
| Avg difficulty | ~2.5 | ~2.2 | ~1.0–4.0 (wide range, trending easier) |

---

## Known Bugs

### Functional Bugs
- UI breaks in dark mode — must be consistent regardless of light/dark mode
- Photo upload failing
- Authentication needs reimplementation
- TestFlight version is outdated (older version of the app)
- Creating Signals and Missions needs clarification on how to do so
- Adding custom interest causes request failed (status 503)
- Unable to add vote on time and location when only one option exists (should users be prompted to add a 2nd option?)
- Voyage button purpose unclear — users don't know what it does
- AI suggestions fail to load / load slowly ~50% of the time
- Cancel vs create button not working (Ai Linh, Iteration 3)

### Non-Bug Improvements
- Custom interest tags should show up at the top (Adam noted they don't appear)
- Onboarding tutorial / guided tour for first-time users
- Consider merging Missions and Signals into a single concept
- Admin controls (approve/kick members)
- Safety features (social media links on profiles, no-show strikes)
- Dismiss + regenerate for AI recommendations
- Discovery page should emphasize joining events over creating them
- Filters (by event type, class, etc.)
- Photo sharing at end of events for public visibility (Ai Linh)
- More extensive profiles to build trust (Ai Linh)
- Short summary/explanation for Missions vs Signals in the UI (Ai Linh)
- Incentives or gamification to encourage participation (Ai Linh)
