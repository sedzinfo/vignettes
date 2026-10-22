##########################################################################################
# PREPARE df_ipipneo120.rda FROM JOHNSON'S IPIP-NEO-120 DATA (OSF)
##########################################################################################
# Source: Johnson, J. A. (2014), data repository https://osf.io/wxvth/ (IPIP120.dat, 619,150
# records collected online 2001-2011; layout in DAT120.doc). Scoring key: data/ipipneo120_key.csv,
# taken from IPIP-NEO-ItemKey.xls in https://osf.io/ycvdk/ (the 120 items of the IPIP-NEO-300).
# In the data file the - keyed items are already reverse-scored, so item scores can be averaged
# as they are.
# The vignette loads the result (data/df_ipipneo120.rda); this script only has to run again to
# change the cleaning rules or the sample.
#
# From quarto/validation/:
#   Rscript data/prepare_ipipneo120.R                     # downloads IPIP120.dat (95 MB)
#   Rscript data/prepare_ipipneo120.R path/to/IPIP120.dat # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  dat <- args[1]
} else {
  dat <- tempfile(fileext = ".dat")
  options(timeout = 1800)
  download.file("https://osf.io/download/q9jrh/", dat, mode = "wb")
}
key <- read.csv("data/ipipneo120_key.csv", stringsAsFactors = FALSE)
##########################################################################################
# READ THE FIXED-WIDTH FILE (columns from DAT120.doc; short lines are missing trailing items)
##########################################################################################
lines <- readLines(dat)
start <- c(1, 7, 8, 20, 23, 31 + 1:120)
end   <- c(6, 7, 9, 22, 31, 31 + 1:120)
fields <- c("case", "sex", "age", "year", "country", paste0("I", 1:120))
raw <- as.data.frame(setNames(lapply(seq_along(start), function(j) trimws(substr(lines, start[j], end[j]))), fields),
                     stringsAsFactors = FALSE)
for (v in setdiff(fields, "country")) raw[[v]] <- suppressWarnings(as.integer(raw[[v]]))
rm(lines)

x <- as.matrix(raw[, key$item])
x[x == 0] <- NA                                                   # 0 = item skipped
##########################################################################################
# EVEN-ODD CONSISTENCY (Johnson, 2005): the 4 items of each facet are split into the 1st+3rd
# and 2nd+4th, the 30 pairs of half scores are correlated within the person and corrected
# with Spearman-Brown
##########################################################################################
position <- ave(seq_len(nrow(key)), key$facet_code, FUN = seq_along)
half <- function(odd) sapply(unique(key$facet_code), function(f)
  rowMeans(x[, key$facet_code == f & (position %% 2 == 1) == odd, drop = FALSE], na.rm = TRUE))
odd <- half(TRUE); even <- half(FALSE)
r_oe <- vapply(seq_len(nrow(x)), function(i) suppressWarnings(cor(odd[i, ], even[i, ])), numeric(1))
even_odd <- 2 * r_oe / (1 + r_oe)
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
rules <- data.frame(
  complete      = rowSums(is.na(x)) == 0,
  sex_recorded  = raw$sex %in% 1:2,
  plausible_age = !is.na(raw$age) & raw$age >= 14 & raw$age <= 80,
  consistent    = !is.na(even_odd) & even_odd >= 0.30
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
##########################################################################################
# SAMPLE: 30,000 from the USA (sex and age comparisons within one country) and up to 3,000
# from each of 11 other countries (cross-country comparisons); the country names in the file
# are cut to 9 characters
##########################################################################################
countries <- c("USA" = "USA", "Canada" = "Canada", "UK" = "UK", "Australia" = "Australia",
               "Ireland" = "Ireland", "New Zeala" = "New Zealand", "Singapore" = "Singapore",
               "India" = "India", "Philippin" = "Philippines", "Netherlan" = "Netherlands",
               "Sweden" = "Sweden", "Germany" = "Germany")
cap <- ifelse(names(countries) == "USA", 30000, 3000)
set.seed(2014)
rows <- unlist(lapply(seq_along(countries), function(i) {
  pool <- which(keep & raw$country == names(countries)[i])
  if (length(pool) > cap[i]) sample(pool, cap[i]) else pool
}))
##########################################################################################
# SAVE: item scores (1-5, - keyed items already reversed), sex, age, country, year
##########################################################################################
df_ipipneo120 <- as.data.frame(x[rows, ])
df_ipipneo120[] <- lapply(df_ipipneo120, as.integer)
df_ipipneo120$sex     <- factor(raw$sex[rows], levels = 1:2, labels = c("Male", "Female"))
df_ipipneo120$age     <- raw$age[rows]
df_ipipneo120$country <- factor(unname(countries[raw$country[rows]]), levels = unname(countries))
df_ipipneo120$year    <- raw$year[rows] + 1900
rownames(df_ipipneo120) <- NULL
attr(df_ipipneo120, "cleaning") <- cleaning

save(df_ipipneo120, file = "data/df_ipipneo120.rda", compress = "xz")
print(table(df_ipipneo120$country))
