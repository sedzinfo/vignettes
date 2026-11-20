"""Add a "See also" section to the tutorials in docs/<site>/ that relate to an app or package of sedzinfo.

Links from the tutorials lead readers, and search engines, to the apps and packages. A tutorial in PAGES
gets links to the apps that share its subject (item response theory: golemirt; a Big Five scale:
golemcat; Eurostat or World Bank data: golemeurostat, golemworldbank), with a link to the live app where
there is one. Any tutorial that loads rwf and calls its functions also gets a link to rwf, naming those
functions: they are not base R, so a reader who copies the code needs the package. The functions are
found in the page's source, by the names that quarto/example/R/code_rwf.R (rwf's code) defines.
An app the page links to already is left out.

The section goes at the end of <main>, so it is in the RSS feed too (this runs before build_feed.py).
A page that has it already gets it replaced, so the script can run any number of times, and a page is
written only when its section changes. Run by the GitHub workflow after rendering, and by render.R.
Set DOCS_DIR to write somewhere else (render.R uses _preview/).
"""
import html
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUARTO = ROOT / "quarto"
DOCS = Path(os.environ.get("DOCS_DIR", ROOT / "docs"))
HOME = "https://sedzinfo.github.io/"

TARGETS = {   # name: (site, live app or None, what it is)
    "golemirt": (HOME + "golemirt/", "https://sedzinfo-golemirt.share.connect.posit.cloud/",
                 "an interactive app for item response theory: the response curves of the common models, how "
                 "abilities and item parameters are estimated, and an adaptive test that runs item by item"),
    "golemcat": (HOME + "golemcat/", "https://sedzinfo-golemcat.share.connect.posit.cloud/",
                 "the 50 statements of the IPIP Big-Five Factor Markers as an adaptive personality test, "
                 "each trait scored with the rating scale model"),
    "golemworldbank": (HOME + "golemworldbank/", "https://sedzinfo.shinyapps.io/golemworldbank/",
                       "an interactive explorer of the World Bank development indicators of every country"),
    "golemeurostat": (HOME + "golemeurostat/", "https://sedzinfo.shinyapps.io/golemeurostat/",
                      "a Shiny app for exploring the Eurostat indicators of the countries and regions of Europe"),
    "golemenviro": (HOME + "golemenviro/", "https://sedzinfo-golemenviro.share.connect.posit.cloud/",
                    "a live dashboard of the readings of Pimoroni Enviro sensors: temperature, humidity, "
                    "pressure and more"),
    "snp": (HOME + "snp/", None,
            "an R package that draws the normal curve with the z, T, percentile, sten, stanine and IQ scales "
            "under it"),
    "rwf": (HOME + "rwf/", None, None),
}
CAT = ("an interactive app for item response theory, whose adaptive test runs this estimation item by item "
       "under the {} and five other models")
IPIP = "the same 50 IPIP statements as an adaptive personality test, each trait scored with the rating scale model"
PAGES = {   # "<site>/<page>": [(target, note, or None for the target's own description)]
    "cat_irt_eap/eap_dichotomous": [("golemirt", CAT.format("1PL to 4PL models").replace(" and five other models", ""))],
    "cat_irt_eap/eap_grm": [("golemirt", CAT.format("graded response model"))],
    "cat_irt_eap/eap_ggrm": [("golemirt", CAT.format("modified graded response model"))],
    "cat_irt_eap/eap_nrm": [("golemirt", CAT.format("nominal response model"))],
    "cat_irt_eap/eap_pcm": [("golemirt", CAT.format("partial credit model"))],
    "cat_irt_eap/eap_rsm": [("golemirt", CAT.format("rating scale model")), ("golemcat", None)],
    "example/EXAMPLE_SIMULATION_catR": [("golemirt", None), ("golemcat", None)],
    "example/EXAMPLE_MSTR": [("golemirt", None)],
    "example/EXAMPLE_TIRT": [("golemirt", "an interactive app for item response theory, with the response "
                                          "functions of Thurstonian IRT")],
    "example/EXAMPLE_TIRT_SCORING_GR": [("golemirt", "διαδραστική εφαρμογή για τη θεωρία απόκρισης ερωτημάτων "
                                                     "(IRT), με τις συναρτήσεις απόκρισης του Thurstonian IRT")],
    "validation/VALIDATION_VIQT": [("golemirt", None), ("snp", None)],
    "validation/VALIDATION_OCEAN": [("golemcat", IPIP)],
    "validation/VALIDATION_DESCRIPTIVES_OCEAN": [("golemcat", IPIP)],
    "validation/VALIDATION_BFI44": [("golemcat", None)],
    "validation/VALIDATION_IPIPNEO120": [("golemcat", None)],
    "validation/VALIDATION_HEXACO": [("golemcat", None)],
    "illustration/ILLUSTRATION_GAPMINDER": [("golemworldbank", None)],
    "illustration/ILLUSTRATION_GREEK_DEBT": [("golemeurostat", None), ("golemworldbank", None)],
    "illustration/ILLUSTRATION_GREEK_INVESTMENT": [("golemeurostat", None), ("golemworldbank", None)],
    "illustration/ILLUSTRATION_GREEK_ECONOMY": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_GREEK_POPULATION": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_GREEK_TOURISM": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_GREEK_WAGES_PRICES": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_GREEK_WORKFORCE": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_EU_SALARY": [("golemeurostat", None)],
    "illustration/ILLUSTRATION_AIRPORT_WEATHER": [("golemenviro", None)],
}
WORDS = {False: ("See also", "open the app", "and", "the R package behind {} on this page"),
         True: ("Δείτε επίσης", "ανοίξτε την εφαρμογή", "και", "το πακέτο R των {} αυτής της σελίδας")}
