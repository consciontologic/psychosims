# Static PWA build and GitHub Pages hosting

Psychosims builds to `app/build/web` for **https://psychosim.com/**. The
production entry point is Flutter web; serving these files requires no game
server, database, native inference library, or runtime environment variables.
New patient replies use direct OpenRouter HTTPS requests. Gameplay, previous
dialogue, deterministic outcomes and saves remain local.

## Build and inspect

Use **Flutter 3.38.5 / Dart 3.10.4**, Python 3 and Node 22. The build checks the
Flutter version and uses the committed dependency lockfile. From the repository:

```bash
pwd
make verify
# Build alone, once dependencies/test gates have been checked:
scripts/web_build.sh
# Local static server; no SPA rewrites or server application:
make web.serve  # serves app/build/web on 127.0.0.1:18763
```

Open `http://localhost:18763/`. Keep this dedicated origin for Psychosims so
unrelated apps on common ports do not share its service-worker registration or
saves. Changing the host or port creates separate browser storage. Localhost is
a secure context for service workers;
a LAN address over HTTP is not. Build artifacts are intentionally ignored by
Git. CI stores the complete artifact for review; publication uses the same
directory. Do not publish repository source or the parent `app/` directory.

For a local offline check, wait for **Ready offline**, play a turn, then use
Chrome/Edge DevTools → Network → **Offline** and reload the page. The saved turn
and transcript should remain; local practice can continue while new AI replies
pause. Switch Network back to **No throttling** when finished. Disconnecting
Wi-Fi alone does not block the local server, so it is not sufficient evidence
of an offline reload on localhost. Do not select **Bypass for network** or clear
site storage during this check. Refreshing forgets the memory-only API key.

The build invokes:

```bash
flutter pub get --enforce-lockfile
flutter build web --release --base-href / --pwa-strategy=none --no-web-resources-cdn
python3 scripts/web_finalize.py
```

Each build first clears only generated `app/build/web` so stale assets cannot
enter the new artifact; other build/cache directories are preserved. The
finalizer rejects symlinks, source maps, server executables, secret/config
filenames, unexpected file types and recognizable OpenRouter/private-key values.
It creates `offline-manifest.json` with every cached URL and SHA-256 hash and
compiles that inventory into `service_worker.js`. It is a defense in addition
to source review and secret scanning, not a proof that arbitrary secret formats
cannot be embedded in text. Never put keys in `--dart-define`, source, assets or
Actions variables. No user key is needed to build or test.

## Paths and reloads

The HTML `<base href="/">`, manifest, worker and asset paths share root scope:

```json
{
  "id": "/",
  "start_url": "/#/",
  "scope": "/",
  "display": "standalone"
}
```

Navigation uses hash URLs, for example `https://psychosim.com/#/session`.
The fragment never reaches Pages, so reloads request `/` and do not require
rewrite rules or a `404.html` routing trick. Share links using `/#/...`, not
`/session`. Direct path URLs intentionally receive normal static-host 404s.
Query-string credential links are unsupported; keys are entered in the app.
The root build is intended for the custom domain, not the repository subpath
`consciontologic.github.io/psychosims/` before that domain is configured.

