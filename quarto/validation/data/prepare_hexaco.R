##########################################################################################
# PREPARE df_hexaco.rda FROM THE OPEN-SOURCE PSYCHOMETRICS PROJECT HEXACO DATA
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (HEXACO.zip, 22,786 records of the 240-item
# IPIP-HEXACO scales; see codebook.txt inside the zip).
# Scoring key: data/hexaco_key.csv, matched item by item to the official key at
# https://ipip.ori.org/newHEXACO_PI_key.htm (keying and published facet alphas). The codebook
# does not give the keying; within every facet the + keyed items are numbered first.
# The vignette loads the result (data/df_hexaco.rda); this script only has to run again to
# change the cleaning rules.
#
# From quarto/validation/:
#   Rscript data/prepare_hexaco.R                   # downloads the zip
#   Rscript data/prepare_hexaco.R path/to/data.csv  # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  csv <- args[1]
} else {
  zip <- tempfile(fileext = ".zip")
  options(timeout = 600)
  download.file("https://openpsychometrics.org/_rawdata/HEXACO.zip", zip, mode = "wb")
  unzip(zip, exdir = tempdir())
  csv <- file.path(tempdir(), "HEXACO", "data.csv")
}
raw <- read.delim(csv, stringsAsFactors = FALSE)
key <- read.csv("data/hexaco_key.csv", stringsAsFactors = FALSE)

x <- as.matrix(raw[, key$item])
x[x == 0] <- NA                                                   # 0 = item skipped
##########################################################################################
# EVEN-ODD CONSISTENCY (Johnson, 2005): each facet is split into its odd- and even-numbered
# items (after reverse-keying), the 24 odd and 24 even half scores are correlated within the
# person and corrected with Spearman-Brown. Random responding gives values near 0.
##########################################################################################
scored <- x
scored[, key$key == "-"] <- 8 - scored[, key$key == "-"]
facet  <- substr(key$item, 1, 5)
number <- as.integer(substring(key$item, 6))
half <- function(odd) sapply(unique(facet), function(f)
  rowMeans(scored[, facet == f & (number %% 2 == 1) == odd, drop = FALSE], na.rm = TRUE))
odd <- half(TRUE); even <- half(FALSE)
r_oe <- vapply(seq_len(nrow(x)), function(i) suppressWarnings(cor(odd[i, ], even[i, ])), numeric(1))
even_odd <- 2 * r_oe / (1 + r_oe)
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
elapse <- suppressWarnings(as.numeric(raw$elapse))
rules <- data.frame(
  complete          = rowSums(is.na(x)) == 0,
  understood        = raw$V1 >= 5,               # "I understand the instructions": at least slightly agree
  accurate          = raw$V2 >= 5,               # "I have answered ... as accurately as possible"
  not_too_fast      = !is.na(elapse) & elapse >= 2 * nrow(key),   # at least 2 seconds per item
  consistent        = !is.na(even_odd) & even_odd >= 0.30
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
##########################################################################################
# SAVE: raw item responses (1-7, not yet reverse-keyed), country and the consistency index
##########################################################################################
df_hexaco <- as.data.frame(x[keep, ])
df_hexaco[] <- lapply(df_hexaco, as.integer)
df_hexaco$country  <- raw$country[keep]
df_hexaco$even_odd <- round(even_odd[keep], 3)
rownames(df_hexaco) <- NULL
attr(df_hexaco, "cleaning") <- cleaning

save(df_hexaco, file = "data/df_hexaco.rda", compress = "xz")
