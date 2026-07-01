# Vendored Claude Skills

These skills are vendored from [posit-dev/skills](https://github.com/posit-dev/skills)
(MIT © 2025 Posit PBC) at `main`. They give Claude Code task-specific guidance for
R-package work in this repository — testing, `cli` messaging, lifecycle/deprecation,
CRAN preparation, releases, PR workflows, Shiny/bslib apps, and general code review.

## What's here

| Category | Skills |
|---|---|
| R package dev (`r-lib`) | `r-package-development`, `testing-r-packages`, `cli`, `cran-extrachecks`, `lifecycle`, `mirai`, `r-cli-app` |
| Open source | `release-post`, `create-release-checklist`, `maintainer-decline` |
| GitHub | `pr-create`, `pr-threads-address`, `pr-threads-resolve` |
| General dev (`posit-dev`) | `critical-code-reviewer`, `describe-design`, `implement`, `new-work`, `review-testing`, `working-on` |
| Shiny | `shiny-bslib`, `shiny-bslib-theming`, `brand-yml` |
| Visualisation | `alt-text` |

The Quarto-authoring and `ggsql` skills from upstream were intentionally omitted —
they are not relevant to this package.

## Updating

These are a snapshot. To refresh, re-copy the relevant skill folders from
upstream `main`. Each skill folder is self-contained (`SKILL.md` plus any
`references/` and `scripts/`).
