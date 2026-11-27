options(width=1000)

# no knitr cache on any page: the site keeps what was rendered in _freeze/, and a chart from a
# cached chunk can get the same id as a new chart, which then does not draw
knitr::opts_chunk$set(
  echo       = TRUE,
  message    = FALSE,
  warning    = FALSE,
  cache      = FALSE
)
# the size, resolution and device of the plots are set for every site in quarto/_shared/_figures.yml

