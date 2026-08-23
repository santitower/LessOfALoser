# Wellness Leagues

Wellness Leagues is a privacy-first social competition concept inspired by the motivational structure of weekly learning leagues—not a copy of another product's branding or interface.

The prototype includes:

- a weekly league and countdown;
- rank movement, podium, chase, and comeback zones;
- a three-metric point breakdown;
- personal goal controls;
- streaks and a friendly one-on-one duel;
- preset playful reactions; and
- a clear preview mode using synthetic friend profiles.

Duolingo's public explanation highlights weekly resets, matching learners with similar habits, promotion through league tiers, and the ability to opt out. Its social features add friend streaks, milestone celebrations, and cooperative quests. Those mechanics informed the hierarchy, while LessOfALoser uses its own visual language and a much narrower health-data boundary.

- [Duolingo: how leaderboards and leagues work](https://blog.duolingo.com/duolingo-leagues-leaderboards/)
- [Duolingo: social features](https://blog.duolingo.com/friends-social-features/)

## What the score means

The leaderboard is a **consistency game**, not a health score and not a comparison of bodies.

Each of the user's three personal goals is worth 10 points per day:

- sleep reaches the user's chosen target;
- steps reach the user's chosen target; and
- Screen Time remains at or below the user's chosen limit.

Every category has equal weight. Passing a target by more does not earn more points. Missing measurements remain unknown and earn no points; they are not presented as failed health goals. A week has a maximum of 210 points.

The iPhone retains at most seven locally generated aggregate Screen Time totals so current-week points can accumulate without uploading them. It cannot backfill a day when the privacy-preserving daily report was not produced.

The default goals are examples and can be changed locally. They are not medical recommendations.

## Current boundary

The current screen is deliberately a preview:

- friend profiles, scores, streaks, movement, and reactions are synthetic;
- the user can choose to substitute their locally calculated weekly score;
- no account is created;
- no social backend is contacted; and
- no health-derived value is uploaded.

The UI must continue to say this plainly until a real service exists.

## Backend contract for a later phase

A first production version should transmit only a user-approved social snapshot:

```json
{
  "schemaVersion": 1,
  "weekID": "2026-W34",
  "weeklyPoints": 170,
  "activeDays": 6,
  "streakDays": 12
}
```

The service may separately store display name, avatar reference, friendship state, and preset reaction events. It must not receive exact sleep, step, or Screen Time values; app names; web domains; HealthKit samples; trend observations; or model prompts.

Before enabling uploads, implement and review:

1. explicit, revocable consent that names every shared field and recipient;
2. Sign in with Apple or an equivalent compliant account flow;
3. in-app account deletion and server-side deletion/retention handling;
4. invite approval without uploading a user's entire contacts database;
5. private profile, opt-out, unfriend, mute, block, and report controls;
6. rate limits and replay protection for reactions and weekly score submissions;
7. a versioned scoring contract, a minimum-data-coverage policy, and fair weekly timezone rules;
8. a privacy policy and App Review disclosure; and
9. abuse reporting plus moderation operations before any free-form messages.

Preset reactions are intentional. They allow playful competition without introducing an unmoderated chat system or permitting comments about a person's body, diagnosis, medication, or missing health data.

Because unknown measurements earn no points, a production league must show data coverage clearly, must not label missing data as a failed health goal, and must not pressure people to grant optional Health or Screen Time access merely to remain eligible.

## Apple privacy considerations

Apple requires permission before personal data is transmitted or shared, a way to withdraw consent, data minimization, and clear retention/deletion policies. Its current Health and Health Research rule also says personal health information may not be stored in iCloud. For that reason, do not assume CloudKit is an acceptable store for a HealthKit-derived leaderboard score without a dedicated legal and App Review assessment.

- [App Review Guidelines, sections 5.1.1–5.1.3](https://developer.apple.com/app-store/review/guidelines/)
- [HealthKit privacy guidance](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)

For a group prototype, Tailscale can protect a small first-party API, but it does not replace user accounts, consent records, deletion, moderation, or a scalable production service.
