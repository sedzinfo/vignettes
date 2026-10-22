##########################################################################################
# PREPARE df_viqt.rda FROM THE OPEN-SOURCE PSYCHOMETRICS PROJECT VOCABULARY IQ TEST DATA
##########################################################################################
# Source: https://openpsychometrics.org/_rawdata/ (VIQT_data.zip, 12,173 records collected
# online July 2017 - March 2018 with the "Vocabulary IQ Test"; see codebook.txt inside the zip).
# Each of the 45 items lists five words and asks for the two with the same meaning. An answer
# is stored as the sum of 2^(position - 1) over the selected words (first word = 1, second = 2,
# third = 4, fourth = 8, fifth = 16), so 3 means words 1 and 2 and 24 means words 4 and 5;
# -1 = "don't know" and 0 = no response. The answer key below is copied from codebook.txt and
# is checked against the score_right column that the test site computed for every record.
# The vignette loads the result (data/df_viqt.rda); this script only has to run again to
# change the cleaning rules.
#
# From quarto/validation/:
#   Rscript data/prepare_viqt.R                        # downloads the zip
#   Rscript data/prepare_viqt.R path/to/VIQT_data.csv  # uses a copy you already have
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  csv <- args[1]
} else {
  zip <- tempfile(fileext = ".zip")
  options(timeout = 900)
  download.file("https://openpsychometrics.org/_rawdata/VIQT_data.zip", zip, mode = "wb")
  unzip(zip, exdir = tempdir())
  csv <- file.path(tempdir(), "VIQT_data", "VIQT_data.csv")
}
raw <- read.delim(csv, stringsAsFactors = FALSE)
##########################################################################################
# ITEMS AND ANSWER KEY (codebook.txt)
##########################################################################################
key <- data.frame(item = paste0("Q", 1:45), stringsAsFactors = FALSE, code = c(
  24,  3, 10,  5,  9,  9, 17, 10, 17, 10,  5, 17,  9,  5, 18, 18,  3, 12, 18, 18,  3, 18,  6,
  12, 17, 10, 10,  9,  9,  3,  6, 10, 17,  3, 17, 24, 17,  5,  5, 24,  5,  5, 12, 10,  9),
  words = c(
  "tiny faded new large big",                                 # Q1
  "shovel spade needle oak club",
  "walk rob juggle steal discover",
  "finish embellish cap squeak talk",
  "recall flex efface remember divest",                       # Q5
  "implore fancy recant beg answer",
  "deal claim plea recoup sale",
  "mindful negligent neurotic lax delectable",
  "quash evade enumerate assist defeat",
  "entrapment partner fool companion mirror",                 # Q10
  "junk squeeze trash punch crack",
  "trivial crude presidential flow minor",
  "prattle siren couch chatter good",
  "above slow over pierce what",
  "assail designate arcane capitulate specify",               # Q15
  "succeed drop squeal spit fall",
  "fly soar drink peer hop",
  "disburse perplex muster convene feign",
  "cistern crimp bastion leeway pleat",
  "solder beguile distant reveal seduce",                     # Q20
  "dowager matron spank fiend sire",
  "worldly solo inverted drunk alone",
  "protracted standard normal florid unbalanced",
  "admissible barbaric lackluster drab spiffy",
  "related intrinsic alien steadfast pertinent",              # Q25
  "facile annoying clicker obnoxious counter",
  "capricious incipient galling nascent chromatic",
  "noted subsidiary culinary illustrious begrudge",
  "breach harmony vehement rupture acquiesce",
  "influence power cauterize bizarre regular",                # Q30
  "silence rage anger victory love",
  "sector mean light harsh predator",
  "house carnival yeast economy domicile",
  "depression despondency forswear hysteria integrity",
  "memorandum catalogue bourgeois trigger note",              # Q35
  "fulminant doohickey ligature epistle letter",
  "titanic equestrian niggardly promiscuous gargantuan",
  "stanchion strumpet pole pale forstall",
  "yearn reject hanker despair indolence",
  "introduce terminate shatter bifurcate fork",               # Q40
  "omen opulence harbinger mystic demand",
  "hightail report abscond perturb surmise",
  "fugacious vapid fractious querulous extemporaneous",
  "cardinal pilot full trial inkling",
  "fixed rotund stagnant permanent shifty"))                  # Q45
# decode each key into its two words: bit k (value 2^(k-1)) set = word k selected
key$answer <- mapply(function(code, words) {
  w <- strsplit(words, " ")[[1]]
  paste(w[bitwAnd(code, 2^(0:4)) > 0], collapse = " = ")
}, key$code, key$words)

x <- as.matrix(raw[, key$item])
correct <- sweep(x, 2, key$code, "==") * 1L
stopifnot(all(rowSums(correct) == raw$score_right))         # the key reproduces the site's scores
##########################################################################################
# CLEANING: each rule is counted on its own and then all are applied together
##########################################################################################
one_or_three <- matrix(x %in% c(1, 2, 4, 8, 16, 28), nrow(x))  # one or three words, not two
demog <- c("age", "gender", "country", "education", "engnat")
rules <- data.frame(
  few_blanks    = rowSums(x == 0) <= 4,                      # 0 = no response at all
  two_words     = rowSums(one_or_three) <= 4,                # chose two words as instructed
  not_too_fast  = raw$testelapse >= 2 * nrow(key),           # at least 2 seconds per item
  plausible_age = raw$age >= 13 & raw$age <= 90,
  not_repeat    = !duplicated(raw[, c(key$item, demog)])     # same 45 answers and demographics
)
keep <- Reduce(`&`, rules)
cleaning <- data.frame(rule = c(names(rules), "all rules"),
                       excluded = c(colSums(!rules), sum(!keep)),
                       remaining = c(colSums(rules), sum(keep)))
print(cleaning)
d <- raw[keep, ]
##########################################################################################
# SAVE: raw answer codes (scored in the vignette with the key) and demographics
##########################################################################################
df_viqt <- as.data.frame(x[keep, ])
df_viqt[] <- lapply(df_viqt, as.integer)
df_viqt$age       <- d$age
df_viqt$gender    <- factor(d$gender, levels = 1:3, labels = c("Male", "Female", "Other"))
df_viqt$engnat    <- factor(d$engnat, levels = 1:2, labels = c("Yes", "No"))
df_viqt$education <- factor(d$education, levels = 1:4,
                            labels = c("Less than high school", "High school", "University degree", "Graduate degree"))
df_viqt$urban     <- factor(d$urban, levels = 1:3, labels = c("Rural", "Suburban", "Urban"))
df_viqt$country   <- d$country
rownames(df_viqt) <- NULL
attr(df_viqt, "cleaning") <- cleaning
attr(df_viqt, "key")      <- key

save(df_viqt, file = "data/df_viqt.rda", compress = "xz")
