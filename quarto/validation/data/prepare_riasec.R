##########################################################################################
# PREPARE df_riasec.rda FROM THE OPEN-SOURCE PSYCHOMETRICS PROJECT RIASEC DATA
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (RIASEC_data12Dec2018.zip, 145,828 records
# collected 2015-2018 with an online Holland Code test; see codebook.txt inside the zip).
# The vignette loads the result (data/df_riasec.rda); this script only has to run again to
# change the cleaning rules.
#
# From quarto/validation/:
#   Rscript data/prepare_riasec.R                   # downloads the zip
#   Rscript data/prepare_riasec.R path/to/data.csv  # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  csv <- args[1]
} else {
  zip <- tempfile(fileext = ".zip")
  options(timeout = 600)
  download.file("https://openpsychometrics.org/_rawdata/RIASEC_data12Dec2018.zip", zip, mode = "wb")
  unzip(zip, exdir = tempdir())
  csv <- file.path(tempdir(), "RIASEC_data12Dec2018", "data.csv")
}
raw <- read.delim(csv, stringsAsFactors = FALSE, quote = "", encoding = "UTF-8")

items <- paste0(rep(c("R", "I", "A", "S", "E", "C"), each = 8), 1:8)
tipi  <- paste0("TIPI", 1:10)
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
x <- as.matrix(raw[, items])
rules <- data.frame(
  complete      = rowSums(x < 1 | x > 5) == 0,                  # 0 = item skipped
  no_fake_words = raw$VCL6 == 0 & raw$VCL9 == 0 & raw$VCL12 == 0, # "cuivocal", "florted", "verdid"
  not_too_fast  = raw$testelapse >= 2 * length(items),           # at least 2 seconds per item
  not_flat      = apply(x, 1, function(r) length(unique(r)) > 1),# not the same answer to all 48
  plausible_age = raw$age >= 13 & raw$age <= 80,
  first_record  = raw$uniqueNetworkLocation == 1                 # drops retakes and shared networks
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
d <- raw[keep, ]
##########################################################################################
# UNIVERSITY MAJOR: free text grouped into broad fields (first matching pattern wins)
##########################################################################################
major_patterns <- c(
  "Nursing"                  = "nurs",
  "Psychology"               = "psych",
  "Social work / counseling" = "social work|counsel",
  "Education"                = "educat|teach",
  "Accounting / finance"     = "account|financ|banking|actuar",
  "Economics"                = "econ",
  "Business / management"    = "business|manag|marketing|commerce|entrepreneur|\\bmba\\b|hospitality",
  "Law / criminal justice"   = "\\blaw\\b|legal|crimin",
  "Engineering"              = "engineer",
  "Computer science / IT"    = "computer|software|information tech|\\bit\\b|programming",
  "Mathematics / physical sciences" = "math|physics|chemistry|statistic",
  "Biology / life sciences"  = "biolog|zoolog|ecolog|marine|biochem|microbio|neurosci|life science",
  "Medicine / pharmacy"      = "medicine|medical|pre-?med|mbbs|pharm",
  "Arts / design / music"    = "\\bart\\b|fine arts|design|music|theat|drama|film|animation|graphic|photograph|danc",
  "English / writing"        = "english|literature|writing|journalism",
  "History / philosophy / politics" = "history|philosoph|politic"
)
major <- tolower(trimws(d$major))
major_group <- rep(NA_character_, nrow(d))
for (g in names(major_patterns)) {
  hit <- is.na(major_group) & grepl(major_patterns[[g]], major, perl = TRUE)
  major_group[hit] <- g
}
##########################################################################################
# SAVE: items, TIPI and a few demographics; the free-text major itself is not kept
##########################################################################################
df_riasec <- d[, c(items, tipi)]
df_riasec[tipi] <- lapply(df_riasec[tipi], function(v) replace(v, v == 0, NA))  # 0 = skipped
df_riasec$gender      <- factor(d$gender, levels = 1:3, labels = c("Male", "Female", "Other"))
df_riasec$age         <- d$age
df_riasec$education   <- factor(d$education, levels = 1:4,
                                labels = c("Less than high school", "High school", "University degree", "Graduate degree"))
df_riasec$engnat      <- factor(d$engnat, levels = 1:2, labels = c("Yes", "No"))
df_riasec$major_group <- factor(major_group, levels = names(major_patterns))
rownames(df_riasec) <- NULL
attr(df_riasec, "cleaning") <- cleaning

save(df_riasec, file = "data/df_riasec.rda", compress = "xz")
print(table(df_riasec$major_group, useNA = "ifany"))
