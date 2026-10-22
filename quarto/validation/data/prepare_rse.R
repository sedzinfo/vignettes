##########################################################################################
# PREPARE df_rse.rda FROM THE OPEN-SOURCE PSYCHOMETRICS PROJECT ROSENBERG SELF-ESTEEM DATA
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (RSE.zip, 47,974 records of the Rosenberg
# Self-Esteem Scale; see codebook.txt inside the zip). Only respondents who confirmed that
# their answers were accurate and could be used for research are in the file.
# The codebook lists gender as "1=male, 3=female, 3=other"; the data contain the codes 0-3
# with 2 the most frequent, so 1 = male, 2 = female, 3 = other, 0 = not chosen.
# The vignette loads the result (data/df_rse.rda); this script only has to run again to
# change the cleaning rules.
#
# From quarto/validation/:
#   Rscript data/prepare_rse.R                   # downloads the zip
#   Rscript data/prepare_rse.R path/to/data.csv  # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  csv <- args[1]
} else {
  zip <- tempfile(fileext = ".zip")
  options(timeout = 600)
  download.file("https://openpsychometrics.org/_rawdata/RSE.zip", zip, mode = "wb")
  unzip(zip, exdir = tempdir())
  csv <- file.path(tempdir(), "RSE", "data.csv")
}
raw <- read.delim(csv, stringsAsFactors = FALSE)
items <- paste0("Q", 1:10)
x <- as.matrix(raw[, items])
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
rules <- data.frame(
  complete      = rowSums(x < 1 | x > 4) == 0,                    # 0 = no answer
  plausible_age = raw$age >= 13 & raw$age <= 80,                   # 0 = could not be read
  not_flat      = apply(x, 1, function(r) length(unique(r)) > 1)   # same answer to all 10 items
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
##########################################################################################
# SAVE: item responses as answered (1-4, negatively worded items not reversed), gender, age,
# source and country
##########################################################################################
df_rse <- raw[keep, items]
df_rse$gender  <- factor(raw$gender[keep], levels = 1:3, labels = c("Male", "Female", "Other"))
df_rse$age     <- raw$age[keep]
df_rse$source  <- factor(raw$source[keep], levels = 1:3, labels = c("Test website", "Google", "Other"))
df_rse$country <- raw$country[keep]
rownames(df_rse) <- NULL
attr(df_rse, "cleaning") <- cleaning

save(df_rse, file = "data/df_rse.rda", compress = "xz")
