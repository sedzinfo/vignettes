##########################################################################################
# LINK-PREVIEW IMAGES OF THE QUARTO SITES
##########################################################################################
# Draws quarto/<site>/social-card.png for every site: 1200 x 630 px, the size that LinkedIn,
# Mastodon, Slack and X show in full when a link to the site is posted. Each _quarto.yml points
# to it with website: image, and open-graph / twitter-card put it in every page's <head>.
# The title comes from website: title in _quarto.yml; the line under it from taglines below.
# Re-run after changing either, from the repo root:
#   Rscript quarto/_shared/social_card.R
##########################################################################################
library(grid)

taglines <- c(
  cat_irt_eap  = "Computerised adaptive testing with EAP scoring, rebuilt step by step in base R for six IRT models",
  example      = "Machine learning, psychometrics, adaptive testing and statistics, with the R code on every page",
  illustration = "Data visualisation with real data: climate, Greece and the EU, Gapminder, colour and illusions",
  validation   = "Reliability, factor structure, invariance and IRT for personality, interest, symptom and ability tests"
)

navy <- "#2C3E50"; teal <- "#18BC9C"; light <- "#ECF0F1"; muted <- "#AEB6BF"   # Flatly, the theme of the sites
fonts <- systemfonts::system_fonts()$family
font <- c("Lato", "Segoe UI", "Helvetica", "Arial")
font <- font[font %in% fonts][1]
if (is.na(font)) font <- "sans"

draw_card <- function(file, title, tagline, url) {
  ragg::agg_png(file, width = 1200, height = 630, units = "px", res = 72, background = navy)
  on.exit(dev.off())
  grid.newpage()
  # background: item response curves, faint, on the right
  theta <- seq(-4, 4, length.out = 200)
  curves <- list(c(a = 1.0, b = -1.5, c = 0.00), c(a = 1.8, b = -0.3, c = 0.15),
                 c(a = 0.7, b = 0.6, c = 0.00), c(a = 2.6, b = 1.4, c = 0.05))
  pushViewport(viewport(x = 0.74, y = 0.5, width = 0.5, height = 0.78))
  for (k in curves) {
    p <- k[["c"]] + (1 - k[["c"]]) / (1 + exp(-1.7 * k[["a"]] * (theta - k[["b"]])))
    grid.lines((theta + 4) / 8, p, gp = gpar(col = teal, alpha = 0.22, lwd = 7, lineend = "round"))
  }
  popViewport()
  # accent bar, label, title, tagline, address
  grid.rect(x = 0, width = 0.012, just = "left", gp = gpar(fill = teal, col = NA))
  left <- unit(80, "points")
  grid.text("SEDZINFO  ·  R TUTORIALS", x = left, y = unit(630 - 92, "points"), just = c("left", "center"),
            gp = gpar(fontfamily = font, fontface = "bold", fontsize = 26, col = teal))
  title_lines <- strwrap(title, width = 22)
  title_top <- 630 - 175
  grid.text(paste(title_lines, collapse = "\n"), x = left, y = unit(title_top, "points"), just = c("left", "top"),
            gp = gpar(fontfamily = font, fontface = "bold", fontsize = 76, lineheight = 1.05, col = "white"))
  tagline_top <- title_top - 1.05 * 76 * length(title_lines) - 34
  grid.text(paste(strwrap(tagline, width = 46), collapse = "\n"), x = left, y = unit(tagline_top, "points"),
            just = c("left", "top"), gp = gpar(fontfamily = font, fontsize = 34, lineheight = 1.25, col = light))
  grid.text(url, x = left, y = unit(64, "points"), just = c("left", "center"),
            gp = gpar(fontfamily = font, fontsize = 26, col = muted))
}

root <- if (dir.exists("quarto")) "quarto" else stop("Run this from the repository root (the folder with quarto/).")
for (site in names(taglines)) {
  config <- yaml::read_yaml(file.path(root, site, "_quarto.yml"))
  url <- sub("^https?://", "", sub("/$", "", config$website$`site-url`))
  out <- file.path(root, site, "social-card.png")
  draw_card(out, config$website$title, taglines[[site]], url)
  cat(out, "\n")
}
cat("Font:", font, "\n")
