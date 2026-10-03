##########################################################################################
# RENDER QUARTO SITES LOCALLY
##########################################################################################
# Renders quarto/<site>/ the same way the GitHub workflow does, but into _preview/<site>/
# (ignored by git) instead of docs/, builds the landing page, and opens it in the browser.
# Rendering also updates quarto/<site>/_freeze/: commit it together with the changed pages,
# so GitHub can publish them without running the R code itself.
#
# From the repo root:
#   Rscript render.R                          # all sites
#   Rscript render.R illustration             # one site (or several, separated by spaces)
#   Rscript render.R illustration --preview   # live preview: re-renders as you save
#   add --no-browser to skip opening the result
# In RStudio: open this file, set the options below if you want, and click Source.
##########################################################################################
sites <- character(0)        # empty = all sites; e.g. c("illustration")
preview <- FALSE             # TRUE = live preview of one site (quarto preview)
open_browser <- TRUE
##########################################################################################
# ARGUMENTS
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  preview <- "--preview" %in% args
  open_browser <- !"--no-browser" %in% args
  sites <- setdiff(args, c("--preview", "--no-browser"))
}
##########################################################################################
# PATHS
##########################################################################################
root <- normalizePath(".")
if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  editor_path <- rstudioapi::getSourceEditorContext()$path
  if (nzchar(editor_path)) root <- dirname(editor_path)
}
if (!dir.exists(file.path(root, "quarto"))) stop("Run this from the repository root (the folder with quarto/ and docs/).")
out_root <- file.path(root, "_preview")
all_sites <- basename(list.dirs(file.path(root, "quarto"), recursive = FALSE))
all_sites <- all_sites[file.exists(file.path(root, "quarto", all_sites, "_quarto.yml"))]
if (!length(sites)) sites <- all_sites
unknown <- setdiff(sites, all_sites)
if (length(unknown)) stop("No Quarto project at quarto/", paste(unknown, collapse = ", quarto/"), ". Sites: ", paste(all_sites, collapse = ", "))
##########################################################################################
# QUARTO AND R
##########################################################################################
find_quarto <- function() {
  candidates <- c(
    Sys.getenv("QUARTO_PATH"),
    Sys.which("quarto"),
    if (nzchar(Sys.getenv("RSTUDIO_PANDOC"))) file.path(dirname(Sys.getenv("RSTUDIO_PANDOC")), c("quarto.exe", "quarto")),
    "C:/Program Files/Quarto/bin/quarto.exe",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs/Positron/resources/app/quarto/bin/quarto.exe"),
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
    "/usr/local/bin/quarto",
    "/opt/quarto/bin/quarto"
  )
  found <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(found)) stop("Quarto not found. Install it from https://quarto.org or set QUARTO_PATH.")
  normalizePath(found[1])
}
quarto <- find_quarto()
# make Quarto use the R that runs this script, not whichever R it finds first
Sys.setenv(QUARTO_R = R.home("bin"))
cat("Quarto:", quarto, "\nR:     ", R.home("bin"), "\n\n")
##########################################################################################
# LIVE PREVIEW
##########################################################################################
if (preview) {
  if (length(sites) != 1) stop("--preview works with one site, e.g. Rscript render.R illustration --preview")
  owd <- setwd(file.path(root, "quarto", sites))
  cat("Live preview of", sites, "(press Ctrl+C, or Esc in RStudio, to stop)\n")
  tryCatch(system2(quarto, "preview"), finally = setwd(owd))
} else {
  ##########################################################################################
  # RENDER
  ##########################################################################################
  failed <- character(0)
  for (site in sites) {
    cat("==== Rendering", site, "====\n")
    site_dir <- file.path(root, "quarto", site)
    owd <- setwd(site_dir)
    status <- tryCatch(system2(quarto, c("render", "--output-dir", "_site")), finally = setwd(owd))
    if (status != 0) {
      failed <- c(failed, site)
      next
    }
    dest <- file.path(out_root, site)
    unlink(dest, recursive = TRUE)
    dir.create(dest, recursive = TRUE)
    file.copy(list.files(file.path(site_dir, "_site"), full.names = TRUE, all.files = TRUE, no.. = TRUE), dest, recursive = TRUE)
  }
  ##########################################################################################
  # LANDING PAGE
  ##########################################################################################
  # on Windows python3 is often the Microsoft Store placeholder, so try py/python first
  python <- Sys.which(if (.Platform$OS.type == "windows") c("py", "python", "python3") else c("python3", "python"))
  python <- python[nzchar(python)][1]
  if (!is.na(python)) {
    Sys.setenv(DOCS_DIR = out_root)
    system2(python, shQuote(file.path(root, ".github", "scripts", "build_index.py")))
  } else {
    message("Python not found: skipped the landing page (_preview/index.html).")
  }
  ##########################################################################################
  # RESULT
  ##########################################################################################
  if (length(failed)) stop("Rendering failed for: ", paste(failed, collapse = ", "), ". See the messages above.")
  cat("\nDone. Output in", out_root, "\n")
  cat("Commit the changed pages together with quarto/<site>/_freeze/, then push.\n")
  index <- if (length(sites) == 1) file.path(out_root, sites, "index.html") else file.path(out_root, "index.html")
  if (open_browser && file.exists(index)) utils::browseURL(index)
}
