##########################################################################################
# PREVIEW IMAGES OF THE PAGES, FOR THE CARDS OF A SITE'S INDEX
##########################################################################################
# Takes a screenshot of one chart of every page of a site and saves it as
# quarto/<site>/thumbnails/<page>.webp (800 px wide), the image on the page's card in
# index.qmd. It reads the rendered pages in _preview/<site>/, so plotly and highcharter
# charts come out as they look in a browser. Needs Google Chrome and the chromote package.
# From the repo root:
#   Rscript render.R illustration --no-browser                      # render the pages first
#   Rscript quarto/_shared/thumbnails.R illustration                # write the thumbnails
#   Rscript quarto/_shared/thumbnails.R illustration --candidates   # the first four charts of
#                                                                   # every page, to choose from
# Candidates go to _preview/thumbnail-candidates/<site>/ as <page>_<n>.webp. The chart of each
# page is set in `charts` below: 1 is the first chart on the page, 2 the second, and so on.
##########################################################################################
library(chromote)
library(magick)

# the chart on the card of each page; a page that is not listed gets its first chart
charts <- list(
  illustration = c(
    ILLUSTRATION_AI_LAYOFFS = 1,           # job cuts blamed on AI, by year
    ILLUSTRATION_AIRPORT_WEATHER = 1,      # daily temperature ribbon
    ILLUSTRATION_ATHENS_HEAT = 1,          # warming stripes of the summers
    ILLUSTRATION_CLIMATE_HIGHCHARTER = 1,  # temperature spiral
    ILLUSTRATION_COLOR_CHART = 2,          # colours sorted by hue
    ILLUSTRATION_EU_SALARY = 4,            # bar chart race (a frame of the GIF)
    ILLUSTRATION_EURO_CRISIS = 2,          # income per person, 2008 = 100
    ILLUSTRATION_FERTILITY = 2,            # world map of children per woman
    ILLUSTRATION_GAPMINDER = 4,            # the bubble chart (a frame of the GIF)
    ILLUSTRATION_GREECE_SINCE_2000 = 1,    # income per person
    ILLUSTRATION_GREEK_DEBT = 1,           # debt in billion euros
    ILLUSTRATION_GREEK_ECONOMY = 2,        # GDP by use
    ILLUSTRATION_GREEK_ELECTRICITY = 1,    # electricity by fuel since 1990
    ILLUSTRATION_GREEK_EMIGRATION = 1,     # people who left Greece each year
    ILLUSTRATION_GREEK_EXCESS_DEATHS = 1,  # deaths every week against the normal range
    ILLUSTRATION_GREEK_HOUSING = 1,        # house prices and rents since 2015
    ILLUSTRATION_GREEK_INVESTMENT = 3,     # 10-year bond yields
    ILLUSTRATION_GREEK_POPULATION = 1,     # population and projections
    ILLUSTRATION_GREEK_ROADS = 4,          # killed in cars and on two wheels since 1999
    ILLUSTRATION_GREEK_TOURISM = 2,        # nights by month, a heatmap
    ILLUSTRATION_GREEK_WAGES_PRICES = 1,   # wages, prices and real wages since 2015
    ILLUSTRATION_GREEK_WILDFIRES = 3,      # map of every fire EFFIS outlined
    ILLUSTRATION_GREEK_WORKFORCE = 3,      # below the basic PISA level
    ILLUSTRATION_ILLUSIONS = 1,            # the café wall
    ILLUSTRATION_NATURAL_DISASTERS = 2,    # disaster deaths by decade and kind
    ILLUSTRATION_OLIVE_OIL = 1,            # weekly prices at the markets since 2010
    ILLUSTRATION_SEA_ICE = 1,              # September minimum since 1979
    ILLUSTRATION_SEA_ICE_TEMP = 1,         # the sea ice map (a frame of the GIF)
    ILLUSTRATION_SEA_LEVEL = 3,            # map of the tide gauges of Greece
    ILLUSTRATION_WORLD_EARTHQUAKES = 1,    # map of the earthquakes and the plate boundaries
    ILLUSTRATION_WORLD_FLOODS = 2,         # map of the large floods in each country
    ILLUSTRATION_WORLD_TORNADOES = 2,      # map of the EF3+ tornadoes in the US
    ILLUSTRATION_WORLD_TSUNAMIS = 1,       # map of the tsunami sources by cause
    ILLUSTRATION_WORLD_VOLCANOES = 1,      # map of the volcanoes and the plate boundaries
    ILLUSTRATION_WORLD_WILDFIRES = 2       # world map of the land burnt each year
  )
)
##########################################################################################
# ARGUMENTS AND PATHS
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
candidates <- "--candidates" %in% args
args <- setdiff(args, "--candidates")
if (length(args) == 0) {
  stop("Usage: Rscript quarto/_shared/thumbnails.R <site> [<page> ...] [--candidates]")
}
site <- args[1]
only <- args[-1]                                 # some pages only, e.g. ILLUSTRATION_SEA_ICE
root <- getwd()
pages_dir <- file.path(root, "_preview", site)
if (!dir.exists(pages_dir)) {
  stop("No rendered pages in _preview/", site, ": run Rscript render.R ", site)
}
pages <- sub("\\.[Rr]md$", "", list.files(file.path(root, "quarto", site), pattern = "\\.[Rr]md$"))
if (length(only)) pages <- intersect(pages, only)
out_dir <- if (candidates) {
  file.path(root, "_preview", "thumbnail-candidates", site)
} else {
  file.path(root, "quarto", site, "thumbnails")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
##########################################################################################
# BROWSER
##########################################################################################
# 1200 px wide: the text column, and so every chart, has its desktop width (about 800 px);
# 1100 px high: a chart up to that height fits in the window and is cut out whole
b <- ChromoteSession$new(width = 1200, height = 1100)
# no cookie banner or footer from sedzinfo.github.io, no analytics
b$Network$enable()
b$Network$setBlockedURLs(urls = list("*sedzinfo.github.io/*", "*googletagmanager.com/*"))

# removes the fixed navbar, hides the toolbars of plotly and highcharter charts, and numbers the
# charts of the page in a data-thumb attribute: every htmlwidget and every image (png or gif) of
# the text that is at least 300 x 150 px
mark_charts <- "(() => {
  document.querySelectorAll('#quarto-header').forEach(e => e.remove());
  const style = document.createElement('style');
  style.textContent = '.modebar-container, .highcharts-exporting-group ' +
    '{ display: none !important; }';
  document.head.appendChild(style);
  const charts = [...document.querySelectorAll('main .html-widget, main img')].filter(e => {
    if (e.tagName === 'IMG' && e.closest('.html-widget')) return false;
    const r = e.getBoundingClientRect();
    return r.width >= 300 && r.height >= 150;
  });
  charts.forEach((e, i) => e.setAttribute('data-thumb', i + 1));
  return charts.length;
})()"
##########################################################################################
# SCREENSHOTS
##########################################################################################
for (page in pages) {
  b$go_to(paste0("file://", file.path(pages_dir, paste0(page, ".html"))))
  Sys.sleep(3)                                   # htmlwidgets draw after the page has loaded
  n <- b$Runtime$evaluate(mark_charts)$result$value
  if (n == 0) {
    message(page, ": no chart found")
    next
  }
  chosen <- unname(charts[[site]][page])
  if (length(chosen) == 0 || is.na(chosen)) chosen <- 1
  which_charts <- if (candidates) seq_len(min(n, 4)) else chosen
  for (k in which_charts) {
    # bring the chart to the top of the window, wait for charts that animate when they come
    # into view, then cut out its box (in page coordinates, at twice the screen resolution)
    chart <- sprintf("document.querySelector(\"[data-thumb='%d']\")", k)
    b$Runtime$evaluate(paste0(chart, ".scrollIntoView({block: 'start'})"))
    Sys.sleep(1.5)
    box <- b$Runtime$evaluate(paste0(
      "(() => { const r = ", chart, ".getBoundingClientRect();",
      " return JSON.stringify({x: r.left + scrollX, y: r.top + scrollY,",
      " width: r.width, height: Math.min(r.height, innerHeight)}); })()"
    ))$result$value
    clip <- c(jsonlite::fromJSON(box), scale = 2)
    shot <- b$Page$captureScreenshot(format = "png", clip = clip)
    file <- if (candidates) sprintf("%s_%d.webp", page, k) else paste0(page, ".webp")
    image_read(jsonlite::base64_dec(shot$data)) |>
      image_resize("800x") |>
      image_write(file.path(out_dir, file), format = "webp", quality = 80)
  }
  cat(page, ": ", n, " charts, saved ", paste(which_charts, collapse = ", "), "\n", sep = "")
}
b$close()
cat("Done:", out_dir, "\n")
