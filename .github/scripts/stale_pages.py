"""Which pages of the sites being rendered must run their R code on the runner.

Quarto keeps, in quarto/<site>/_freeze/<page>/execute-results/html.json, the MD5 of the source of the
page (with Unix line endings) from the last time its code ran. A page with R code runs again when that
file is missing or the source has changed since; every other page is rendered from _freeze.

Reads the sites from the SITES environment variable (separated by spaces) and writes needs_r=true or
needs_r=false to GITHUB_OUTPUT (or prints it, run locally).
"""
import hashlib
import json
import os
from pathlib import Path

stale = []
for site in os.environ.get("SITES", "").split():
    project = Path("quarto", site)
    for page in sorted(p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd")):
        text = page.read_bytes()
        if b"```{r" not in text and b"`r " not in text:
            continue
        freeze = project / "_freeze" / page.stem / "execute-results" / "html.json"
        digest = hashlib.md5(text.replace(b"\r\n", b"\n")).hexdigest()
        if not freeze.exists() or json.loads(freeze.read_text(encoding="utf-8")).get("hash") != digest:
            stale.append(page.as_posix())

print("Pages that will run their R code:", ", ".join(stale) if stale else "none")
line = f"needs_r={'true' if stale else 'false'}\n"
if os.environ.get("GITHUB_OUTPUT"):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
        out.write(line)
else:
    print(line, end="")
