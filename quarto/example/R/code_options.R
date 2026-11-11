options(width=1000)
hook_output <- function(x, options) {
  paste0('<pre class="r-output">', knitr::knit_print(x), '</pre>')
}
options(future.show.progress = FALSE)

knitr::opts_chunk$set(
  output     = hook_output,
  echo       = TRUE,
  message    = FALSE,
  warning    = FALSE,
  cache      = TRUE
)
# the size, resolution and device of the plots are set for every site in quarto/_shared/_figures.yml

