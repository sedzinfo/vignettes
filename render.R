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
#   Rscript render.R illustration --publish   # also copy the site into docs/, as the workflow does
#   add --no-browser to skip opening the result
# In RStudio: open this file, set the options below if you want, and click Source.
#
# A page runs its R code again only when the page itself has changed. After a change to a file
# that pages use, such as R/code_options.R, R/code_rwf.R, _quarto.yml or quarto/_shared/, delete
# quarto/<site>/_freeze/<page>/ of each page that should change, then render the site.
#
# --publish is for when the GitHub workflow cannot render (GitHub Pages serves docs/ as it is):
# commit docs/ together with the pages and _freeze/, then push. The workflow, when it runs,
# renders the same pages from the same _freeze/ and replaces docs/ with its own copy.
##########################################################################################
sites <- character(0)        # empty = all sites; e.g. c("illustration")
preview <- FALSE             # TRUE = live preview of one site (quarto preview)
publish <- FALSE             # TRUE = also copy the rendered sites into docs/
open_browser <- TRUE
##########################################################################################
# ARGUMENTS
##########################################################################################
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  preview <- "--preview" %in% args
  publish <- "--publish" %in% args
  open_browser <- !"--no-browser" %in% args
  sites <- setdiff(args, c("--preview", "--publish", "--no-browser"))
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
docs_root <- file.path(root, "docs")
all_sites <- basename(list.dirs(file.path(root, "quarto"), recursive = FALSE))
all_sites <- all_sites[file.exists(file.path(root, "quarto", all_sites, "_quarto.yml"))]
if (!length(sites)) sites <- all_sites
unknown <- setdiff(sites, all_sites)
if (length(unknown)) stop("No Quarto project at quarto/", paste(unknown, collapse = ", quarto/"), ". Sites: ", paste(all_sites, collapse = ", "))
##########################################################################################
# QUARTO, R AND PYTHON
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
# Python builds the landing page and checks _freeze/; on Windows python3 is often the Microsoft
# Store placeholder, so try py/python first
python <- Sys.which(if (.Platform$OS.type == "windows") c("py", "python", "python3") else c("python3", "python"))
python <- python[nzchar(python)][1]
# run a script of .github/scripts/ from the repository root, with environment variables
run_python <- function(script, env = character(0), ...) {
  owd <- setwd(root)
  on.exit(setwd(owd))
  old <- setNames(Sys.getenv(names(env), unset = NA), names(env))
  do.call(Sys.setenv, as.list(env))
  on.exit({
    Sys.unsetenv(names(old)[is.na(old)])
    if (any(!is.na(old))) do.call(Sys.setenv, as.list(old[!is.na(old)]))
  }, add = TRUE)
  system2(python, shQuote(file.path(root, ".github", "scripts", script)), ...)
}
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
  # the pages of a site: the files Quarto renders
  site_pages <- function(site_dir) list.files(site_dir, pattern = "\\.(rmd|qmd)$", ignore.case = TRUE, full.names = TRUE)
  render_site <- function(site_dir) {
    owd <- setwd(site_dir)
    on.exit(setwd(owd))
    system2(quarto, c("render", "--output-dir", "_site"))
  }
  # copy a rendered site to <to>/<site>, replacing what was there
  copy_site <- function(site_dir, to) {
    dest <- file.path(to, basename(site_dir))
    unlink(dest, recursive = TRUE)
    dir.create(dest, recursive = TRUE)
    file.copy(list.files(file.path(site_dir, "_site"), full.names = TRUE, all.files = TRUE, no.. = TRUE), dest, recursive = TRUE)
  }

  failed <- character(0)
  for (site in sites) {
    cat("==== Rendering", site, "====\n")
    site_dir <- file.path(root, "quarto", site)
    started <- Sys.time()
    status <- render_site(site_dir)
    # A page saved while its site was rendering keeps the results of the version that Quarto read at
    # the start, under the fingerprint of the version saved, so it would never run again: its
    # _freeze/ is removed and the site rendered once more, which runs it
    pages <- site_pages(site_dir)
    changed <- pages[file.mtime(pages) > started]
    if (status == 0 && length(changed)) {
      cat("\nChanged while rendering:", paste(basename(changed), collapse = ", "), "- rendering again\n")
      unlink(file.path(site_dir, "_freeze", tools::file_path_sans_ext(basename(changed))), recursive = TRUE)
      status <- render_site(site_dir)
    }
    if (status != 0) {
      failed <- c(failed, site)
      next
    }
    copy_site(site_dir, out_root)
    if (publish) copy_site(site_dir, docs_root)
  }
  ##########################################################################################
  # LANDING PAGE
  ##########################################################################################
  if (!is.na(python)) {
    run_python("build_index.py", c(DOCS_DIR = out_root))
    if (publish) run_python("build_index.py", c(DOCS_DIR = docs_root))
  } else {
    message("Python not found: skipped the landing page (index.html) and the check of _freeze/.")
  }
  ##########################################################################################
  # CHECK OF _freeze/
  ##########################################################################################
  # The same check as the GitHub workflow, over every site: a page whose _freeze/ does not match
  # it would make GitHub run its R code, with every package of the site, instead of rendering it
  # from _freeze/
  if (!is.na(python)) {
    check <- run_python("stale_pages.py", c(SITES = paste(all_sites, collapse = " ")), stdout = TRUE)
    stale <- sub("^Pages that will run their R code: ", "", grep("^Pages that will run", check, value = TRUE))
    if (length(stale) && stale != "none") {
      message("\nThese pages changed since their code last ran: ", stale, "\n",
              "Render their sites before you push, or GitHub has to run them itself: ",
              "Rscript render.R ", paste(unique(sub("^quarto/([^/]+)/.*", "\\1", strsplit(stale, ", ")[[1]])), collapse = " "))
    } else {
      cat("\nEvery page with R code matches its _freeze/: GitHub can render all of them without running R code.\n")
    }
  }
  ##########################################################################################
  # RESULT
  ##########################################################################################
  if (length(failed)) stop("Rendering failed for: ", paste(failed, collapse = ", "), ". See the messages above.")
  cat("\nDone. Output in", out_root, if (publish) paste("and", docs_root), "\n")
  cat("Commit the changed pages together with quarto/<site>/_freeze/", if (publish) " and docs/", ", then push.\n", sep = "")
  index <- if (length(sites) == 1) file.path(out_root, sites, "index.html") else file.path(out_root, "index.html")
  if (open_browser && file.exists(index)) utils::browseURL(index)
}
