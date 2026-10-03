"""Build docs/index.html: a landing page linking every rendered site in docs/<name>/.

Title and description come from the `website:` block of quarto/<name>/_quarto.yml.
Styled with the same Bootswatch theme (flatly) the Quarto sites use.
Set DOCS_DIR to write somewhere else (render.R uses _preview/ for local builds).
"""
import html
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUARTO = ROOT / "quarto"
DOCS = Path(os.environ.get("DOCS_DIR", ROOT / "docs"))
REPO_URL = "https://github.com/sedzinfo/vignettes"


def website_field(config: str, key: str) -> str:
    """Read a one-line `key:` value from the `website:` block of a _quarto.yml."""
    block = re.search(r"^website:\n((?:[ \t]+.*\n|\n)*)", config, re.M)
    if not block:
        return ""
    match = re.search(rf"^  {key}:\s*(.+)$", block.group(1), re.M)
    return match.group(1).strip().strip("\"'") if match else ""


def page_count(project: Path) -> int:
    pages = [p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd") and p.stem != "index"]
    return len(pages)


sites = []
for config_path in sorted(QUARTO.glob("*/_quarto.yml")):
    project = config_path.parent
    name = project.name
    if not (DOCS / name).is_dir():
        continue
    config = config_path.read_text(encoding="utf-8")
    sites.append({
        "name": name,
        "title": website_field(config, "title") or name,
        "description": website_field(config, "description"),
        "pages": page_count(project),
    })

nav_links = "\n".join(
    f'          <li class="nav-item"><a class="nav-link" href="{s["name"]}/">{html.escape(s["title"])}</a></li>'
    for s in sites
)

cards = "\n".join(
    f"""      <div class="col">
        <a class="card h-100 site-card" href="{s["name"]}/">
          <div class="card-body">
            <h2 class="card-title h5">{html.escape(s["title"])}</h2>
            <p class="card-text">{html.escape(s["description"])}</p>
          </div>
          <div class="card-footer text-muted small">{s["pages"]} {"tutorial" if s["pages"] == 1 else "tutorials"}</div>
        </a>
      </div>"""
    for s in sites
)

page = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vignettes</title>
  <meta name="description" content="Tutorials and worked examples in R.">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootswatch@5.3.3/dist/flatly/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <style>
    body {{ display: flex; flex-direction: column; min-height: 100vh; }}
    main {{ flex: 1; }}
    .site-card {{ color: inherit; text-decoration: none; border-left: 5px solid #007ACC; transition: box-shadow .15s, transform .15s; }}
    .site-card:hover {{ box-shadow: 0 .5rem 1rem rgba(0,0,0,.12); transform: translateY(-2px); }}
    .site-card .card-title {{ color: var(--bs-primary); }}
  </style>
</head>
<body>
  <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
    <div class="container">
      <a class="navbar-brand" href="./">Vignettes</a>
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#nav" aria-controls="nav" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="collapse navbar-collapse" id="nav">
        <ul class="navbar-nav me-auto">
{nav_links}
        </ul>
        <ul class="navbar-nav">
          <li class="nav-item"><a class="nav-link" href="{REPO_URL}" aria-label="GitHub"><i class="bi bi-github"></i></a></li>
        </ul>
      </div>
    </div>
  </nav>

  <main class="container py-5">
    <h1 class="mb-2">Vignettes</h1>
    <p class="lead text-muted mb-4">Tutorials and worked examples in R.</p>
    <div class="row row-cols-1 row-cols-md-2 g-4">
{cards}
    </div>
  </main>

  <footer class="border-top py-3 text-center text-muted small">
    <a class="text-muted" href="{REPO_URL}">{REPO_URL.removeprefix("https://")}</a>
  </footer>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"""

DOCS.mkdir(exist_ok=True)
(DOCS / ".nojekyll").touch()
(DOCS / "index.html").write_text(page, encoding="utf-8")
print(f"{DOCS / 'index.html'}: {len(sites)} sites")
