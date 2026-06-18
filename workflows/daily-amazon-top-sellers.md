# Daily Amazon Top-Sellers Research Workflow

## Purpose

Produce one dashboard HTML report identifying ~15-25 cross-category products that are currently
hot-selling or rapidly-climbing on Amazon for U.S. consumers, with verified-where-possible context on
WHY each is selling, WHAT market segment it's in, and WHERE growth is projected. The audience is an
educator/writer/business owner who writes about economic growth and American business — they need to
quickly digest what's hot and trust that it's accurate, not skim something fabricated.

This workflow runs fully unattended (scheduled, no human in the loop). Before every run, the cloud routine should execute `scripts/clear-stale-lock.ps1` to remove any stale `.claude/scheduled_tasks.lock` file left by a previous failed or interrupted run. Do not ask clarifying questions
mid-run — make the most reasonable, conservative choice (favor under-claiming over fabricating) and
note any judgment call in the methodology footer instead of stopping.

Reference files this workflow depends on:
- `resources/category-taxonomy.md` — fixed category labels + colors
- `resources/seen-products-history.json` — rolling 14-day history of previously seen products
- `resources/dashboard-template.html` — the HTML shell with `{{TOKEN}}` placeholders to fill in

## Step 1 — Gather candidate products (public web research only)

Use WebSearch and WebFetch only. No paid API. Check, in this order, accepting partial failure of any
single source:

1. **Amazon Movers & Shakers** (amazon.com/gp/movers-and-shakers) — check this first; it surfaces
   rapidly-climbing items, which is the most interesting story for this audience.
2. **Amazon Best Sellers** (amazon.com/Best-Sellers/zgbs and per-category zgbs pages) for a rotating
   subset of ~8-10 categories from `resources/category-taxonomy.md` (rotate which categories you check
   each day so coverage isn't always identical) — don't spend the whole research budget on one category.
3. **Amazon New Releases** for the same category subset, if time/budget allows — optional third pass.
4. **Corroborating WebSearch** for retail/industry coverage: queries like "Amazon best seller [category]
   [month year]", "trending on Amazon this week", "[product name] sales surge", "[product name] viral
   social media", "[product name] sold out Amazon".
5. **General retail trend press** (CNBC, Retail Dive, Modern Retail, Business Insider, trade publications
   relevant to the category) to corroborate WHY a product is moving.

If an Amazon page returns a bot-detection/CAPTCHA page, blocked content, or is clearly throttled: retry
at most 2 times for that URL, then move on. Fall back to WebSearch-derived discovery (search for
bestseller snippets and secondary press/aggregator coverage) instead of forcing direct page access.
Record this fallback explicitly — it goes in the methodology footer (Step 6) so the user knows direct
access was degraded that day.

## Step 2 — Build the shortlist (15-25 items)

- Prioritize newly-appearing or fast-climbing items over static evergreen best-sellers.
- Span at least 5-6 distinct categories from `resources/category-taxonomy.md` — don't let one category
  (e.g. Electronics) dominate the list.
- Read `resources/seen-products-history.json`. For each shortlisted product, normalize its name into a
  stable key: lowercase, hyphenated, brand + core product name only (strip size/color/pack-count
  variants unless the variant itself is the story, e.g. "new flavor launch"). Look the key up in the
  history:
  - Not present in the last 14 days → tag **NEW**.
  - Present → tag **RECURRING** and note the streak (e.g. "appeared in 4 of last 7 reports").
- If fewer than 15 credible items can be found/verified that day, ship fewer rather than padding the
  list with weak or unverifiable entries. Never pad to hit a quota — say so in the executive summary.

## Step 3 — Verification protocol (apply to every product before inclusion)

Classify each candidate's confidence:

- **VERIFIED** — corroborated by at least 2 independent sources. Amazon's own Best
  Sellers/Movers & Shakers page counts as one source; a second independent source (a news article, a
  different retail-trend aggregator, or a second distinct Amazon list/category page) is required.
- **LOW-CONFIDENCE** — only one source found, or sources disagree on key facts. Include these only if
  genuinely interesting, and mark them visibly as such in the dashboard. Never silently upgrade
  confidence to make the report look cleaner.

When sources conflict on a specific number (rank, percent growth, review count): report the range or
state "sources disagree" rather than picking one arbitrarily. Do not average or guess.

## Step 4 — Per-product analysis

For each shortlisted item, produce:

1. **Product name + category + price band** (if visible on the page; write "price not confirmed" if not).
2. **Why it's selling** — a 2-4 sentence synthesis grounded in what sources actually say (seasonal
   demand, a viral social moment, a price drop, a supply-chain story, a health/wellness trend,
   back-to-school timing, a recall/shortage of a competing product, etc). If no clear driver can be
   sourced, say "no clear driver identified in available sources" rather than inventing a
   plausible-sounding reason.
