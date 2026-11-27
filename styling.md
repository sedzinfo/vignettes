# Styling: the R code of the Illustrations pages

The pages of `quarto/illustration/` (the "data stories" site) are being rewritten one page at a time in the compact style of the hand-written code in rwf. Each page keeps the same output; only the code changes. These notes hold the rules, how a page is checked, and where the work stands.

## Code style

- **Compact spacing.** No spaces around `<-`, `=` or operators, none after commas, none between `if`/`for` and the bracket: `x<-f(a,b=1)`, `if(n>0)`, `for(k in names(x))`.
- **Base R for the data.** Subsetting, `aggregate()`, `merge()`, `tapply()`, `ave()`, `split()` with `lapply()`, `order()`, `rbind()`. No dplyr or tidyr verbs (equivalents below).
- **No named functions inside functions.** A helper is a function of its own, at the top level of a chunk. Anonymous functions are fine: in `lapply()`, `sapply()` and `vapply()`, as `tryCatch()` handlers, and as callbacks such as `done=function(r) ...`.
- **snake_case names**, helpers named for what they do: `get_contrast_color()`, `count_sorted()`, `distance_km()`.
- **An explicit `return()`** at the end of every named function: `result<-...` then `return(result)`, or `return(x)` when the function returns a variable as it is.
- **Lines of at most 100 characters, one statement to a line** (no `;`). `#| fig-alt` lines may be longer.
- **Continued lines** line up under their opening bracket. After an argument that spans several lines, the next argument starts a new line, unless it is short and the last (`quiet=TRUE)`). A `data.frame()` made for a table gets one column to a line.
- **Long strings** are cut into `paste0()` pieces only when their line would be too long. Text is cut after a full stop or semicolon where possible; a web address is cut before its `?` or at a `/`.
- **An expression that repeats is named once**: `from_now<-xy_now[seq(1,nrow(xy_now),by=2),]`.
- **Comments** are lower case and say what a step is for. A comment of several lines is wrapped as one paragraph.
- **Chains:** `%>%` for plotly, with the next steps indented by two. ggplot layers end their line with `+`, one layer to a line. No `|>`.
- **One-statement `if` without braces:** the statement goes on the next line, indented by two.
- **The setup chunk** (hidden on the page) in one compact form, followed by the page's own lines:

  ```r
  directory<-""
  if(rstudioapi::isAvailable())
    directory<-paste0(dirname(rstudioapi::getActiveDocumentContext()$path),"/")
  source(paste0(directory,"R/code_options.R"))
  ```

  Pages restyled before this rule get it in one batch when all pages are done (a re-render pulls fresh data).
