##########################################################################################
# PREPARE df_dass.rda FROM THE OPEN-SOURCE PSYCHOMETRICS PROJECT DASS DATA
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (DASS_data_21.02.19.zip, 39,775 records of
# the 42-item Depression Anxiety Stress Scales collected online in 2017-2019; see codebook.txt
# inside the zip). Answers are stored 1-4 (Q1A ... Q42A); DASS scoring uses 0-3, which the
# vignette applies. Q1E ... Q42E hold the time taken to answer each item in milliseconds.
# The vignette loads the result (data/df_dass.rda); this script only has to run again to
# change the cleaning rules.
#
# From quarto/validation/:
#   Rscript data/prepare_dass.R                   # downloads the zip
#   Rscript data/prepare_dass.R path/to/data.csv  # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  csv <- args[1]
} else {
  zip <- tempfile(fileext = ".zip")
  options(timeout = 1200)
  download.file("https://openpsychometrics.org/_rawdata/DASS_data_21.02.19.zip", zip, mode = "wb")
  unzip(zip, exdir = tempdir())
  csv <- file.path(tempdir(), "DASS_data_21.02.19", "data.csv")
}
raw <- read.delim(csv, stringsAsFactors = FALSE, quote = "", encoding = "UTF-8")   # tab-separated

answers <- paste0("Q", 1:42, "A")
times   <- paste0("Q", 1:42, "E")
tipi    <- paste0("TIPI", 1:10)
x  <- as.matrix(raw[, answers])
rt <- apply(as.matrix(raw[, times]), 1, median) / 1000   # median seconds per item
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
same_answer <- apply(x, 1, function(r) length(unique(r)) == 1)
record_cols <- c(answers, tipi, paste0("VCL", 1:16), "age", "gender", "country", "education",
                 "engnat", "race", "religion", "orientation", "married", "familysize", "major")
rules <- data.frame(
  complete      = rowSums(is.na(x) | x < 1 | x > 4) == 0,
  no_fake_words = raw$VCL6 == 0 & raw$VCL9 == 0 & raw$VCL12 == 0,  # "cuivocal", "florted", "verdid"
  not_too_fast  = rt >= 1,                                         # median time per item at least 1 s
  not_flat      = !(same_answer & x[, 1] != 1),                    # same answer to all 42, unless "did not apply"
  plausible_age = raw$age >= 13 & raw$age <= 80,
  not_duplicate = !duplicated(raw[, record_cols])                  # exact copy of an earlier record
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
d <- raw[keep, ]
##########################################################################################
# SAVE: item answers (1-4, as recorded), TIPI, a few demographics and the median item time
##########################################################################################
df_dass <- as.data.frame(x[keep, ])
names(df_dass) <- paste0("Q", 1:42)
df_dass[tipi] <- lapply(d[tipi], function(v) replace(v, v == 0, NA))   # 0 = skipped
df_dass[] <- lapply(df_dass, as.integer)
df_dass$gender    <- factor(d$gender, levels = 1:3, labels = c("Male", "Female", "Other"))
df_dass$age       <- as.integer(d$age)
df_dass$education <- factor(d$education, levels = 1:4,
                            labels = c("Less than high school", "High school", "University degree", "Graduate degree"))
df_dass$engnat    <- factor(d$engnat, levels = 1:2, labels = c("Yes", "No"))
df_dass$country   <- d$country
df_dass$median_rt <- round(rt[keep], 2)
rownames(df_dass) <- NULL
attr(df_dass, "cleaning") <- cleaning
# Not used as a rule: records from a network that sent more than one survey (the codebook
# warns that this does not imply a duplicate); the count is kept for the text
attr(df_dass, "shared_network") <- sum(raw$uniquenetworklocation == 2)

save(df_dass, file = "data/df_dass.rda", compress = "xz")
