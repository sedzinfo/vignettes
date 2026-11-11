# vignettes

---

## Overview

Tutorials and worked examples in R, published as Quarto websites with GitHub Pages: https://sedzinfo.github.io/vignettes/

Most functions used in the tutorials come from the [rwf](https://github.com/sedzinfo/rwf) package, sourced from `code_rwf.R` so the pages render without installing it.

## Structure

| Path | Purpose |
|---|---|
| `quarto/<site>/` | One Quarto website per folder: pages (`.Rmd`), `_quarto.yml`, `index.qmd`, `styles.css` |
| `quarto/<site>/_freeze/` | Saved results of each page. GitHub reuses them instead of running the R code (commit it) |
| `quarto/_shared/` | Used by every site: `styles.scss` (styles), `_ga_consent.html` (cookie banner and analytics) and `_mobile.html` (phones: wide tables scroll, plotly charts fit the screen) |
| `docs/` | Published sites, written by the GitHub workflow (do not edit) |
| `render.R` | Renders the sites locally into `_preview/` |
| `.github/workflows/render-quarto.yml` | Renders changed sites into `docs/<site>/` on every push |
| `.github/scripts/build_index.py` | Builds the landing page `docs/index.html`, one card per site |

![Stars](https://img.shields.io/github/stars/sedzinfo/vignettes)
![Watchers](https://img.shields.io/github/watchers/sedzinfo/vignettes)
![Repo Size](https://img.shields.io/github/repo-size/sedzinfo/vignettes)
![Open Issues](https://img.shields.io/github/issues/sedzinfo/vignettes)
![Forks](https://img.shields.io/github/forks/sedzinfo/vignettes)
![Last Commit](https://img.shields.io/github/last-commit/sedzinfo/vignettes)
![Contributors](https://img.shields.io/github/contributors/sedzinfo/vignettes)
![License](https://img.shields.io/github/license/sedzinfo/vignettes)
![Release](https://img.shields.io/github/v/release/sedzinfo/vignettes)
![Workflow Status](https://img.shields.io/github/actions/workflow/status/sedzinfo/vignettes/render-quarto.yml)
