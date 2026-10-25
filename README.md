# Psychosims

A fictional psychology-practice game delivered as a **static Flutter web PWA**.
The existing deterministic rules own outcomes and local career progression.
Optional OpenRouter AI voices patients while online; saved sessions, transcripts,
loadouts and bundled content remain available offline after caching completes.
This is fictional gameplay, not clinical care.

## Run and verify

Use Flutter **3.38.5** / Dart **3.10.4**, Python 3 and Node.js. No server,
database, Docker, native inference build, model download or API key is required.

```bash
scripts/bootstrap.sh      # locked Dart dependencies and repository-local hook
make verify               # current static PWA tests, checks and release build
make web.serve            # static preview at localhost:18763
```

Open `http://localhost:18763/`. This dedicated origin keeps Psychosims saves and
service-worker caches separate from other projects on common localhost ports. Use the in-app OpenRouter settings to enter your
own key for this tab only; it is cleared on reload. Local practice works without
a key. Use hash links (`/#/...`) for bookmarkable routes on GitHub Pages.
Wait for the visible offline-ready confirmation before disconnecting.

Choose **New game** on Home to prepare a fresh session. During a session it asks
before replacing unfinished dialogue; career progress and completed history stay
on the device. **Resume session** continues an existing game. The original
scenario now uses locally bundled painterly noir artwork and typography; see
the [visual direction and asset credits](docs/design/VISUAL_DIRECTION.md).

The release artifact is `app/build/web/`. Only that directory is uploaded to
Pages. The configured production origin is `https://psychosim.com`; creating the
artifact does not publish it. The Pages workflow requires a separate manual
dispatch and environment approval configured by the repository owner.

## Documentation

- [Static hosting, DNS and HTTPS](docs/guides/STATIC_HOSTING.md)
- [Current architecture and privacy](docs/code/ARCHITECTURE.md)
- [Implementation evidence](docs/reports/2026-10-23-static-pwa.md)
- [Roadmap and acceptance checklist](docs/planning/ROADMAP.md)
- [Security and local data](SECURITY.md)
- [Agent rules](AGENTS.md) and [tracking](docs/tracking/README.md)

The retired native client, server, downloaded models, platform binaries and
obsolete tests/docs have been removed with explicit user authorization. Reusable
core rules, content, tests and current PWA verification evidence remain.

Agents stage changes; a human reviews, commits and pushes using `make git`.
See [LICENSE](LICENSE).
