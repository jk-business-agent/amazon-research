# American Business Comparative Research Workflow

## Purpose

This agent is a research lead. Its job is to take the Amazon product research already compiled by
the sibling agent at `../Competitor Research Agent/` (a separate, independently-scheduled daily
"Amazon top sellers" workflow) and find comprehensive American business alternatives for the most
promising products — same or higher quality, regardless of price difference — compiled into a
dashboard the user can scan to quickly understand the who, where, and what of each alternative found.

This agent does not run on a fixed "daily" cadence independent of whether new input exists. It is
**event-triggered**: it should do real work once per new dated report the sibling agent publishes,
and otherwise no-op cheaply. Whatever schedule eventually calls this workflow can therefore run
frequently — Step 0 below is what makes that safe.

Before every run, execute `bash scripts/clear-stale-lock.sh` to remove any stale
`.claude/scheduled_tasks.lock` file left by a previous failed or interrupted run. This is a bash
script specifically because it must run unmodified in both this developer's local Windows
environment (via Git Bash) and the unattended Linux-based cloud sandbox used for scheduled runs,
neither of which can be assumed to have the other's shell available — do not reintroduce a
PowerShell-only or cmd-only version of this step.

Reference files this workflow depends on:
- `../Competitor Research Agent/docs/` — the sibling agent's rendered reports (read-only; never write here)
- `resources/category-taxonomy.md` — fixed category labels + colors (shared, unmodified)
- `resources/seen-products-history.json` — this agent's own rolling 14-day history + sibling-report cursor
- `resources/dashboard-template.html` — the HTML shell with `{{TOKEN}}` placeholders to fill in

Do not ask clarifying questions mid-run. Make the most reasonable, conservative choice (favor
under-claiming over fabricating) and note any judgment call in the methodology footer instead of
stopping.

## Error handling & stopping criteria

Every step below that can fail refers back to this section instead of repeating itself. Three
possible outcomes for a run:

- **SUCCESS** — dashboard written, history updated, committed and pushed normally.
- **HARD STOP** — an environment-level problem (the specific cases are called out in Steps 0a, 0b,
  and 10.1). Send a notification naming exactly what failed, stop without fabricating anything, and
  do not commit.
- **DEGRADED SUCCESS** — the run completes and a dashboard is still published, but one or more
  products or sources were skipped along the way because of repeated errors (see the circuit
  breaker below). Ship the report anyway; surface what was skipped in `{{METHODOLOGY_NOTES}}`
  (Step 6) and in the notification (Step 9) rather than silently producing a thinner report.

**Retry ceiling for any web fetch:** one retry on the same URL, no artificial delay — a
bot-detection page or CAPTCHA will not clear in the few seconds an agent would "wait," so pausing
buys nothing. If the retry also fails, do not attempt that exact URL a third time. Instead pivot to
a different source or a reworded search for the same fact. Log the abandoned source in one terse
line (not a paragraph) and move on.

**Per-product circuit breaker:** if a single product accumulates 3 source failures during Step 3
with zero alternatives found for it, stop researching that product. Mark it "research incomplete —
repeated source errors" and move on to the next product in Step 2's order. Never let one product's
errors consume the run.

**Cost-conscious research:** prefer `WebSearch` snippets for initial discovery and quick
verification scanning; reserve `WebFetch` (full-page) for the specific page actually needed to
confirm a Step 4 fact (founder bio, contact page, certification listing). This keeps the baseline
cost of Step 3 down and makes retry pivots cheaper too, since a search-based pivot costs less than
another full-page fetch.

## Step 0 — New-report detection (no-op check)

### Step 0a — Bootstrap sibling repo access (required on every run, including cloud/unattended runs)

`../Competitor Research Agent/` is a local checkout of the sibling agent's content. On a developer's
own machine it already exists side-by-side with this repo. On a fresh cloud/scheduled run, this
repo's working tree is the only thing checked out — `../Competitor Research Agent/` will not exist yet.
Both projects are the same git remote (`origin`, currently
`https://github.com/jk-business-agent/amazon-research.git`), just different branches: the sibling's
daily reports live on `main`; this agent's own work lives on `american-business-research`. Use that
fact to bootstrap read-only access to the sibling's content on every run, before Step 0b:

- If `../Competitor Research Agent/` does not exist: `git clone --branch main --single-branch <origin
  URL of this repo> "../Competitor Research Agent"`.