- **Code shown to readers but not run** (a plain code block, a chunk with `eval=FALSE`) follows the same style, and stays in step with the code it stands for.
- **Kept as they are:** chunk labels (they name the figure files in `_freeze/`), `#| fig-alt` lines, and code quoted from someone else (efg's script in the colour chart).

From the earthquakes page (the chart shortened):

```r
# the distance in kilometres between two points (longitude and latitude in degrees)
distance_km<-function(lon1,lat1,lon2,lat2) {
  r<-pi/180
  h<-sin((lat2-lat1)*r/2)^2+cos(lat1*r)*cos(lat2*r)*sin((lon2-lon1)*r/2)^2
  result<-12742*asin(sqrt(h))
  return(result)
}
```

```r
plot_ly(bars,x=~deaths,y=~name,type="bar",orientation="h",
        marker=list(color=ifelse(bars$deaths==max(bars$deaths),red,gray)),text=~number(deaths),
        textposition="outside",cliponaxis=FALSE,showlegend=FALSE) %>%
  chart(paste0("Deaths in earthquakes since ",since,", 10 countries"),
        "NCEI Significant Earthquake Database. Deaths as recorded, in the country that NCEI names.",
        x_axis=list(range=c(0,1.3*max(bars$deaths)),showgrid=FALSE),note_y=-0.1)
```

## Charts

- **plotly as a rule**, because these are web pages. A static ggplot chart becomes a plotly chart when its page is restyled.
- **Kept as they are:**
  - animations saved as GIF with gganimate, such as Gapminder, together with the static steps that build them;
  - the colour chart, whose subject is base graphics;
  - the illusions, which are grid drawings;
  - the highcharter page, whose subject is highcharter.
- **The `chart()` helper** of each page sets the title, puts the source as a note under the chart, and applies the common layout. A ggplot subtitle goes into the title or the note.
- **Panels** (`facet_wrap`) become `subplot()`. Each panel's title is an annotation placed from the domains in `plotly_build(p)$x$layout`.
- **Colour classes** on a map or calendar are a `colorscale` of steps with `zmin`/`zmax`, and a colour bar shows the class names (see the earthquake country map).
- **Overlapping labels** are left out, as ggplot's `check_overlap` did. The point keeps its colour and its hover text.
- **A hover text for many points** is set with `style(hovertemplate=...)`: given to `plot_ly()`, plotly repeats it for every point (the decomposition of AIRPORT_WEATHER shrank from 3.1 MB to 0.8 MB). Pass the data as a data frame with formulas (`x=~date`), not as vectors, which plotly keeps a second copy of.
- **A page with several plotly or highcharter charts** turns the knitr cache off (`knitr::opts_chunk$set(cache=FALSE)` in the setup chunk, as most pages do): when some chunks come from the cache and one runs again, the new chart can get the same id as a cached one, and then it does not draw.
- **A package that is no longer used** comes out of `library()`, out of the install comment, and out of the footer (`*Rendered with R ... · plotly · sf*`).
- **The PNG of a converted chart** stays in `_freeze/<page>/figure-html/` after the render, because Quarto does not remove it. Delete it once the freeze no longer refers to it.

## dplyr to base R

| dplyr | base R | watch |
| --- | --- | --- |
| `filter(x,cond)` | `x[which(cond),]` | `filter()` drops rows where the condition is `NA`, and so does `which()` |
| `arrange(x,desc(v))` | `x[order(-x$v),]` | both keep ties in their order |
| `count(x,v,sort=TRUE)` | `table()` or `unique()`, then `order(-n,v,method="radix")` | dplyr sorts text in the C locale (capitals first), and so does `method="radix"`; `sort()` and `factor()` follow the system locale |
| `group_by()` + `summarise()` | `aggregate(y~g,data,FUN,na.action=na.pass)`, or `split()` + `lapply()` + `do.call(rbind,...)` | `aggregate()` drops `NA` values (hence `na.pass`) and `NA` groups; `split(x,addNA(factor(g),ifany=TRUE))` keeps them |
| `slice_max(v,n=1,with_ties=FALSE)` | `x[which.max(x$v),]` | |
| `group_by()` + `mutate()` | `ave(x$v,x$g,FUN=mean)` | |
| `inner_join()` | `merge()` | `merge()` sorts by the key |
| `right_join()` + `coalesce(n,0L)` | `table(factor(x,levels=all_values))` | dplyr puts the rows without a match last |
| `distinct(x,a,b)` | `unique(x[,c("a","b")])` | |
| `n_distinct(v)` | `length(unique(v))` | |
| `case_when()` | `result<-rep(other,n)`, then `result[cond]<-value` | |
| `bind_rows(pages)` | add each page's missing columns as `NA`, then `do.call(rbind,pages)` | |
| `summarise(across(all_of(cols),sum))` | `aggregate(x[cols],list(group=x$group),sum)` | |

After reordering rows, set `rownames(x)<-NULL`: dplyr numbers the rows again, and `kable()` would otherwise print the old row names. `summarise()` returns a tibble but base R returns a data frame, so `x[,"a"]` gives a vector.

## Checking a page

The new code must give the same page as the old one:

1. Knit both versions, main's and the new one, with the same settings and at the same time, because the data are downloaded when a page is knitted.
2. Compare the output without the code:
   - the text, with its inline numbers;
   - the printed tables;
   - the JSON of each plotly chart;
   - each static figure, pixel by pixel (GIFs frame by frame).
3. Only intended differences may remain: a chart converted to plotly, the footer, or a name changed on purpose. Look at each converted chart in the browser.

Some published freezes are older than `_shared/_figures.yml` and have other figure sizes. That is why both versions are knitted again rather than compared with the freeze.

## Workflow

- The work happens in a worktree, `~/GitHub/vignettes-worktrees/personal-style` (branch `personal-style`).
- Render with `QUARTO_PATH=/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto Rscript render.R illustration --no-browser`.
- Once a page passes its check and renders, copy its `.Rmd` and `_freeze/<page>/` into `quarto/illustration/` here. First check that the files here have no changes of their own.
- Commits and pushes are made by hand.

## Pages

Done, checked and copied here:

- [x] COLOR_CHART: helpers in snake_case (`SetTextContrastColor` is now `get_contrast_color`); the table header `TextContrastColor` is now `contrast_colors`
- [x] GAPMINDER
- [x] GREEK_DEBT
- [x] GREEK_ECONOMY
- [x] GREEK_INVESTMENT: fixed `at()`, which compared a vector of years with `==`, so the average FDI of 2021–2025 used 2021 only (3.0%, now 3.2%)
- [x] GREEK_WORKFORCE
- [x] GREEK_POPULATION
- [x] GREEK_EMIGRATION
- [x] GREEK_TOURISM
- [x] AI_LAYOFFS
- [x] NATURAL_DISASTERS: no dplyr or ggplot2 left
- [x] WORLD_EARTHQUAKES: the yearly counts are a plotly chart of three panels
- [x] WORLD_VOLCANOES: the decade chart and the deaths timeline are plotly
- [x] WORLD_TSUNAMIS: NOAA's pages arrive in the order in which they finish and are now put in page order, so the map draws its points in the same order on every render
- [x] WORLD_WILDFIRES: the trend chart (eight panels, one y scale for all, as before) and the season calendar are plotly; the calendar's title is shorter and its subtitle is now the legend's title; the panels show the change with a minus sign (−) where the ggplot font needed a dash (–)

- [x] FERTILITY, EURO_CRISIS, GREECE_SINCE_2000: dplyr and tidyr gone; output identical (these read local data files); the reader's "another country" snippet of GREECE_SINCE_2000 is base R too
- [x] GREEK_HOUSING, EU_SALARY: dplyr and tidyr gone, the GIFs stay ggplot; output identical, GIFs frame by frame. `eu_salary_race.gif` (tracked, linked directly) has two more years of Eurostat data than the committed one
- [x] GREEK_WAGES_PRICES: charts and GIFs identical; the first table now prints as a data frame (dplyr's `group_by()` had made it a tibble), with the same values
- [x] CLIMATE_HIGHCHARTER: highcharter kept; dplyr, tidyr, reshape, stringr and lubridate replaced by base R; output identical
- [x] ILLUSIONS: only the setup chunk; the drawings are quoted code ("not written by me") and stay as they are
- [x] SEA_ICE: the time series is plotly; the two maps stay ggplot for now (see the question below)
- [x] SEA_ICE_TEMP: base R instead of dplyr and tidyr, unused packages out (dplyr, tidyr, lubridate, reshape, rnoaa); the two GIFs stay ggplot. The spiral's data were checked object by object, and both GIFs frame by frame. A full render takes about 3 minutes here, not the 1–2 hours the page mentions
- [x] AIRPORT_WEATHER: base R (plyr, dplyr and lubridate gone) and plotly (ggplot2 and ggfortify gone). The daily band is a bar for each day, from its lowest to its highest temperature, coloured by the highest; the monthly band shows the highest temperatures as coloured points; the heatmaps keep a value in each cell; "All four together" and the decomposition are stacked plotly panels. The page could not run since early October because of `plot_multiplot()` (fixed, see below), and now no longer uses it
- [x] WORLD_FLOODS: no dplyr or ggplot2 left; text, tables and the two plotly charts identical; the deaths panels, the season calendar and the yearly counts are plotly (two years that tie for the most both stay red, as before); a comment that said 10,000 km² now says 25,000, as the code does
- [x] WORLD_TORNADOES: no dplyr or ggplot2 left; text, five tables and the three plotly charts identical; the calendar of the divisions, the hours of the day, the deaths of each year and the four trend panels are plotly; six variables that the page computed but never used are gone (`strong_states`, `deadliest_day`, `deadliest_rating`, `unrated_modern`, `canada_provinces`, `estimated`)
- [x] ATHENS_HEAT: no dplyr or ggplot2 left; text and all tables identical; the seven charts (stripes, the station against ERA5-Land, hot days, tropical nights, the calendar of every day, the season curves and the heatwaves) are plotly; three functions that were defined inside other functions are now top-level (`reported`, `day_number`, `month_word`)
- [x] GREEK_WILDFIRES: no dplyr left; text, both tables, the two maps and the three plotly charts identical; the season calendar is plotly, a cell for each day coloured by its class of heat, with the megawatts in the hover text; the two maps stay ggplot (see the question below)

To do:

- [ ] The setup chunk on the first fifteen pages above (COLOR_CHART to WORLD_WILDFIRES), in one batch (see **The setup chunk**)

Open questions:

- **sf maps:** SEA_ICE draws sf polygons in a polar projection, in twelve panels; GREEK_WILDFIRES draws the outline of every fire, on Greece and on Attica. As plotly they would put every point of every outline in the page (megabytes for SEA_ICE), so they are still ggplot. Keep them as an exception?

Fixed along the way: `plot_multiplot()` called `viewport()` and `grid.layout()` without `grid::`. Inside the rwf package that works (the package imports them), but in the copies of `R/code_rwf.R` that the pages source it stops the page. Fixed in rwf (`working_functions/FUNCTIONS_PLOT.R` and `rwf/R/FUNCTIONS_PLOT.R`, not committed there) and in the four copies here (illustration, example, validation, cat_irt_eap). EXAMPLE_GENERALIZED, EXAMPLE_LDA and VALIDATION_DESCRIPTIVES_OCEAN use it too and would have stopped the same way when run again.