BLOCK = re.compile(r"<!-- see-also: written by .*?<!-- /see-also -->\n\n?", re.S)   # and the line break added after it
RWF_CODE = QUARTO / "example" / "R" / "code_rwf.R"
RWF_FUNCTIONS = set(re.findall(r"^([A-Za-z][\w.]*)\s*<-\s*function", RWF_CODE.read_text(encoding="utf-8"), re.M)
                    ) if RWF_CODE.exists() else set()


def rwf_calls(source):
    """The rwf functions a page calls, if it loads rwf (its bundled code, or the package)."""
    if not re.search(r"code_rwf\.r|library\(rwf\)|rwf::", source, re.I):
        return []
    return sorted(name for name in RWF_FUNCTIONS if re.search(rf"(?<![\w.$]){re.escape(name)}\(", source))


def section(items, greek):
    heading, open_app, word_and, _ = WORDS[greek]
    lines = []
    for name, note in items:
        site, app, _ = TARGETS[name]
        line = f'<li><a href="{site}">{name}</a>: {note}'
        if app:
            line += f' (<a href="{app}">{open_app}</a>)'
        lines.append(line + "</li>")
    return ("<!-- see-also: written by .github/scripts/add_see_also.py -->\n"
            '<section id="see-also" class="level2">\n'
            f'<h2 class="anchored" data-anchor-id="see-also">{heading}</h2>\n'
            "<ul>\n" + "\n".join(lines) + "\n</ul>\n</section>\n<!-- /see-also -->\n")


written = total = 0
for config in sorted(QUARTO.glob("*/_quarto.yml")):
    project = config.parent
    for source in sorted(p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd") and p.stem != "index"):
        rendered = DOCS / project.name / f"{source.stem}.html"
        if not rendered.exists():
            continue
        page = rendered.read_text(encoding="utf-8")
        clean = BLOCK.sub("", page)
        main = (re.search(r"<main\b.*?</main>", clean, re.S) or [""])[0]
        greek = bool(re.search("[Ͱ-Ͽ]", (re.search(r'<h1 class="title">(.*?)</h1>', clean, re.S) or [None, ""])[1]))
        items = []
        for name, note in PAGES.get(f"{project.name}/{source.stem}", []):
            if TARGETS[name][0] not in main:                      # not linked from the page already
                items.append((name, html.escape(note or TARGETS[name][2])))
        calls = rwf_calls(source.read_text(encoding="utf-8"))
        if calls:
            code = [f"<code>{name}()</code>" for name in calls]
            listed = code[0] if len(code) == 1 else f"{', '.join(code[:-1])} {WORDS[greek][2]} {code[-1]}"
            items.append(("rwf", WORDS[greek][3].format(listed)))
        new = clean
        if items and "</main>" in clean:
            at = clean.index("</main>")
            new = clean[:at] + section(items, greek) + "\n" + clean[at:]
            total += 1
        if new != page:
            rendered.write_text(new, encoding="utf-8", newline="\n")
            written += 1
print(f"{DOCS}: See also in {total} tutorials, {written} pages written")
