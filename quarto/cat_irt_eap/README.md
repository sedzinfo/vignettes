# EAP Ability Estimation in base R

Quarto website with the EAP tutorials. A GitHub Action renders it into the repository's `docs/cat_irt_eap/` folder, which GitHub Pages serves.

## Structure

| Path | Purpose |
|---|---|
| `_quarto.yml` | Site settings: navbar, sidebar, theme, knitr options |
| `index.qmd` | Home page with a card for each tutorial |
| `*.Rmd` | Tutorials |
| `R/` | Functions sourced by the tutorials |
| `styles.css` | Code and output colours |
| `_freeze/` | Saved results; documents are only re-run when they change (commit it) |
| `_site/` | Local render output (ignored by git) |

## Render

```bash
quarto render                 # whole site
quarto render eap_rsm.Rmd     # one page
quarto preview                # live preview while editing
```

In RStudio use the **Build** pane > **Render Website**.

## Add a tutorial

1. Add `new_page.Rmd` with a `title:` and `description:` in its front matter.
2. List it in `_quarto.yml` (navbar and sidebar) and in `index.qmd` (listing).
3. Commit and push. The Action renders and publishes it.

## Publish

Push changes under `quarto/` to `main`. The workflow `.github/workflows/render-quarto.yml` renders the site, copies it to `docs/cat_irt_eap/`, commits the result and any updated `_freeze/`.

Site: https://sedzinfo.github.io/vignettes/cat_irt_eap/
