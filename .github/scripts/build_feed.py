"""Build docs/feed.xml: an RSS feed of the newest tutorials of every site, for feed readers and R-bloggers.

R-bloggers (https://www.r-bloggers.com/add-your-blog/) takes feeds that are only about R, in English,
with the full post rather than an excerpt, and without base64 images. So each item holds the whole page,
from the rendered sites in docs/<site>/:
- the content of <main>, without the title block (the item has the title), buttons and scripts;
- interactive charts (htmlwidgets) need JavaScript, which feed readers do not run: each one becomes a
  link to the page, named by the chart's title; R code is kept as plain text, without the markup of
  its highlighting;
- links and images point to the site; a page without a static image starts with the card of its site,
  so the post has a picture (R-bloggers shows the first image of a post next to it).
Left out: the home pages of the sites, pages without R code, and pages whose title is in Greek.
An item is dated by the commit that added its page, so it shows up once, when the page is new, and the
feed holds the ITEMS newest pages. Rebuilt from scratch on every run, so it changes only when a page
does.

Run by the GitHub workflow after rendering, and by render.R. Set DOCS_DIR to write somewhere else
(render.R uses _preview/).
"""
import html
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[2]
QUARTO = ROOT / "quarto"
DOCS = Path(os.environ.get("DOCS_DIR", ROOT / "docs"))
BASE = "https://sedzinfo.github.io/vignettes/"
ITEMS = 10
TITLE = "sedzinfo · R tutorials"
DESCRIPTION = ("Tutorials in R with the code on every page: psychometrics, adaptive testing, scale validation, "
               "statistics, machine learning and data visualisation with real data.")


def website_title(project):
    match = re.search(r'^  title:\s*"?(.*?)"?\s*$', (project / "_quarto.yml").read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else project.name


def added(source):
    """When the page was first committed (the file's date when it is not committed yet)."""
    dates = subprocess.run(["git", "log", "--follow", "--diff-filter=A", "--format=%aI", "--", str(source)],
                           cwd=ROOT, capture_output=True, text=True).stdout.split()
    if dates:
        return datetime.fromisoformat(dates[-1])
    return datetime.fromtimestamp(source.stat().st_mtime, timezone.utc)


def text_of(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def chart_title(data):
    """The title of an htmlwidget (plotly or highcharter) from its JSON data, or ''."""
    try:
        x = json.loads(data).get("x") or {}
    except ValueError:
        return ""
    title = (x.get("layout") or {}).get("title") or ((x.get("hc_opts") or {}).get("title") or {})
    title = title.get("text", "") if isinstance(title, dict) else title
    return text_of(re.sub(r"<br\s*/?>", " ", str(title or "")))


def content(page, url):
    """The body of a rendered page as feed-ready HTML, or None if the page has no <main>."""
    main = re.search(r'<main class="content" id="quarto-document-content"[^>]*>(.*)</main>', page, re.S)
    if not main:
        return None
    body = main.group(1)
    titles = {wid: chart_title(data) for wid, data in
              re.findall(r'<script type="application/json" data-for="([^"]+)">(.*?)</script>', body, re.S)}
    body = re.sub(r'<header id="title-block-header".*?</header>', "", body, flags=re.S)
    body = re.sub(r"<(script|style|button)\b.*?</\1>", "", body, flags=re.S)
    body = re.sub(r'<div(?=[^>]*\bclass="[^"]*\bhtml-widget\b)[^>]*\bid="([^"]+)"[^>]*>\s*</div>',
                  lambda m: f'<p><a href="{url}">Interactive chart: '
                            f'{html.escape(titles.get(m.group(1)) or "see it on the original page")}</a></p>', body)
    body = re.sub(r'<a href="#cb\d+-\d+"[^>]*></a>', "", body)           # line anchors of code blocks
    body = re.sub(r'<pre class="sourceCode r[^"]*">(.*?)</pre>',
                  lambda m: f'<pre><code class="language-r">{html.escape(text_of(m.group(1)), quote=False)}</code></pre>',
                  body, flags=re.S)

    def absolute(match):
        attribute, value = match.group(1), html.unescape(match.group(2))
        if value.startswith("#"):
            value = url + value
        elif not re.match(r"[a-z][a-z0-9+.-]*:|//", value):
            value = urljoin(url, value)
        return f'{attribute}="{html.escape(value)}"'

    body = re.sub(r'\b(src|href)="([^"]*)"', absolute, body)
    return re.sub(r"\n\s*\n+", "\n", body).strip()


items = []
for config in sorted(QUARTO.glob("*/_quarto.yml")):
    project = config.parent
    site_title = website_title(project)
    for source in sorted(p for p in project.iterdir() if p.suffix.lower() in (".rmd", ".qmd") and p.stem != "index"):
        rendered = DOCS / project.name / f"{source.stem}.html"
        if not rendered.exists():
            continue
        page = rendered.read_text(encoding="utf-8")
        title = text_of((re.search(r'<h1 class="title">(.*?)</h1>', page, re.S) or [None, source.stem])[1])
        if '<pre class="sourceCode r' not in page or re.search("[Ͱ-Ͽ]", title):
            continue                                                       # no R code, or not in English
        url = f"{BASE}{project.name}/{rendered.name}"
        body = content(page, url)
        if body is None:
            print(f"::warning::{rendered}: no <main> found; left out of the feed")
            continue
        summary = (re.search(r'<meta name="description" content="([^"]*)"', page) or [None, ""])[1]
        if "<img" not in body:
            body = (f'<p><img src="{BASE}{project.name}/social-card.png" alt="{html.escape(site_title)}" '
                    f'width="1200" height="630"></p>\n{body}')
        items.append({"title": title, "url": url, "site": site_title, "date": added(source),
                      "summary": html.unescape(summary), "body": body})

items = sorted(items, key=lambda i: (i["date"], i["url"]), reverse=True)[:ITEMS]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


entries = []
for i in items:
    body = (f'<p><em>{html.escape(i["summary"])}</em></p>\n{i["body"]}\n'
            f'<p>This post first appeared on <a href="{i["url"]}">{html.escape(i["site"])}</a>, '
            f'with its interactive charts and the full R code.</p>')
    entries.append(f"""    <item>
      <title>{html.escape(i["title"])}</title>
      <link>{i["url"]}</link>
      <guid isPermaLink="true">{i["url"]}</guid>
      <pubDate>{format_datetime(i["date"])}</pubDate>
      <category>R</category>
      <category>{html.escape(i["site"])}</category>
      <description>{html.escape(i["summary"])}</description>
      <content:encoded>{cdata(body)}</content:encoded>
    </item>""")

feed = f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- Written by .github/scripts/build_feed.py. Do not edit by hand. -->
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>{html.escape(TITLE)}</title>
    <link>{BASE}</link>
    <atom:link href="{BASE}feed.xml" rel="self" type="application/rss+xml"/>
    <description>{html.escape(DESCRIPTION)}</description>
    <language>en</language>
    <lastBuildDate>{format_datetime(items[0]["date"]) if items else ""}</lastBuildDate>
{chr(10).join(entries)}
  </channel>
</rss>
"""
DOCS.mkdir(exist_ok=True)
(DOCS / "feed.xml").write_text(feed, encoding="utf-8", newline="\n")
print(f"{DOCS / 'feed.xml'}: {len(items)} items, {len(feed) // 1024} KB")
