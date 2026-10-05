options(width=1000,future.show.progress = FALSE)
hook_output <- function(x, options) {
  paste0('<pre class="r-output">', knitr::knit_print(x), '</pre>')
}

knitr::opts_chunk$set(
  output     = hook_output,
  echo       = TRUE,
  message    = FALSE,
  warning    = FALSE,
  cache      = TRUE,
  fig.width  = 7,
  fig.height = 6,
  fig.align  = "center",
  dpi        = 300,
  fig.retina = 2,
  dev        = "ragg_png"
)

