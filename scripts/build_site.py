#!/usr/bin/env python3
"""Builds the public PersonalOS website in docs/site/.

    python3 scripts/build_site.py

Three pages, no external resources (a privacy page shouldn't load anything
from a third party):

  docs/site/index.html                 a short landing page
  docs/site/privacy/index.html         from docs/privacy-policy.md
  docs/site/delete-account/index.html  how to delete an account (Google Play
                                       requires a web address for this)

The site is served by GitHub Pages from its own public repository; the app's
repository stays private. To publish, copy docs/site/ into a checkout of that
repository, commit and push.

The Markdown reader below handles only what the policy uses: headings,
paragraphs, "- " lists, pipe tables, **bold**, `code` and [links](url).
"""

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "docs" / "site"
SUPPORT = "sand.it.support@gmail.com"

MARK = (
    '<svg viewBox="130 130 764 764" width="34" height="34" aria-hidden="true">'
    '<circle cx="512" cy="512" r="263.5" fill="none" stroke="#fff" '
    'stroke-opacity=".28" stroke-width="87"/>'
    '<path d="M 512 248.5 A 263.5 263.5 0 1 1 253.3 561.8" fill="none" '
    'stroke="#FFBB6E" stroke-width="87"/>'
    '<circle cx="512" cy="205" r="43.5" fill="#FFBB6E"/>'
    '<circle cx="210" cy="570" r="74" fill="#fff"/></svg>'
)

CSS = """
:root { --bg:#f6f4fb; --card:#fff; --text:#1c1b18; --muted:#5d5a66;
  --line:#e4e0ee; --link:#4c37be; --head-a:#7460ef; --head-b:#4c37be; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#141318; --card:#1e1d24; --text:#f1eff6; --muted:#aaa6b6;
    --line:#33313c; --link:#b4a7ec; }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body { margin:0; background:var(--bg); color:var(--text);
  font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
    "Helvetica Neue", Arial, sans-serif; }
header { background: linear-gradient(180deg, var(--head-a), var(--head-b)); }
header a { display:flex; align-items:center; gap:10px; max-width:760px;
  margin:0 auto; padding:18px 16px; color:#fff; text-decoration:none;
  font-weight:800; font-size:21px; letter-spacing:-.02em; }
main { max-width:760px; margin:0 auto; padding:8px 16px 48px; }
h1 { font-size:30px; line-height:1.2; letter-spacing:-.02em; margin:28px 0 8px; }
h2 { font-size:20px; line-height:1.3; margin:36px 0 8px; padding-top:20px;
  border-top:1px solid var(--line); }
p, ul, ol { margin:12px 0; }
ul, ol { padding-left:22px; } li { margin:6px 0; }
a { color:var(--link); }
code { font: 0.9em ui-monospace, SFMono-Regular, Menlo, monospace;
  background:var(--line); padding:1px 5px; border-radius:5px; }
.table { overflow-x:auto; margin:14px 0; border:1px solid var(--line);
  border-radius:12px; background:var(--card); }
table { border-collapse:collapse; width:100%; font-size:15.5px; }
th, td { text-align:left; vertical-align:top; padding:10px 12px;
  border-bottom:1px solid var(--line); }
tr:last-child td { border-bottom:0; }
th { font-size:13px; text-transform:uppercase; letter-spacing:.05em;
  color:var(--muted); }
.card { background:var(--card); border:1px solid var(--line);
  border-radius:16px; padding:6px 18px; margin:18px 0; }
.links a { display:block; padding:14px 0; font-weight:700;
  border-bottom:1px solid var(--line); text-decoration:none; }
.links a:last-child { border-bottom:0; }
footer { max-width:760px; margin:0 auto; padding:0 16px 40px;
  color:var(--muted); font-size:14px; }
"""


