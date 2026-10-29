# Source Control and Documentation Maintenance

No `.github` workflow directory is present in the reviewed checkout; no automated CI, branch protection, build publication or deployment pipeline is claimed. The steps below are a manual team workflow, not implemented GitHub automation.

1. Start with `git status` and preserve other contributors' uncommitted changes. Keep task scope explicit. Follow repository `AGENTS.md`; use a focused branch (`codex/` prefix for agent-created branches unless otherwise requested).
2. Inspect affected code, models and Rules before editing documentation or implementation. Update the relevant canonical guide rather than adding another conflicting summary.
3. For code changes, format Dart, run analysis/relevant tests and complete required regression checks. For documentation-only changes, validate links and source-backed claims; do not format or modify someone else's application code just to refresh docs.
4. Review `git diff --check`, changed paths and secret hygiene. Never commit `.dev.vars`, `.env` credentials, service-account JSON, signing keys, private audit exports, node_modules or `.orglink-demo` manifests/cache. Native Firebase public app configuration is different from privileged credentials and must retain its configured project identity.
5. In a PR/handover, state the behavior changed, source evidence, exact validation commands/results, warnings, and remote/manual actions not performed. Local passing tests must not be described as deployed acceptance.
6. Review and merge using the team's existing repository policy. Git merge does not authorize deployment, migration, demo apply/cleanup or provisioning. Perform those as separately approved operator actions.

When behavior changes, update [documentation index](README.md), the owning module guide and [current QA](current-version-qa-audit.md) as applicable. Record dated test evidence, not a growing undifferentiated list of “all tests pass” claims. Historical migration reports remain historical even if their filenames contain “current” or “verified”.