Flutter bootstrapping explicitly loads `canvaskit/` from this site. Roboto
regular/medium/bold, Noto Serif regular/bold and Noto Sans Symbols fonts are bundled with their
licenses, alongside the original noir office and patient illustrations. All are
included in the verified offline inventory; no art or font CDN is used. See
[visual direction and provenance](../design/VISUAL_DIRECTION.md). The existing Android
launcher artwork is reused for the PWA icons, with a 512 px PNG export. The
Cupertino icon font used by adaptive Flutter controls is also bundled, using
`cupertino_icons` 1.0.9 compatible with the pinned toolchain; the newer 2.x
requires a newer Flutter SDK ([official package changelog](https://pub.dev/packages/cupertino_icons/changelog)). The
shell directs font fallback to this origin and its CSP prohibits external
fonts, scripts, frames and analytics; only OpenRouter is an allowed external
connection. See [Flutter initialization](https://docs.flutter.dev/platform-integration/web/initialization)
for the documented `canvasKitBaseUrl`, `fontFallbackBaseUrl` and `hostElement`
configuration. Future languages need suitable bundled glyph coverage.

## Offline lifecycle and privacy

On first opening, the service worker downloads **all enumerated build resources**,
including engine WASM, every bundled scenario, font and icon. Each response must
succeed and match its build hash before installation completes. A failed or
incomplete installation is removed; the shell displays a retry action. Wait for
**Ready offline** before disconnecting. The worker script itself is installed
by the browser; the audit manifest is a build-review file, not an app dependency.

The worker only serves exact, same-origin public inventory paths. It does not
cache POST requests, authorization headers, query strings, cross-origin URLs,
API responses, keys or transcripts. API keys stay in page memory and must be
re-entered after reloading. Browser saves/transcripts use the app's local storage
mechanism separately from this public asset cache. An offline action never
queues a hidden API request; reconnecting alone does not replay a generation.

The shell reports offline readiness, current connectivity and update availability.
Connectivity is advisory; an online browser can still have an unreachable API.
The client handles request failures independently. Saving failure and unavailable
storage are reported by the application; do not clear site data to fix an update
unless local saves have been exported.

Each build gets its own cache name derived from asset contents **and worker
source**. Updates finish downloading in the background and wait. Save your work,
close **every** Psychosims tab/window, and reopen to activate the update. There is
no `skipWaiting`, automatic reload, or mid-session code replacement. Activation
deletes only prior Psychosims static caches, never local saved games. A failed
update leaves the active version available, including on an offline reload.

Browsers can evict site data, private browsing may discard it, and users can
clear it. Offline support begins after successful caching and lasts while that
storage is retained. Installation does not make storage permanent. Use the app's
save export for a portable backup. Chrome/Edge can show **Install app** when the
browser offers installation; Safari uses Share → Add to Home Screen. The app
works as a normal browser tab when installation UI is unavailable.

## Prepared workflows and approval boundary

`.github/workflows/ci.yml` runs `make verify` on pushes and pull requests, and
tests the release artifact in Chromium and uploads `psychosims-static-pwa` for
review. Browser screenshots and results are uploaded even on test failure. It
never deploys.
`.github/workflows/pages.yml` requires a human to run the workflow on `main`
and explicitly select `publish: true`; it re-verifies the artifact before upload:

```yaml
on:
  workflow_dispatch:
    inputs:
      publish:
        required: true
        default: false
        type: boolean
# deploy job (after the build):
permissions:
  contents: read
  pages: write
  id-token: write
environment:
  name: github-pages
```

Before approving publication, a repository administrator must configure
Settings → Environments → `github-pages` with required reviewers and allow
deployments only from `main` (where supported by the account plan). YAML cannot
create those reviewer protections. Without them, the explicit manual workflow
dispatch remains the publication decision. Pages source must be **GitHub Actions**.
The workflow uses GitHub's `configure-pages@v5`, `upload-pages-artifact@v4` and
`deploy-pages@v4` actions, with write/OIDC permissions limited to deployment.
The build job has `contents: read` and `pages: read`: `configure-pages`
[reads the existing site with `repos.getPages`](https://github.com/actions/configure-pages/blob/v5/src/api-client.js),
whose authenticated permission is
[Pages read](https://docs.github.com/en/rest/pages/pages#get-a-github-pages-site).
Public resources can be readable without that permission, but the workflow
declares its access explicitly. `enablement: false` prevents the action from
creating a Pages site; administrator setup remains separate.
[GitHub custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
documents these requirements.

The `npm ci` and `npx playwright install --with-deps chromium` steps run only
inside the workflows' GitHub-hosted `ubuntu-latest` jobs. They follow
[Playwright's CI setup](https://playwright.dev/docs/ci-intro), including ephemeral
runner system dependencies. The local verification script does not invoke
`--with-deps` or install OS packages; local browser provisioning remains subject
to the repository's system-change approval rule.

`app/web/CNAME` records `psychosim.com` in the artifact for discoverability.
**For Actions publishing, this file does not configure the custom domain**;
the administrator must set it in repository Settings → Pages.
[GitHub publishing-source documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
explains that distinction. No workflow dispatch, account setting, DNS record,
commit or push was performed as part of this local implementation.

## Live domain observations — 23 October 2026

Read-only checks at approximately **13:21–13:27 Europe/Istanbul** used the host's
resolver (`127.0.0.53`) and Google Public DNS over HTTPS, with matching answers.
Google's replies identify authoritative servers `97.74.103.14` and
`173.201.71.14`. These are observations at that time, not a claim of control over
the registrar or GitHub account.

| Check | Observed result | Implication |
|---|---|---|
| NS | `ns27.domaincontrol.com`, `ns28.domaincontrol.com`; TTL 3600 | DNS is not currently on Namecheap BasicDNS |
| Apex A | `3.33.130.190`, `15.197.148.33`; TTL 600 | Does not point to GitHub Pages |
| Apex AAAA | No answer (SOA negative TTL 600) | No IPv6 Pages records observed |
| `www` CNAME | `psychosim.com`; TTL 3600 | Must point directly to the GitHub owner host for Pages |
| GitHub TXT challenge | `_github-pages-challenge-consciontologic.psychosim.com`: NXDOMAIN | No public verification record observed at this expected name |
| HTTP apex and www | HTTP 200, no HTTP→HTTPS redirect | HTTPS enforcement is not proven |
| HTTPS apex and www | HTTP 200; HTML script navigates to `/lander` | Current site is not this PWA |
| Apex TLS | Valid certificate, SAN `psychosim.com`; issuer GoDaddy TLS Intermediate CA DV - R1v1; expires 14 Jan 2027 | Existing TLS works, but this is not a Pages deployment certificate check |
| www TLS | Valid certificate, SAN `www.psychosim.com`; same issuer; expires 3 Feb 2027 | Existing TLS works; canonical redirect absent |

One local TXT lookup timed out; the separate Google DNS query returned NXDOMAIN.
The connected GitHub repository metadata confirms public visibility and default
branch `main`; the connection has read/pull access, not administrator access.
No authenticated Namecheap registrar record, GitHub domain verification screen,
Pages custom-domain setting or environment-reviewer policy was available to this
verification. The user's Namecheap registration statement is retained as context;
the public nameservers are a separate fact to reconcile before changing DNS.

## Domain setup after approval

1. Confirm the domain and nameserver ownership in Namecheap → Domain List →
   Manage → Nameservers. With the currently observed custom nameservers, edit
   records at the authoritative DNS provider. If choosing Namecheap BasicDNS,
   first copy the full existing zone, including mail records, then approve that
   nameserver migration separately. Namecheap's Advanced DNS host-record editor
   applies only to BasicDNS, PremiumDNS or FreeDNS. See
   [Namecheap host records](https://www.namecheap.com/support/knowledgebase/article.aspx/434/2237/how-do-i-set-up-host-records-for-a-domain/).
2. In the **GitHub owner account/organization settings**, open Pages → Add a
   domain → `psychosim.com`. Copy the exact TXT name and value GitHub generates.
   In Namecheap, the host is normally just
   `_github-pages-challenge-consciontologic` (do not duplicate `.psychosim.com`).
   The value must come from GitHub; there is no invented token in this repository.
   After DNS resolves, click Verify and **retain the TXT record**. Verification
   is owner-level, not repository-level.
   [GitHub domain verification](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages)
3. In repository Settings → Pages, choose **GitHub Actions** and save custom
   domain **psychosim.com**. Review/approve the first manual publication only
   after the staged implementation and build artifact have been reviewed.
4. At the authoritative DNS provider, prepare these records. For Namecheap
   BasicDNS use Domain List → Manage → Advanced DNS → Host Records → Add New
   Record, and TTL **Automatic**. Remove conflicting parking/URL Redirect or
   old A/AAAA/CNAME records for these hosts only, preserving unrelated mail/TXT
   records. No wildcard record is needed.

| Type | Host | Value |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `consciontologic.github.io` |
| TXT | Exact GitHub challenge host | Exact GitHub-generated verification value |

The owner hostname is taken from this repository's configured remote,
`consciontologic/psychosims`; do not append `/psychosims` or point `www` to the
apex. Optional AAAA records at `@` are `2606:50c0:8000::153`,
`2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`; retain the
A records if adding IPv6. These values match the official
[GitHub custom-domain guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)
and [Namecheap GitHub Pages guide](https://www.namecheap.com/support/knowledgebase/article.aspx/9645/2208/how-do-i-link-my-domain-to-github-pages/).

5. Wait for the Pages DNS check and certificate provisioning, then enable
   **Enforce HTTPS** in repository Settings → Pages. If CAA records are present,
   permit `letsencrypt.org`; inspect the current zone before changing this policy.
   [GitHub HTTPS](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https)
   and [custom-domain troubleshooting](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages)
   describe provisioning and CAA requirements. A registrar SSL purchase is not
   needed for GitHub-managed Pages HTTPS.
6. With the apex selected as custom domain and both DNS variants correctly set,
   Pages supplies the `www`→apex redirect. Use GitHub's HTTPS enforcement for
   HTTP→HTTPS. Do not add Namecheap masked/URL forwarding rules on top.
   Validate actual Location headers; the prior site's TLS success is insufficient.

## Post-publication acceptance (still external)

Run these read-only commands after the approved deployment and DNS propagation:

```bash
dig psychosim.com NS +noall +answer
dig psychosim.com A +noall +answer
dig psychosim.com AAAA +noall +answer
dig www.psychosim.com CNAME +noall +answer
dig _github-pages-challenge-consciontologic.psychosim.com TXT +noall +answer
curl -I http://psychosim.com/
curl -I https://psychosim.com/
curl -I http://www.psychosim.com/
curl -I https://www.psychosim.com/
curl -I https://psychosim.com/service_worker.js
```

Expect the four Pages A records, the direct owner CNAME, the exact TXT challenge,
valid apex/www TLS, redirects ending at `https://psychosim.com/`, and successful
HTML/JS/manifest/WASM responses without mixed content. Confirm the Pages UI says
DNS check successful and HTTPS enforced. DNS propagation can take up to 24 hours.

In a fresh browser profile open the public app, wait for **Ready offline**, save
a session, and install if offered. Disable network and reload the installed app
and a `/#/session` link; confirm saves/transcripts, local moves, and the paused AI
control. Reconnect; confirm no automatic AI replay. Exercise 360, 768, 1440 px
and intermediate widths, keyboard focus, touch targets, high text scale and
reduced motion. Test a second approved build with two open tabs: the old game
must continue until all tabs close, then reopening must show the new build and
the same saved data. Record public URL, revision, cache build ID, browser/version,
viewport and screenshots. Local passing tests cannot establish these live gates.
