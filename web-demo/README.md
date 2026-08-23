# LessOfALoser web review

The companion web dashboard turns a user-initiated aggregate export from the iPhone app into a private retrospective, grounded model view, weekly consistency league, and PDF-ready report.

## Product flow

1. The iPhone app reads authorized Apple Health and Screen Time sources.
2. The user exports `lessofaloser.wellness-export` JSON from the Today dashboard.
3. The web dashboard validates and processes that file in the current browser session.
4. The user can review personal baselines, inspect model context, and print a structured PDF.
5. The league provides a browser-local preview with sample competitors and no account requirement.

Raw HealthKit samples, app and website identities, personal trend values, prompts, and report contents are not uploaded. The local league control stores only a pinned/not-pinned preference in browser storage.

## Run locally

The project requires Node.js 22.13 or newer.

```bash
npm install
npm run dev
```

Then open `http://localhost:3000`.

## Validate

```bash
npm run lint
npm test
```

The standard Next.js build has no platform-specific hosting plugin, sign-in dependency, or server-side league database. It can run on a normal product-owned host; local development never requires an account.
