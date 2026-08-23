# Branch integration review

This review compares `origin/wellness-league-visual-polish` at `61bdcb8` and
`origin/health-insight-harness` at `e45f091` with the current application architecture.
The branches were treated as feature donors rather than merged wholesale: the visual branch
forked from older project history, while the health insight prototype has no shared Git ancestry.

## Adopted

- A user-selectable wellness focus and a polished daily path are derived from real aggregate data.
- `WellnessInsightEngine` is a platform-independent model layer. It produces one versioned,
  deterministic `WellnessInsightContext` containing trend, daily goal, and weekly-score data.
- `WellnessViewModel` owns persisted focus and goal settings. Today, League, Ask, and export now
  read the same settings rather than maintaining separate values in views.
- Goal progress has three explicit states: achieved, open, and unavailable. Missing or
  unauthorized data is never converted to zero and never presented as a failed goal.
- The Device Activity report groups a seven-day filter into coarse daily totals before saving;
  the model never receives application, category, domain, or activity-event details.
- The Personal AI boundary receives the reviewed context rather than assembling health facts in
  the model runtime or SwiftUI view.
- Real small-group standings can use explicit local league-pass export/import. The pass includes
  only a versioned aggregate snapshot and never contacts CloudKit or another backend.

## Intentionally not adopted

- The visual branch's public CloudKit friend-code database. Six-character public record keys,
  automatic publishing, and the lack of invite approval, deletion, blocking, reporting, and
  server-side authorization do not meet the existing social privacy contract. CloudKit is not
  required for the core product and was removed after evaluating Apple's health-data rules.
- Automatic streak-risk notifications. They request permission without a user setting and can
  turn unavailable measurements into pressure to preserve a streak.
- Mutable XP awards. The donor implementation stores totals without an auditable event ledger,
  so switching tracks or changing rules can make totals impossible to reproduce.
- The health harness's view-owned HealthKit and model state. Its single view performs data access,
  scoring, report generation, and inference, which bypasses the app's model/controller boundaries.
- Its zero fallback for failed HealthKit queries, raw summation of overlapping sleep samples, and
  added calorie permission. The current HealthKit client de-duplicates supported sleep categories
  and keeps absent measurements optional.
- Its hard-coded uncensored model resource and unbounded raw generation path. The existing runtime
  protocol, source reporting, reviewed JSON context, safety instructions, and deterministic fallback
  remain the supported model path.

## End-to-end ownership

```text
HealthKit + Device Activity
    -> DailyWellnessRecord (optional aggregate measurements)
        -> WellnessInsightEngine (pure reviewed model)
            -> WellnessViewModel (controller + persisted goals/focus)
                -> Today path
                -> League score
                    -> explicit local league pass -> on-device friend standings
                -> PersonalModelContext
                -> WellnessExportPackage -> companion web review -> PDF
```

The export continues to carry aggregate records plus the controller's actual goal configuration.
Derived values are recomputed from that source data instead of being persisted twice, preventing
stale score or trend snapshots from disagreeing with the imported records.

The league-pass path is intentionally manual and not cheat-resistant. Automatic global leagues
remain a later backend, identity, moderation, and policy project rather than being disguised as a
completed feature.
