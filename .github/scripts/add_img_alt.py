"""Give every plot in the rendered tutorials in docs/<site>/ an alt text, for screen readers and search engines.

knitr writes a plot as <img> with no alt attribute unless its chunk sets fig-cap or fig-alt, so most
plots of the tutorials have none. Each such image gets one made from what the page already says about
it: the chunk label (the file name knitr gives the plot, <page>_files/figure-html/<label>-<n>.png) and the
heading of the section the plot is in, e.g. "Density plot – Examples". A label that says nothing on its
own (plot, gif1, m3, unnamed-chunk-2...) gives way to the heading: "Plot: Network training". An image
that has an alt attribute, even an empty one, is left as it is: it was set on purpose.

To give a plot a better description, set fig-alt in its chunk (#| fig-alt: "...") and render the page.
The script only fills in what is missing, so it can run any number of times, and a page is written only
when it changes. Run by the GitHub workflow after rendering, before build_feed.py so that the feed gets
the alt texts too, and by render.R. Set DOCS_DIR to write somewhere else (render.R uses _preview/).
"""
import html
import os
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUARTO = ROOT / "quarto"
DOCS = Path(os.environ.get("DOCS_DIR", ROOT / "docs"))

IMG = re.compile(r"<img\b[^>]*>", re.I)
HEADING = re.compile(r"<h([1-6])\b[^>]*>(.*?)</h\1>", re.S | re.I)
# labels that say nothing about the plot by themselves
VAGUE = re.compile(r"(unnamed-chunk-\d+|plot\d*|gif\d*|m\d+|look|static|animate|theme|labels|lines|results\d*|"
                   r"step\d+_plot|chart\d*|figure\d*|fig\d*|image\d*|img\d*)", re.I)
# abbreviations in chunk labels, written in capitals
ABBREVIATIONS = {"asb", "cat", "cfa", "cv", "dif", "eap", "eda", "efa", "emm", "grm", "hsv", "icc", "iq",
                 "irt", "lda", "mh", "mirt", "mds", "mst", "nb", "nrm", "pcm", "q3", "rgb", "rmse", "roc",
                 "rsm", "se", "tipi"}
# words of chunk labels written out (run-together words, short forms, misspellings); "" drops the word
WORDS = {"agecurves": "age curves", "agemeans": "age means", "biloadings": "bifactor loadings",
         "corrmatrix": "correlation matrix", "decomp": "decomposition", "desc": "descriptives",
         "engnat": "native language", "evenodd": "even-odd", "facetcor": "facet correlations",
         "facetmap": "facet map", "gif": "", "hist": "histogram", "ii": "item information",
         "iteminfo": "item information", "keycheck": "key check", "methodloadings": "method loadings",
         "nfactors": "number of factors", "pi": "category probability",
         "responsefrequencies": "response frequencies", "sexdiff": "sex differences",
         "sexfacets": "sex differences in facets", "spesification": "specification",
         "subscalecor": "subscale correlations", "testinfo": "test information", "timeseries": "time series",
         "wright": "Wright map"}
# words that say what kind of picture it is, not what it shows
GENERIC = {"plot", "chart", "figure", "graph", "animated", "animation"}
# TeX in headings, as alt text cannot show it
GREEK = {"alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "theta": "θ", "lambda": "λ",
         "mu": "μ", "pi": "π", "rho": "ρ", "sigma": "σ", "tau": "τ", "chi": "χ", "omega": "ω"}


def plain(text):
    """Text with TeX maths written plainly: \\(\\lambda\\) becomes λ."""
    text = re.sub(r"\\[()\[\]]", "", text)
    return re.sub(r"\\([A-Za-z]+)", lambda m: GREEK.get(m.group(1), m.group(1)), text)


def text_of(fragment):
    """The text of an HTML fragment, without tags, the numbers Quarto puts before headings, or anchors."""
    fragment = re.sub(r'<span class="header-section-number">.*?</span>', "", fragment, flags=re.S)
    return plain(" ".join(html.unescape(re.sub(r"<[^>]+>", "", fragment)).split()))


def fold(text):
    """Lower case without accents, to compare a label with a heading (cafe wall, Café Wall)."""
    return unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()


def label_phrase(src):
    """'Density plot' from .../figure-html/density_plot-1.png; None when the label is vague."""
    name = src.rsplit("/", 1)[-1].split("?")[0]
    stem = re.sub(r"\.(png|gif|jpe?g|svg|webp)$", "", name, flags=re.I)
    if "/figure-html/" in src:
        stem = re.sub(r"-\d+$", "", stem)                      # knitr's number of the plot in its chunk
    if not stem or VAGUE.fullmatch(stem):
        return None
    words = []
    for word in re.split(r"[-_\s]+", stem):
        letters = re.fullmatch(r"([a-z]+)\d+", word.lower())
        if letters and letters.group(1) in ABBREVIATIONS:     # efa5: the fifth EFA plot of the page
            word = letters.group(1)
        word = WORDS.get(word.lower(), word)
        if word:
            words.append(word.upper() if word.lower() in ABBREVIATIONS else word)
    if not words:
        return None
    phrase = " ".join(words)
    return phrase[0].upper() + phrase[1:]


def says_nothing_more(phrase, context):
    """True when every word of the label is in the heading already (Berkson, Berkson's Paradox)."""
    words = [w for w in re.findall(r"[a-z]+", fold(phrase)) if w not in GENERIC]
    return all(w in fold(context) for w in words)


def alt_text(src, heading, title):
    phrase = label_phrase(src)
    context = heading or title
    animation = re.search(r"\.gif(\?|$)", src, re.I)
    if not context:
        return phrase or ("Animation" if animation else "Plot")
    if phrase is None or says_nothing_more(phrase, context):
        if animation:
            return f"Animation: {context}"
        if phrase is None and not fold(context).startswith("plot"):
            return f"Plot: {context}"                      # the heading may be about more than the plot
        return context
    if fold(context) != fold(phrase):
        return f"{phrase} – {context}"
    return phrase


def add_alts(page):
    """The page with an alt attribute on every <img> of its <main> that has none; how many were added."""
    main = re.search(r"<main\b.*?</main>", page, re.S)
    if not main:
        return page, 0
    title_match = re.search(r'<h1 class="title">(.*?)</h1>', page, re.S)
    title = text_of(title_match.group(1)) if title_match else ""
    headings = [(m.start(), text_of(m.group(2))) for m in HEADING.finditer(page, main.start(), main.end())
                if 'class="title"' not in m.group(0)]
    out, last, added = [], 0, 0
    for m in IMG.finditer(page, main.start(), main.end()):
        tag = m.group(0)
        if re.search(r"\salt\s*=", tag, re.I):
            continue
        src = re.search(r'\ssrc="([^"]*)"', tag)
        if not src:
            continue
        heading = next((text for pos, text in reversed(headings) if pos < m.start()), "")
        alt = html.escape(alt_text(src.group(1), heading, title), quote=True)
        out += [page[last:m.start()], tag[:4] + f' alt="{alt}"' + tag[4:]]
        last = m.end()
        added += 1
    out.append(page[last:])
    return "".join(out), added


sites = sorted(p.parent.name for p in QUARTO.glob("*/_quarto.yml"))
changed = 0
for site in sites:
    for path in sorted((DOCS / site).glob("*.html")):
        raw = path.read_bytes().decode("utf-8")
        new, added = add_alts(raw)
        if added:
            path.write_bytes(new.encode("utf-8"))
            changed += 1
            print(f"{path.relative_to(DOCS).as_posix()}: alt text for {added} image(s)")
print(f"Alt text: {changed} page(s) updated")
