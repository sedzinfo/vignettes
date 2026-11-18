"""Keep a page from running its R code again when only its title or description changed.

Quarto runs the R code of a page again when the page no longer matches the fingerprint saved in
quarto/<site>/_freeze/<page>/execute-results/html.json (the MD5 of its source, with Unix line endings),
even when the change is a new description, which cannot change what the code computes. _freeze/ also
keeps the knitted page, front matter first. So this script puts that saved front matter back in place
of the page's own: if the result matches the fingerprint, the front matter is all that changed. When
every changed line sets one of KEYS, _freeze/ gets the new front matter and fingerprint, and Quarto
renders the page from _freeze/ as before. Any other change (code, text, params, execute options...)
is left alone, so the page runs again.

Run by render.R before it renders and by the GitHub workflow before it checks _freeze/. By hand, from
the repository root (SITES: sites separated by spaces; all of them when it is not set):
  python .github/scripts/refreeze_front_matter.py
"""
import difflib
import hashlib
import json
import os
import re
from pathlib import Path

KEYS = ("title", "subtitle", "description", "image", "keywords")
FRONT_MATTER = re.compile(r"---\n.*?\n---\n", re.S)


def md5(text):
    return hashlib.md5(text.encode("utf-8")).hexdigest()


sites = os.environ.get("SITES", "").split() or sorted(p.parent.name for p in Path("quarto").glob("*/_quarto.yml"))
updated = 0
for site in sites:
    project = Path("quarto", site)
    if not project.is_dir():
        continue
    for page in sorted(p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd")):
        freeze_file = project / "_freeze" / page.stem / "execute-results" / "html.json"
        if not freeze_file.exists():
            continue
        raw = freeze_file.read_bytes().decode("utf-8")
        freeze = json.loads(raw)
        text = page.read_bytes().decode("utf-8").replace("\r\n", "\n")
        if md5(text) == freeze["hash"]:
            continue                                   # matches: rendered from _freeze/ anyway
        new = FRONT_MATTER.match(text)
        old = FRONT_MATTER.match(freeze["result"]["markdown"])
        if not new or not old or md5(old.group(0) + text[new.end():]) != freeze["hash"]:
            continue                                   # more than the front matter changed: runs again
        changed = [line[2:] for line in difflib.ndiff(old.group(0).splitlines(), new.group(0).splitlines())
                   if line[:1] in "+-"]
        if not all(re.match(rf"(?:{'|'.join(KEYS)}):", line) for line in changed):
            print(f"{page.as_posix()}: front matter changed beyond {', '.join(KEYS)}; its R code runs again")
            continue
        freeze["hash"] = md5(text)
        freeze["result"]["markdown"] = new.group(0) + freeze["result"]["markdown"][old.end():]
        out = json.dumps(freeze, indent=2, ensure_ascii=False)       # as Quarto writes it
        if "\r\n" in raw:                                             # keep the file's line endings
            out = out.replace("\n", "\r\n")
        freeze_file.write_bytes(out.encode("utf-8"))
        print(f"{page.as_posix()}: only {', '.join(sorted({l.split(':')[0] for l in changed}))} changed; "
              "_freeze/ updated, so its R code does not run again")
        updated += 1
print(f"Front matter only: {updated} page(s) updated in _freeze/")