- If it already exists (e.g. a developer's local machine where it's a real separate working copy):
  leave it alone if it's not a git repository pointed at this same remote/branch (don't clobber a
  human's real working directory); if it IS the bootstrap-created clone from a prior run, `git pull`
  it to refresh to the latest `main`.
- If the clone/pull itself fails (no GitHub auth in this environment, network failure, remote
  unreachable), retry once immediately (per the retry ceiling in "Error handling & stopping
  criteria" — no artificial delay) in case it was a transient hiccup. If it fails again, this is a
  real environment problem, not a routine no-op: this is a **HARD STOP**. Send a notification
  describing exactly what failed, and stop without fabricating anything. Do not proceed to Step 0b.

### Step 0b — Compare against last-processed cursor

Read `../Competitor Research Agent/docs/index.html` to find the sibling's most recent dated report
folder link (e.g. `June17_2026/`). If that index looks stale, empty, or unparsable, fall back to
listing `../Competitor Research Agent/docs/` directly for folders matching `{Month}{Day}_{Year}` and
take the most recent by date.

Read `resources/seen-products-history.json` and compare that folder name to
`last_processed_sibling_report`:

- **They match, or no sibling report folder exists at all** — true no-op. Do not write a dashboard,
  do not commit, do not send a notification. Stop here. This is the expected outcome on most runs if
  the workflow is invoked on a frequent schedule, and is not an error.
- **They differ (a new sibling report exists that hasn't been processed yet)** — continue to Step 1.
- **The sibling's `docs/` path itself does not exist or cannot be read after Step 0a's bootstrap
  succeeded** (distinct from "no new report" — this means the sibling project's structure changed
  unexpectedly) — this is a real problem, not a routine no-op: a **HARD STOP**. Send a notification
  naming the exact path checked, and stop without fabricating anything. Do not commit.

## Step 1 — Parse the sibling's latest report

The sibling repo has no structured JSON export of its products — only its own
`seen-products-history.json` (a date/key log with no price, category, or narrative text) and the
rendered HTML report itself. Read
`../Competitor Research Agent/docs/{latest folder}/index.html` directly and parse each
`<div class="card">` block:

- `.card-title` → product name
- `.pill` text + its inline `style="background:..."` hex → category
- `.tag-new` / `.tag-recurring` → the sibling's own NEW/RECURRING tag (context only — this agent
  tracks its own NEW/RECURRING independently in Step 5)
- `.tag-verified` / `.tag-lowconf` → the sibling's own confidence tag (context only)
- `.card-why` → why it's selling (context for the rationale in Step 2/Step 6)
- `.card-meta` → price band / other meta lines
- `.card-sources` → source links (context only, not re-cited as this agent's own sources)

Treat this as a real file-read-before-acting step. Do not guess at card contents you have not
actually read.

## Step 2 — Filter and prioritize

- **Hard-exclude Electronics.** Drop any parsed product whose category is Electronics before any
  further processing — never research alternatives for it, never display it.
- **Carry forward every remaining non-Electronics product.** Do not cap the shortlist the way the
  sibling's daily-discovery workflow does (that 15-25 cap exists because it's bounded by daily trend
  volume). For this agent, the candidate set is simply "whatever the sibling published in its latest report, minus Electronics."
- **Judge repurchase interest per product, not per category.** Categories mix durables and
  consumables (e.g. Home & Kitchen contains both a one-time-purchase fry pan and a repeatedly-bought
  roll of parchment paper). For each product write one explicit line: "repurchase interest:
  high/medium/low — reason." This judgment feeds display order in Step 6, it does not exclude
  anything.
- **The $25–$100 price band governs display order only, never inclusion.** CLAUDE.md says to
  prioritize these products "in the display order of the report" — it does not say to drop products
  outside that band. Use the sibling's parsed price band where available; if a product's price wasn't
  confirmed by the sibling, treat it as outside the $25–$100 priority band for ordering purposes only
  (don't block research on it).
- **Final sort precedence for product-group order** (apply in this order, ties broken by the next
  criterion): (1) this agent's own NEW products before RECURRING (per Step 5's history, not the
  sibling's tag), (2) within that, $25–$100 band before outside-band, (3) within that, higher
  repurchase-interest before lower. Record this precedence in the methodology footer.

## Step 3 — Research Delegation (per-product subagents)

Do not research any product inline in the main agent context — all web fetches and raw page content
must stay inside dedicated per-product subagent contexts. The main agent's role in this phase is to
launch one subagent per product (in the Step 2 sort order), collect each compact result block, and
then proceed to Step 5.

**Why subagents:** research for 15–20 products × 2–3 alternatives each means 90+ web sources
flowing into a single context window. Per-product subagents isolate that content and return only a
compact structured summary, keeping the main context bounded regardless of product count.

### Step 3a — Subagent prompt template

For each product in Step 2's sorted list, construct and launch a subagent with the following prompt.
Fill in the bracketed fields from Step 1's parsed data:

---
*[Begin subagent prompt]*

You are a research assistant finding American business alternatives to a specific Amazon product.
Work through the tasks below and return your findings in the exact format specified. Do not ask
questions. If a fact cannot be found, write "not found in available sources" — never fabricate.

**Your assigned Amazon product:**
- Name: [product name from Step 1]
- Category: [category]
- Price band: [price band, or "not confirmed"]
- Why it's selling: [card-why text from Step 1]

**Task 1 — Repurchase judgment**
Write one line: "Repurchase interest: high | medium | low — [one-sentence reason]."

**Task 2 — Find 2–3 American business alternatives**

Cap: stop once you have 2–3 credible alternatives or the search trail genuinely runs dry.

Search strategy:
- `"[product type] made in USA"`, `"American made [product type] brand"`,
  `"[product type] manufacturer USA family owned"`
- Made-in-USA certification directories relevant to this category
- `"[Amazon brand] alternative made in America"`,
  `"American made alternative to [Amazon product name]"`

Prefer `WebSearch` snippets for initial discovery and quick verification; use `WebFetch` only for a
page you genuinely need to read in full (a certification listing, a contact page, an affiliate terms
page). One retry on any failed URL; if the retry fails, pivot to a different source.

Circuit breaker: if you accumulate 3 source failures with zero alternatives found, stop and return
`ALTERNATIVES_FOUND: 0 | CIRCUIT-BREAKER` in your result.

**Verifying American-ness (VERIFIED vs LOW-CONFIDENCE):**
- VERIFIED requires two independent sources: the business's own claim plus one of — a
  certification-body listing, independent press naming the manufacturing location, or a
  public-records signal (state incorporation records, real factory address, USPTO/SEC filing)
- A claim backed only by the business's own About page or marketing copy is LOW-CONFIDENCE —
  label it visibly, never silently upgrade it

**Task 3 — Capture per-alternative data**

For each alternative found, collect:
1. Product comparison — quality, features, price vs. the Amazon product (objective, no editorializing)
2. Business overview — what they sell, how long operating, scale (if sourced)
3. American-ness — ownership, manufacturing location, sourcing, how verified + one further-reading URL
4. Founder(s) — name(s) + one-line background + one further-reading URL
   (or "not found in available sources")
5. Affiliate program — Yes / No / Unconfirmed, + URL if Yes
6. Contact — public channels only: contact page URL, public email, or phone number
7. Sources — every URL you actually fetched, with today's date

**Required return format — use exactly this structure, no extra prose outside these fields:**

```
=== PRODUCT: [Amazon product name] ===
REPURCHASE: high|medium|low — [reason]
ALTERNATIVES_FOUND: [integer]

--- ALT 1 ---
ALT_NAME: [business or product name]
CONFIDENCE: VERIFIED | LOW-CONFIDENCE
AMAZON_SUMMARY: [quality / features / price — objective]
ALT_SUMMARY: [quality / features / price — objective]
OVERVIEW: [2–3 sentences]
AMERICAN_NESS: [claim + verification method] | SOURCE: [url]
FOUNDER: [names + background] | SOURCE: [url or "not found in available sources"]
AFFILIATE: Yes | No | Unconfirmed | LINK: [url or none]
CONTACT: [contact page url / public email / phone]
SOURCES: [url] ([date]), [url] ([date]), ...

--- ALT 2 ---
[same fields]
```

If zero alternatives were found, return only the product header with `ALTERNATIVES_FOUND: 0` and a
one-line note explaining why (trail ran dry / circuit breaker / no credible American manufacturers
found).

*[End subagent prompt]*

---

### Step 3b — Main agent: collect and aggregate

Run subagents sequentially (one product at a time). After each subagent returns, read its result
block and append it to a running list in the main agent's working context. Do not retain or
re-process any raw web content the subagent fetched — only the compact result block comes back.

After all products have been processed:
- Count total source URLs across all result blocks → `{{SOURCE_COUNT}}` for Step 6
- Note any product whose result block is missing (subagent error or timeout) — log it as
  "research incomplete — subagent did not return" in `{{METHODOLOGY_NOTES}}`
- Never fabricate a result block for a missing product

Proceed to Step 5.

## Step 4 — (Merged into Step 3)

Per-alternative data capture now runs inside each product's research subagent (Step 3, Task 3).
No separate inline data-capture phase runs in the main agent.

## Step 5 — Update `resources/seen-products-history.json`

For every product carried into this run (post Step 2 filtering):

- Normalize its name into a stable key: lowercase, hyphenated, brand + core product name only (strip
  size/color/pack-count variants).
- If the key is new (not present in the last 14 days), tag it **NEW** for this run, and add an entry
  with `first_seen` = `last_seen` = today, `seen_dates: [today]`.
- If the key already exists within the last 14 days, tag it **RECURRING** (note the streak, e.g.
  "appeared in 3 of last 5 reports"), append today to `seen_dates`, update `last_seen`, and update
  `alternatives_count` to this run's count.

Then prune any entry whose `last_seen` is more than 14 days before today. Set
`last_processed_sibling_report` to the sibling folder name consumed this run (Step 0), and
`last_updated` to today. Write the file back as valid JSON.

This file's keys are independent of the sibling's own `seen-products-history.json` — there is no
expectation that the two files' keys line up; this agent tracks its own comparative-research
lineage, not the sibling's trend-discovery lineage.

## Step 6 — Render the dashboard

Load `resources/dashboard-template.html` and fill every `{{TOKEN}}`:

- `{{REPORT_DATE}}` — e.g. "June 20, 2026".
- `{{SOURCE_COUNT}}` — number of distinct source URLs fetched this run (Step 3 subagents only —
  not the sibling's own cited sources).
- `{{EXEC_SUMMARY}}` — 3-6 sentences: which sibling report this run is based on, the overall
  narrative (standout alternatives, any notable American-made finding), and any judgment calls or
  degraded-mode notes worth surfacing up top.
- `{{STATS_PRODUCTS}}`, `{{STATS_ALTERNATIVES}}`, `{{STATS_NEW}}`, `{{STATS_RECURRING}}`,
  `{{STATS_VERIFIED}}`, `{{STATS_LOWCONF}}`, `{{STATS_CATEGORIES}}` — plain integers.
- `{{PRODUCT_GROUPS}}` — concatenated HTML, one outer product-group block per Amazon product (in
  Step 2's sort order), each containing one nested `.alt-card` per American alternative found for it:

```html
<div class="product-group">
  <div class="product-group-header">
    <div>
      <h3 class="product-title">{{Amazon product name}}</h3>
      <div class="product-meta">{{Amazon price band or "price not confirmed"}} &middot; <span class="pill" style="background:{{category hex color}}">{{category}}</span></div>
    </div>
    <div class="badge-row">
      <span class="tag {{tag-new|tag-recurring}}">{{NEW | RECURRING (streak: n/m)}}</span>
      <span class="tag tag-count">{{N}} alternative{{s}} found</span>
    </div>
  </div>
  <div class="product-rationale">{{1-3 sentences: repurchase-interest judgment + why this product was prioritized}}</div>
  <div class="alt-grid">
    <div class="alt-card">
      <div class="alt-card-top">
        <h4 class="alt-name">{{Business/product name}}</h4>
        <span class="tag {{tag-verified|tag-lowconf}}">{{VERIFIED AMERICAN-MADE | LOW-CONFIDENCE}}</span>
      </div>
      <div class="alt-compare">
        <div class="compare-col"><div class="compare-label">Amazon product</div><div>{{quality/feature/price summary}}</div></div>
        <div class="compare-col"><div class="compare-label">{{Business name}}</div><div>{{quality/feature/price summary, objective}}</div></div>
      </div>
      <div class="alt-section"><strong>Business overview:</strong> {{2-3 sentences}}</div>
      <div class="alt-section"><strong>American-ness:</strong> {{claim + how verified}} <a href="{{source}}">further reading</a></div>
      <div class="alt-section"><strong>Founder(s):</strong> {{names + background}} <a href="{{source}}">further reading</a></div>
      <div class="alt-section"><strong>Affiliate program:</strong> <span class="tag {{tag-affiliate-yes|tag-affiliate-no|tag-affiliate-unconfirmed}}">{{Yes | No | Unconfirmed}}</span> {{link if yes}}</div>
      <div class="alt-section"><strong>Contact:</strong> {{phone/email/contact-page link}}</div>
      <div class="alt-sources">Sources: <a href="{{url}}">{{domain}}</a> ({{access date}}){{repeat per source}}</div>
    </div>
    <!-- one .alt-card per alternative, up to the Step 3 soft cap -->
  </div>
</div>
```

- `{{CATEGORY_CHART_SVG}}` — a hand-built inline SVG horizontal bar chart, one row per category
  present this run (Electronics will never appear), bar width proportional to product count, using
  the same hex colors as `resources/category-taxonomy.md`:

```html
<svg width="100%" height="{{34 * num_categories + 10}}" viewBox="0 0 700 {{34 * num_categories + 10}}">
  <text x="0" y="22" font-size="13" fill="#1e293b">{{category name}}</text>
  <rect x="160" y="8" width="{{count * scale}}" height="18" rx="4" fill="{{category hex color}}"/>
  <text x="{{160 + count*scale + 8}}" y="22" font-size="12" fill="#475569">{{count}}</text>
</svg>
```

- `{{NEW_ENTRANTS_HTML}}` — short callout list of this run's NEW Amazon products (per Step 5, not the
  sibling's own NEW tag), each with a one-line note on why it's a promising comparative-research
  target. If zero NEW products this run, say so in a plain sentence instead of leaving it blank.
- `{{METHODOLOGY_NOTES}}` — short paragraph: which sibling report this run is based on, the sort
  precedence used (Step 2), the verification rule for American-ness claims (Step 3), the per-product
  alternative cap and whether it bound any product, and any degraded-mode notes. If this run ended
  in **DEGRADED SUCCESS** (see "Error handling & stopping criteria"), name which products were
  marked "research incomplete" and roughly how many sources were abandoned to repeated errors — one
  terse sentence is enough. If nothing was skipped, omit this and leave the paragraph as it would
  otherwise read.
- `{{PREVIOUS_REPORT_LINK}}` — if a previous report exists in this repo's `docs/`, a link like
  `Previous report: <a href="../June19_2026/">June 19</a>`; otherwise "First report."

## Step 7 — Folder/URL naming convention

Same convention as the sibling: `{FullMonthName}{Day}_{Year}` (full month name, no leading zero on
day, underscore, 4-digit year — e.g. June 20, 2026 → `June20_2026`). Save to
`docs/{FullMonthName}{Day}_{Year}/index.html`. If that exact folder already exists (a same-day
re-run), use `docs/{FullMonthName}{Day}_{Year}-2/index.html` instead (increment further if needed).
Everything inline — no external CDN, script, or stylesheet. The report's archive link is
`../index.html` (already set in `resources/dashboard-template.html`).

This repo's `docs/` is entirely independent of the sibling's `docs/` — never read or write across
that boundary except for the read-only Step 1 parse.

## Step 8 — Update the archive index

Open `docs/index.html`. On the very first real run, replace the `<div class="empty-state">` block
with a `<ul class="archive-list">`. On every run (including the first), prepend a new entry: the
date, a one-line headline summary of the run's most notable alternative, and a link to the new
report folder (`<a href="June20_2026/">View report →</a>` — trailing slash, no filename).

## Step 9 — Notify

Send a push notification once the file is written successfully, summarizing the run's single most
promising American alternative in under 200 characters. If the run ended in **DEGRADED SUCCESS**
(see "Error handling & stopping criteria"), briefly note that too (e.g. "... (2 products skipped:
source errors)") so a thinner report doesn't show up unexplained.

## Step 10 — Commit and push to `american-business-research` — never `main`

This repo shares `origin/main` with the sibling agent's **live, independently-scheduled** daily
routine. `main` must never receive a commit from this workflow.

1. Before committing anything, run `git branch --show-current`. If it is not
   `american-business-research`, this is a **HARD STOP** (see "Error handling & stopping
   criteria"): stop and notify instead of committing — do not commit to any other branch, especially
   `main`.
2. Stage and commit this run's changes: the new dated report folder, `docs/index.html`, and
   `resources/seen-products-history.json`.
3. Push to `origin american-business-research`. If the branch doesn't yet have an upstream, use
   `git push -u origin american-business-research`.
4. If the push fails (the remote has commits this clone doesn't), pull/rebase once against
   `origin/american-business-research` (never `origin/main`) and retry; if it still fails, note the
   failure in the push notification so the user knows the report exists locally but didn't reach the
   remote.