3. **Market segment** — map to one label from `resources/category-taxonomy.md` (keep labels consistent
   day over day for trend-spotting).
4. **Growth outlook** — one of: Strong Growth / Steady / Possible Plateau / Likely Seasonal Dip, each
   with a one-line justification tied to sourced evidence. Label explicitly as a qualitative estimate,
   not a precise forecast.
5. **NEW / RECURRING tag** (from Step 2).
6. **Sources** — every source URL actually fetched/read for this specific product, with access date.

### Anti-fabrication rules — read before writing the report

- Never invent a specific sales-rank number, units-sold figure, or revenue figure that wasn't directly
  read from a fetched source. If a source says "a top seller in Kitchen" with no number, report that —
  do not invent "#3 in Kitchen."
- Never present a single-source claim as VERIFIED.
- Never silently drop the LOW-CONFIDENCE label to make the report look cleaner.
- If WebFetch/WebSearch return errors, blocked pages, or empty results for a meaningful portion of
  attempts, say so plainly in the methodology footer — do not quietly under-deliver without explanation.
- If fewer than ~10 credible candidates exist for the day, still publish — with a visible note
  explaining reduced scope — rather than skipping the day or inventing filler entries.
- Before writing a specific number into a card (a percentage, dollar figure, review count, growth rate),
  confirm it actually appears in the cited source's fetched content — not just that it's plausible given
  the source's general topic. A day-1 test run of this workflow cited a "15.7% two-week sales increase"
  figure that sounded consistent with the surrounding article but was not actually present in either
  cited source when spot-checked. Re-read the specific sentence/figure in the fetched content before
  including it, rather than reconstructing a number from memory of the general gist.

## Step 5 — Update the history file

Read `resources/seen-products-history.json`. For every shortlisted product:
- If its normalized key is new, add an entry with `first_seen` = `last_seen` = today, `seen_dates: [today]`.
- If it already exists, append today to `seen_dates` and update `last_seen`.

Then prune any entry whose `last_seen` is more than 14 days before today. Update `last_updated` to
today's date and `window_days` stays `14`. Write the file back as valid JSON.

## Step 6 — Render the dashboard

Load `resources/dashboard-template.html` and replace every `{{TOKEN}}` with generated content:

- `{{REPORT_DATE}}` — e.g. "June 17, 2026".
- `{{SOURCE_COUNT}}` — number of distinct source URLs fetched today.
- `{{EXEC_SUMMARY}}` — 3-6 sentences: the day's overall narrative (what's hot across categories, any
  standout new entrant, any broader economic-growth angle worth noting for this audience). If scope was
  reduced or a fallback was used, mention it here too, briefly.
- `{{STATS_TOTAL}}`, `{{STATS_NEW}}`, `{{STATS_RECURRING}}`, `{{STATS_VERIFIED}}`, `{{STATS_LOWCONF}}`,
  `{{STATS_CATEGORIES}}` — plain integers.
- `{{PRODUCT_CARDS}}` — concatenated HTML, one `<div class="card">` block per product, in this shape:

```html
<div class="card">
  <div class="card-top">
    <h3 class="card-title">{{product name}}</h3>
    <span class="pill" style="background:{{category hex color}}">{{category}}</span>
  </div>
  <div class="badge-row">
    <span class="tag {{tag-new|tag-recurring}}">{{NEW | RECURRING (streak: 4/7)}}</span>
    <span class="tag {{tag-verified|tag-lowconf}}">{{VERIFIED | LOW-CONFIDENCE}}</span>
  </div>
  <div class="card-why">{{why it's selling, 2-4 sentences}}</div>
  <div class="card-meta"><strong>Growth outlook:</strong> {{Strong Growth|Steady|Possible Plateau|Likely Seasonal Dip}} — {{one-line justification}}</div>
  <div class="card-meta">{{price band or "price not confirmed"}}</div>
  <div class="card-sources">Sources: <a href="{{url1}}">{{domain1}}</a> ({{access date}}){{, <a href="{{url2}}">{{domain2}}</a> (...) for each additional source}}</div>
</div>
```

  Order cards with VERIFIED + NEW items first (most newsworthy), then remaining VERIFIED items, then
  LOW-CONFIDENCE items last.

