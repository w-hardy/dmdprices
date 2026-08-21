# Vendored Claude Skills

These skills are vendored from [w-hardy/skills](https://github.com/w-hardy/skills)
at `main` (`695c3fa`), a fork of [posit-dev/skills](https://github.com/posit-dev/skills)
(MIT © 2025 Posit PBC). The `superpowers` skills originate from
[obra/superpowers](https://github.com/obra/superpowers).

They give Claude Code task-specific guidance for the work this repository
actually involves: R-package development, `cli` messaging, lifecycle and
deprecation, CRAN preparation, releases, PR workflows, Shiny/bslib apps,
Posit Connect deployment, and code review.

## What's here

| Category | Skills |
|---|---|
| R package dev (`r-lib`) | `r-package-development`, `testing-r-packages`, `cli`, `cran-extrachecks`, `lifecycle` |
| Open source | `release-post`, `create-release-checklist`, `maintainer-decline` |
| GitHub | `pr-create`, `pr-threads-address`, `pr-threads-resolve` |
| General dev (`posit-dev`) | `critical-code-reviewer`, `describe-design`, `implement`, `new-work`, `review-testing`, `working-on` |
| Dev workflow (`superpowers`) | `systematic-debugging`, `test-driven-development`, `verification-before-completion` |
| Shiny | `shiny-bslib`, `shiny-bslib-theming`, `brand-yml` |
| Deployment | `deploy-to-connect` |

## What is deliberately omitted

- **Quarto authoring** — vignettes here are `.Rmd` (knitr/rmarkdown), not `.qmd`.
- **`ggsql`** — this package does not generate SQL.
- **`mirai`** — no async, parallel, or distributed code in the package.
- **`r-cli-app`** — this is a library, not a Rapp command-line tool.
- **`alt-text`** — the package ships no figures or images to describe.
- **HTA, biostatistics, and clinical-ML skills** — these guide how to *carry out*
  health-economic and statistical analysis. `dmdprices` supplies cost *inputs* to
  that work; it does not perform it. They belong in analysis projects that consume
  this package, not here.
- **Remaining `superpowers` skills** — the planning, orchestration, and
  code-review entries overlap the `posit-dev` skills above, and
  `using-superpowers` is an always-on skill that would reshape default behaviour.

## Updating

These are a snapshot. To refresh, re-copy the skill folders listed above from
`w-hardy/skills` at `main`. Each folder is self-contained (`SKILL.md` plus any
`references/` and `scripts/`). Upstream author-side artefacts — `.evals/`,
`CREATION-LOG.md`, and `test-pressure-*.md` — are intentionally not vendored.