def page(title: str, body: str, home: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<header><a href="{home}">{MARK}<span>PersonalOS</span></a></header>
<main>
{body}
</main>
<footer>PersonalOS is published by Sandeep Choudhary.
Contact: <a href="mailto:{SUPPORT}">{SUPPORT}</a></footer>
</body>
</html>
"""


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    # A bare email address becomes a link (but not one already inside a tag).
    text = re.sub(
        r"(?<![\w:\"/>])([\w.+-]+@[\w-]+\.[\w.-]*\w)",
        r'<a href="mailto:\1">\1</a>',
        text,
    )
    return text


def markdown(source: str) -> str:
    source = re.sub(r"<!--.*?-->", "", source, flags=re.S)
    out: list[str] = []
    lines = source.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
            i += 1
        elif line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
            i += 1
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([c.strip() for c in lines[i].strip("|").split("|")])
                i += 1
            head, body = rows[0], rows[2:]  # rows[1] is the |---| rule
            cells = "".join(f"<th>{inline(c)}</th>" for c in head)
            table = [f"<thead><tr>{cells}</tr></thead><tbody>"]
            for row in body:
                cells = "".join(f"<td>{inline(c)}</td>" for c in row)
                table.append(f"<tr>{cells}</tr>")
            out.append(
                '<div class="table"><table>' + "".join(table) + "</tbody></table></div>"
            )
        elif line.startswith("- "):
            items: list[str] = []
            while i < len(lines) and (
                lines[i].startswith("- ") or lines[i].startswith("  ")
            ):
                if lines[i].startswith("- "):
                    items.append(lines[i][2:])
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append(
                "<ul>" + "".join(f"<li>{inline(t)}</li>" for t in items) + "</ul>"
            )
        else:
            para = []
            while (
                i < len(lines)
                and lines[i].strip()
                and not lines[i].startswith(("#", "|", "- "))
            ):
                para.append(lines[i].strip())
                i += 1
            out.append(f"<p>{inline(' '.join(para))}</p>")
    return "\n".join(out)


HOME = f"""
<h1>PersonalOS</h1>
<p>Your money, habits, tasks, notes and documents in one private app that
works offline. Everything you enter is stored on your phone; an account is
optional.</p>
<div class="card links">
<a href="privacy/">Privacy policy</a>
<a href="delete-account/">Delete your account and data</a>
<a href="mailto:{SUPPORT}">Contact support</a>
</div>
"""

DELETE = f"""
<h1>Delete your PersonalOS account and data</h1>
<p>This page is for people who use <strong>PersonalOS</strong>, the app
published by Sandeep Choudhary, and want their account and the data stored
for it deleted.</p>

<h2>In the app</h2>
<ol>
<li>Open PersonalOS and go to <strong>Sync &amp; account</strong>.</li>
<li>Choose <strong>Delete account</strong> and confirm.</li>
</ol>
<p>Your account is deleted straight away.</p>

<h2>If you can't use the app</h2>
<p>Email <a href="mailto:{SUPPORT}?subject=Delete%20my%20PersonalOS%20account">{SUPPORT}</a>
from the email address on your account, with the subject
&ldquo;Delete my PersonalOS account&rdquo;. We delete the account within 30
days and reply to confirm. We may ask you to confirm from that address
first, so that nobody else can delete your account.</p>

<h2>What is deleted</h2>
<ul>
<li>Your account: your email address, your name if you gave one, and your
sign-in details.</li>
<li>Everything synced to our server: your encrypted data, the copies of your
encryption key, and the list of your devices.</li>
<li>Your voice-entry usage counts and the record of your plan.</li>
</ul>
<p>Nothing from a deleted account is kept afterwards, apart from what we are
legally required to retain, if anything.</p>

<h2>What is not deleted</h2>
<ul>
<li><strong>The data on your phone.</strong> It stays in the app until you
clear the app's data or uninstall it.</li>
<li><strong>A PersonalOS Plus subscription.</strong> Deleting your account
does not cancel it. Cancel it in Google Play (Payments and subscriptions)
so that you are not charged again.</li>
</ul>

<h2>Deleting only some of your data</h2>
<p>You can delete any item inside the app; with sync on, the deletion
reaches our server too. To have your synced data removed from our server
while keeping your account, email us at the address above.</p>

<p>See also the <a href="../privacy/">privacy policy</a>.</p>
"""


def main() -> None:
    policy = (ROOT / "docs" / "privacy-policy.md").read_text(encoding="utf-8")
    pages = {
        "index.html": page("PersonalOS", HOME, "./"),
        "privacy/index.html": page(
            "PersonalOS Privacy Policy", markdown(policy), "../"
        ),
        "delete-account/index.html": page(
            "Delete your PersonalOS account", DELETE, "../"
        ),
    }
    for name, content in pages.items():
        target = SITE / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        print(f"wrote {target.relative_to(ROOT)}")
    (SITE / ".nojekyll").touch()


if __name__ == "__main__":
    main()
