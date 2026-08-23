# Web review and report flow

The `web-demo` project is the companion review surface for LessOfALoser. It does not connect directly to Apple Health. Apple Health access remains in the signed iPhone app; the user explicitly decides when to create and move an aggregate export.

## Export contract

`WellnessExportPackage` is a versioned JSON envelope with:

- a schema version and package kind;
- the export time;
- aggregate daily sleep, step, and coarse Screen Time totals;
- data-coverage values; and
- the user's local consistency goals.

It excludes raw HealthKit samples, application or website identities, opaque Screen Time tokens, prompts, and conversation history. The web importer rejects unknown package kinds, unsupported versions, invalid dates, implausible metric ranges, empty exports, and exports longer than one year.

## Web surfaces

- **Today** shows the latest aggregate values and a 14-day signal.
- **Review** compares the latest day with a selectable 7-, 14-, or 28-day personal baseline.
- **Model** exposes the verified context boundary and supplies a deterministic safe response when no private language model is connected.
- **League** converts goal completions into a maximum of 21 weekly stars and compares them with local sample profiles.
- **Report** formats the retrospective as a print/PDF artifact with provenance and wellness disclaimers.

## League boundary

The current web league is intentionally local-only. It uses sample competitors and stores only a
weekly pinned/not-pinned preference in browser storage. It has no sign-in flow, social API, or
database. A real multiplayer league requires product-owned authentication, explicit consent,
invite approval, withdrawal and deletion, abuse controls, and a reviewed aggregate-only payload
before it can replace this preview.
