"""Keep a page from running its R code again when only its title or description changed.

Quarto runs the R code of a page again when the page no longer matches the fingerprint saved in
quarto/<site>/_freeze/<page>/execute-results/html.json (the MD5 of its source, with Unix line endings),
even when the change is a new description, which cannot change what the code computes. _freeze/ also
keeps the knitted page, front matter first. So this script puts that saved front matter back in place
of the page's own: if the result matches the fingerprint, the front matter is all that changed. When
every changed line sets one of KEYS, _freeze/ gets the new front matter and fingerprint, and Quarto
renders the page from _freeze/ as before. Any other change (code, text, params, execute options...)
is left alone, so the page runs again. A line with inline R code, such as date: "`r Sys.Date()`", is
saved in _freeze/ with its value; the date stays the day the code last ran.

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
INLINE_R = re.compile(r"`r[ \t]")


def md5(text):
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def key(line):
    match = re.match(r"([A-Za-z0-9_.-]+):", line)
    return match.group(1) if match else None


def reconcile(frozen, source):
    """From the front matter in _freeze/ and the page's own (lists of lines), rebuild the page's front
    matter as it was when its code ran, and the front matter to save in _freeze/ now, with the keys
    that changed. None if a line other than KEYS changed, except a line with inline R code whose value
    is in _freeze/."""
    old, new, keys = [], [], set()
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, frozen, source, autojunk=False).get_opcodes():
        f, s = frozen[i1:i2], source[j1:j2]
        if tag == "equal":
            old += s
            new += f
            continue
        f_other = [line for line in f if key(line) not in KEYS]
        s_other = [line for line in s if key(line) not in KEYS]
        if len(f_other) != len(s_other) or any(key(a) != key(b) or not INLINE_R.search(b) for a, b in zip(f_other, s_other)):
            return None
        keys |= {key(line) for line in f + s if key(line) in KEYS}
        s_iter, f_iter = iter(s_other), iter(f_other)
        old += [line if key(line) in KEYS else next(s_iter) for line in f]    # old values of KEYS, inline R as written
        new += [line if key(line) in KEYS else next(f_iter) for line in s]    # new values of KEYS, inline R as computed
    return old, new, keys


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
        source = FRONT_MATTER.match(text)
        frozen = FRONT_MATTER.match(freeze["result"]["markdown"])
        if not source or not frozen:
            continue
        result = reconcile(frozen.group(0).splitlines(), source.group(0).splitlines())
        if result is None or md5("\n".join(result[0]) + "\n" + text[source.end():]) != freeze["hash"]:
            continue                                   # more than KEYS changed: the page runs again
        freeze["hash"] = md5(text)
        freeze["result"]["markdown"] = "\n".join(result[1]) + "\n" + freeze["result"]["markdown"][frozen.end():]
        out = json.dumps(freeze, indent=2, ensure_ascii=False)       # as Quarto writes it
        if "\r\n" in raw:                                             # keep the file's line endings
            out = out.replace("\n", "\r\n")
        freeze_file.write_bytes(out.encode("utf-8"))
        print(f"{page.as_posix()}: only {', '.join(sorted(result[2]))} changed; "
              "_freeze/ updated, so its R code does not run again")
        updated += 1
print(f"Front matter only: {updated} page(s) updated in _freeze/")
