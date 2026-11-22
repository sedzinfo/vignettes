##########################################################################################
# PREPARE df_careless.rda: THE DASS DATA BEFORE ANY CLEANING, FOR THE CARELESS-RESPONDING GUIDE
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (DASS_data_21.02.19.zip, 39,775 records of
# the 42-item Depression Anxiety Stress Scales collected online in 2017-2019; see codebook.txt
# inside the zip), the same file as data/prepare_dass.R. That script removes careless records;
# this one keeps them, because finding them is the subject of VALIDATION_CARELESS_RESPONDING.
# The only rule applied here is that all 42 items were answered.
#
# Each person saw the 42 items one at a time, in a random order of their own: Q1I ... Q42I give
# the position at which each item was shown and Q1E ... Q42E the time taken to answer it (ms).
# The vocabulary checklist VCL1 ... VCL16 asked which words the person knew; VCL6, VCL9 and
# VCL12 ("cuivocal", "florted", "verdid") do not exist.
#
# From quarto/validation/:
#   Rscript data/prepare_careless.R                   # downloads the zip
#   Rscript data/prepare_careless.R path/to/data.csv  # uses a copy you already have
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

answers   <- paste0("Q", 1:42, "A")
positions <- paste0("Q", 1:42, "I")
times     <- paste0("Q", 1:42, "E")
x   <- as.matrix(raw[, answers])
pos <- as.matrix(raw[, positions])
complete <- rowSums(is.na(x) | x < 1 | x > 4) == 0 &
  apply(pos, 1, function(p) identical(sort(as.integer(p)), 1:42))   # every position shown once
d   <- raw[complete, ]
x   <- x[complete, ]
pos <- pos[complete, ]
ms  <- as.matrix(d[, times])
##########################################################################################
# SAVE
##########################################################################################
# Q1 ... Q42: the answers (1-4, as recorded), in item order
df_careless <- as.data.frame(x)
names(df_careless) <- paste0("Q", 1:42)
df_careless[] <- lapply(df_careless, as.integer)
# O1 ... O42: the item shown at position 1, 2, ..., 42 (the presentation order of each person)
order_shown <- t(apply(pos, 1, order))
colnames(order_shown) <- paste0("O", 1:42)
df_careless <- cbind(df_careless, as.data.frame(order_shown))
# response times: the median and the shortest item times (s), and the number of items answered
# in less than 1 s and in less than 2 s
df_careless$median_rt  <- round(apply(ms, 1, median) / 1000, 2)
df_careless$items_lt1s <- as.integer(rowSums(ms < 1000))
df_careless$items_lt2s <- as.integer(rowSums(ms < 2000))
# vocabulary checklist: words claimed out of the 13 real ones, and of the 3 that do not exist
df_careless$real_words <- as.integer(rowSums(d[, paste0("VCL", setdiff(1:16, c(6, 9, 12)))]))
df_careless$fake_words <- as.integer(d$VCL6 + d$VCL9 + d$VCL12)
# TIPI (0 = skipped) and two demographics
tipi <- paste0("TIPI", 1:10)
df_careless[tipi] <- lapply(d[tipi], function(v) as.integer(replace(v, v == 0, NA)))
df_careless$gender <- factor(d$gender, levels = 1:3, labels = c("Male", "Female", "Other"))
df_careless$age    <- as.integer(ifelse(d$age >= 13 & d$age <= 80, d$age, NA))   # implausible ages to NA
rownames(df_careless) <- NULL
attr(df_careless, "records") <- c(raw = nrow(raw), complete = nrow(df_careless))

save(df_careless, file = "data/df_careless.rda", compress = "xz")
cat("records:", nrow(raw), "complete:", nrow(df_careless), "\n")
cat("size:", round(file.size("data/df_careless.rda") / 1e6, 2), "MB\n")