- `{{CATEGORY_CHART_SVG}}` — a hand-built inline SVG horizontal bar chart, one row per category present
  today, bar width proportional to product count, labeled with category name and count, using the same
  hex colors as the category taxonomy. Example pattern for one row (repeat per category, vertical offset
  by ~34px, scale bar width to fit a ~600px-wide chart):

```html
<svg width="100%" height="{{34 * num_categories + 10}}" viewBox="0 0 700 {{34 * num_categories + 10}}">
  <text x="0" y="22" font-size="13" fill="#1e293b">{{category name}}</text>
  <rect x="160" y="8" width="{{count * scale}}" height="18" rx="4" fill="{{category hex color}}"/>
  <text x="{{160 + count*scale + 8}}" y="22" font-size="12" fill="#475569">{{count}}</text>
</svg>
```

- `{{NEW_ENTRANTS_HTML}}` — short callout list (e.g. `<ul>`) pulling out just today's NEW items by name
  with a one-line "why it's new/interesting" note each. If there are zero NEW items today, write a plain
  sentence saying so instead of leaving the section blank.
- `{{METHODOLOGY_NOTES}}` — short paragraph: which source types were checked, the verification rule
  (2-source corroboration for VERIFIED), any degraded-mode fallback used today (e.g. "Amazon Movers &
  Shakers page was inaccessible; relied on secondary press coverage for category X"), and the full list
  of distinct source domains checked today.
- `{{PREVIOUS_REPORT_LINK}}` — if a previous day's report exists in `docs/`, a link/text like
  `Previous report: <a href="../June16_2026/">June 16</a>` (relative to today's report folder — see the
  path convention below); otherwise leave as "First report" text.

### Folder/URL naming convention

Each day's report gets its own folder so that GitHub Pages can serve a clean, human-readable URL
(`.../June17_2026/`) instead of a `.html` filename. Build the folder name as
`{FullMonthName}{Day}_{Year}` — full month name, day number with no leading zero, underscore, 4-digit
year (e.g. June 17, 2026 → `June17_2026`; January 3, 2027 → `January3_2027`).

Save the filled-in HTML to `docs/{FullMonthName}{Day}_{Year}/index.html` using today's actual date.
Check first whether that exact folder already exists (a same-day re-run) — if it does, do not overwrite
it; use `docs/{FullMonthName}{Day}_{Year}-2/index.html` instead (increment further if that also exists).
Do not reference any external CDN, script, or stylesheet — everything must be inline so the file opens
standalone with no network needed. Because the report now lives one directory level below `docs/`, its
link back to the archive must be `../index.html` (already set in `resources/dashboard-template.html` —
don't change it back to a bare `index.html`).

## Step 7 — Update the archive index

Open (or create, if it doesn't exist yet) `docs/index.html`. Prepend a new entry to a reverse-chronological
list: the date, a one-line headline summary of the day's most notable finding, and a link to the new
report folder (e.g. `<a href="June17_2026/">View report →</a>` — trailing slash, no filename, so GitHub
Pages resolves it to that folder's `index.html`). Keep `index.html` itself simple and dependency-free
(plain HTML list, same inline-style approach, no JS needed).

## Step 8 — Notify

Send a push notification once the file is written successfully, summarizing the day's single most
notable finding in under 200 characters (e.g. the most interesting NEW entrant or the day's headline
trend). If the run degraded significantly (e.g. zero verified products, or fewer than 10 credible items
found), notify with that fact instead so the user isn't surprised by a thin report.

## Step 9 — Commit and push

This workspace lives in a git repository so that each day's cloud run (a fresh, isolated sandbox) can
persist its work. After writing the new dashboard file, updating `resources/seen-products-history.json`,
and updating `docs/index.html`, commit all changed/new files and push to `origin main`:

```
git add resources/seen-products-history.json docs/ .claude/CLAUDE.md
git commit -m "chore: daily Amazon top-sellers report for YYYY-MM-DD"
git push origin main
```

If the push fails (e.g. the remote has commits this clone doesn't have), pull/rebase once and retry
before giving up; if it still fails, note the failure in the push notification so the user knows today's
report exists locally in the cloud sandbox but didn't make it back to the repo.
