"""Add structured data (JSON-LD) to every rendered tutorial in docs/<site>/, for search engines.

Each tutorial becomes a TechArticle: its title, description, card image, language, the site it belongs
to (articleSection), its author, and two dates from git: when its source was first committed
(datePublished, the date build_feed.py gives it too) and last committed (dateModified). The author is
the person of https://sedzinfo.github.io/, with the same @id as there. A page whose source names
another author (author: in its front matter) is left without one rather than credited to the wrong
person. The home pages of the sites are left out: they list tutorials and are not tutorials themselves.

The block goes at the end of <head>, as <script type="application/ld+json" id="structured-data">. A
page that has one already gets it replaced, so the script can run any number of times, and a page is
written only when its block changes.
Run by the GitHub workflow after rendering, and by render.R. Set DOCS_DIR to write somewhere else
(render.R uses _preview/). Test a page at https://search.google.com/test/rich-results
"""
import html
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUARTO = ROOT / "quarto"
DOCS = Path(os.environ.get("DOCS_DIR", ROOT / "docs"))
BASE = "https://sedzinfo.github.io/vignettes/"
PERSON = {
    "@type": "Person",
    "@id": "https://sedzinfo.github.io/#person",
    "name": "Dimitrios Zacharatos",
    "url": "https://sedzinfo.github.io/",
    "sameAs": ["https://github.com/sedzinfo", "https://orcid.org/0000-0003-1789-8294"],
}
WEBSITE = {"@type": "WebSite", "@id": "https://sedzinfo.github.io/#website", "name": "sedzinfo",
           "url": "https://sedzinfo.github.io/"}
BLOCK = re.compile(r'\s*<script type="application/ld\+json" id="structured-data">.*?</script>', re.S)


def website_title(project):
    match = re.search(r'^  title:\s*"?(.*?)"?\s*$', (project / "_quarto.yml").read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else project.name


def git_date(source, first):
    """When the source was first (or last) committed; the file's date when it is not committed yet."""
    args = ["--diff-filter=A"] if first else ["-1"]
    dates = subprocess.run(["git", "log", "--follow", *args, "--format=%aI", "--", str(source)],
                           cwd=ROOT, capture_output=True, text=True).stdout.split()
    if dates:
        return dates[-1] if first else dates[0]
    return datetime.fromtimestamp(source.stat().st_mtime, timezone.utc).isoformat(timespec="seconds")


def text_of(fragment):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", "", fragment)).split())


def meta(page, attribute, name):
    match = re.search(rf'<meta {attribute}="{re.escape(name)}" content="([^"]*)"', page)
    return html.unescape(match.group(1)).strip() if match else ""


def article(page, url, section, source):
    headline = text_of((re.search(r'<h1 class="title">(.*?)</h1>', page, re.S) or [None, source.stem])[1])
    language = (re.search(r'<html[^>]*\blang="([^"]+)"', page) or [None, "en"])[1]
    if re.search("[Ͱ-Ͽ]", headline):          # a Greek title: the page is in Greek, whatever <html lang> says
        language = "el"
    data = {
        "@context": "https://schema.org",
        "@type": "TechArticle",
        "headline": headline,
        "description": meta(page, "name", "description"),
        "url": url,
        "mainEntityOfPage": url,
        "image": meta(page, "property", "og:image"),
        "inLanguage": language,
        "datePublished": git_date(source, first=True),
        "dateModified": git_date(source, first=False),
        "articleSection": section,
        "keywords": meta(page, "name", "keywords"),
        "author": None if meta(page, "name", "author") else PERSON,
        "isPartOf": WEBSITE,
    }
    return {key: value for key, value in data.items() if value}


changed = total = 0
for config in sorted(QUARTO.glob("*/_quarto.yml")):
    project = config.parent
    section = website_title(project)
    for source in sorted(p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd") and p.stem != "index"):
        rendered = DOCS / project.name / f"{source.stem}.html"
        if not rendered.exists():
            continue
        page = rendered.read_text(encoding="utf-8")
        if "</head>" not in page:
            print(f"::warning::{rendered}: no </head>; left without structured data")
            continue
        data = article(page, f"{BASE}{project.name}/{rendered.name}", section, source)
        script = ('<script type="application/ld+json" id="structured-data">'
                  + json.dumps(data, ensure_ascii=False, indent=1).replace("</", "<\\/") + "</script>")
        new = BLOCK.sub("", page).replace("</head>", f"{script}\n</head>", 1)
        total += 1
        if new != page:
            rendered.write_text(new, encoding="utf-8", newline="\n")
            changed += 1
print(f"{DOCS}: structured data in {total} tutorials, {changed} pages written")
