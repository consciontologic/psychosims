# ┊┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃
#  Model-agnostic agent framework Makefile
# ──────────────────────────────────────────────────────────────
#  Targets are thin dispatchers. All real logic lives in
#  xops/makefile/<module>.py (stdlib-only, cross-platform).
#
#  Convention:
#    • daily verbs are short  : help, git, doctor, scaffold
#    • everything else uses   : domain.action  (track.add, git.dry, roadmap.status)
# ┊┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃

PYTHON ?= python3
XOPS   := $(PYTHON) xops/makefile

# Tracking append defaults (override on CLI: make track.add ACTION=note SUMMARY="...")
ACTION  ?= note
STATUS  ?= completed
SCOPE   ?= general
AGENT   ?= human
SUMMARY ?=
REFS    ?=
RUN_ID  ?=

# Skills targets
TAG ?=

.DEFAULT_GOAL := help

.PHONY: help git git.dry track.add track.list roadmap.status doctor scaffold skills.status skills.find codeg test verify
.PHONY: build lint format format.check verify.contracts dart.test dart.lint dart.format dart.format.check web.build web.smoke web.serve
.PHONY: security.secrets security.dependencies security.privacy

## help              List all available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /' | sort

## git               Commit pending tracking rows as conventional commits + push
git:
	@$(XOPS)/git_ops.py push

## git.dry           Preview what `make git` would commit and push (read-only)
git.dry:
	@$(XOPS)/git_ops.py dry

## track.add         Append a row to docs/tracking/tracking.csv (vars: ACTION STATUS SCOPE AGENT SUMMARY REFS RUN_ID)
track.add:
	@$(XOPS)/track_ops.py add \
		--action="$(ACTION)" --status="$(STATUS)" --scope="$(SCOPE)" \
		--agent="$(AGENT)"   --summary="$(SUMMARY)" --refs="$(REFS)" \
		$(if $(RUN_ID),--run-id="$(RUN_ID)",)

## track.list        Show recent tracking rows (last 20)
track.list:
	@$(XOPS)/track_ops.py list

## roadmap.status    Summarize ROADMAP.md checkbox progress
roadmap.status:
	@$(XOPS)/roadmap_ops.py status

## codeg             Initialize or update the CodeGraph index
codeg:
	@$(XOPS)/codegraph_ops.py update

## doctor            Sanity-check the framework is wired correctly
doctor:
	@$(XOPS)/doctor.py

## scaffold          Re-sync framework files from the agentic-workspace source repo
scaffold:
	@echo "xops/init/ is framework-only and not shipped to scaffolded projects."
	@echo "Re-run the scaffolder from the agentic-workspace repo instead:"
	@echo "  /path/to/agentic-workspace/xops/init/scaffold.sh --target $$(pwd) --help"

## skills.status     List all skills with line count, last-modified, and AGENTS.md refs
skills.status:
	@$(XOPS)/skills_ops.py status

## skills.find       Search skills by tag or name keyword (TAG=<tag>)
skills.find:
	@TAG="$(TAG)" $(XOPS)/skills_ops.py find

## security.secrets  Real secret scanner acceptance and index/worktree scan
security.secrets:
	@$(PYTHON) -m unittest xops.test.test_security_acceptance.SecretAcceptanceTests
	@scripts/secret_check.sh

## security.dependencies  Check resolved inventory, licenses and vulnerabilities
security.dependencies:
	@$(PYTHON) -m unittest xops.test.test_dependency_inventory xops.test.test_dependency_scan xops.test.test_security_acceptance.DependencyAcceptanceTests
	@scripts/vuln_check.sh

## dart.test         Run Dart package tests
dart.test:
	@scripts/dart_test.sh

## dart.lint         Run Dart static analysis
dart.lint:
	@scripts/dart_lint.sh

## dart.format.check Check Dart formatting
dart.format.check:
	@scripts/dart_format.sh --check

## dart.format       Format Dart code
dart.format:
	@scripts/dart_format.sh

## verify            Verify the static Flutter PWA and produce its release build
verify:
	@bash scripts/web_verify.sh

## verify.contracts  Current static PWA gate (also used by the local commit hook)
verify.contracts: verify

## test              Test current browser runtime, shared rules and static cache
test:
	@bash scripts/web_verify.sh --tests-only

## web.build         Build the static production artifact for psychosim.com
web.build:
	@bash scripts/web_build.sh

## web.smoke         Test the production artifact in Chromium (npm ci first)
web.smoke:
	@node scripts/web_smoke.mjs

## build             Build the current static Flutter PWA
build: web.build
## lint              Analyze the current Dart/Flutter modules
lint: dart.lint
## format            Format current Dart/Flutter modules
format: dart.format
## format.check      Check current Dart/Flutter formatting
format.check: dart.format.check
## security.privacy  Verify browser saves and memory-only AI credentials
security.privacy:
	@bash scripts/web_privacy_check.sh

WEB_PORT ?= 18763
## web.serve         Serve the production build locally on a dedicated PWA origin
web.serve:
	@test -f app/build/web/index.html || { echo "Run make web.build first." >&2; exit 1; }
	@$(PYTHON) -m http.server $(WEB_PORT) --bind 127.0.0.1 --directory app/build/web
