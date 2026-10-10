# vignettes

---

## Overview

Tutorials and worked examples in R, published as Quarto websites with GitHub Pages: https://sedzinfo.github.io/vignettes/

Most functions used in the tutorials come from the [rwf](https://github.com/sedzinfo/rwf) package, sourced from `code_rwf.R` so the pages render without installing it.

## Sites

| Site                    | Description |
|-------------------------|---|
| [EAP Ability Estimation](https://sedzinfo.github.io/vignettes/cat_irt_eap/) |  Computerised adaptive testing with EAP scoring, rebuilt step by step in base R for six IRT models and checked against catR |
| [Worked Examples in R](https://sedzinfo.github.io/vignettes/example/) | Decision trees, LDA, regularized regression, Keras, measurement invariance, multitrait-multimethod, Thurstonian IRT, adaptive testing and statistical paradoxes |
| [Illustrations in R](https://sedzinfo.github.io/vignettes/illustration/) | Data visualisation with real data: Arctic sea ice, global temperature, airport weather, Gapminder, EU wages, colour charts and optical illusions |
| [Scale Validation in R](https://sedzinfo.github.io/vignettes/validation/) | Item statistics, reliability, correlations and factor structure for the BFI-44 and the IPIP-50 (OCEAN) |

## Structure

| Path | Purpose |
|---|---|
| `quarto/<site>/` | One Quarto website per folder: pages (`.Rmd`), `_quarto.yml`, `index.qmd`, `styles.css` |
| `quarto/<site>/_freeze/` | Saved results of each page. GitHub reuses them instead of running the R code (commit it) |
| `docs/` | Published sites, written by the GitHub workflow (do not edit) |
| `render.R` | Renders the sites locally into `_preview/` |
| `.github/workflows/render-quarto.yml` | Renders changed sites into `docs/<site>/` on every push |
| `.github/scripts/build_index.py` | Builds the landing page `docs/index.html`, one card per site |

## Workflow

1. Edit or add a page in `quarto/<site>/`.
2. Render it locally, so the R code runs on your machine:
   - RStudio: open `render.R`, set `sites <- c("<site>")` and click **Source**.
   - Terminal: `Rscript render.R <site>`; add `--preview` for a live preview that updates on save.
3. Check the result in the browser, then commit the page together with `quarto/<site>/_freeze/` and push.
4. The workflow renders the changed sites from `_freeze/` without running R, commits `docs/`, and GitHub Pages publishes them.

Pages that need data downloads, Python (Keras/TensorFlow) or packages no longer on CRAN (`rnoaa`, `mstR`, `deepviz`) only run locally, so their `_freeze/` must always be committed.

## Add a site

1. Create `quarto/<name>/` with a `_quarto.yml` (copy one from another site and change `title`, `description`, `site-url` and the navbar), an `index.qmd`, `styles.css`, and the pages.
2. Render it with `render.R`, then commit the whole folder including `_freeze/`.
3. The site appears at `https://sedzinfo.github.io/vignettes/<name>/` with a card on the landing page.

## Comments

Each page has a comment box ([giscus](https://giscus.app)) set in `_quarto.yml`. Comments are stored in this repository's Discussions, one discussion per page.

## License

GPL-3, see [LICENSE](LICENSE).

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
