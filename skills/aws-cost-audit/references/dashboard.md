# Generating the HTML dashboard

The dashboard is an **optional** deliverable: one self-contained `index.html` you hand the user after
the audit. It renders the verified savings model as a dark, single-page view — a "pay today" header, a
**"save now safely" vs "max theoretical"** split, a spend-by-service chart, and one card per resource
(cost / purpose / owner / created / last-used / verdict / confidence).

It is a **view of already-verified data**, not a place to compute or guess. By the time you generate
it, every dollar has been re-derived from the live AWS Price List Query API and actual Cost Explorer /
CUR usage (Law 1) and a separate skeptic pass has signed off (Law 4). The dashboard only substitutes
those verified values into a template.

## Hard rules for the generated file

- **Zero hardcoded prices.** No unit price, no `$X`, no rate is written into the template. Every number
  comes from the user's verified run. If a figure is not yet verified, it does not go on the dashboard.
- **Zero secrets / account-specific tokens.** No raw 12-digit account id, no concrete ARN, no public
  IP, no resource id (`i-…`, `vol-…`, `nat-…`, `E…` CloudFront id, `eipalloc-…`). Use a generic account
  alias for the label, and resource *names/types* (not ARNs) in the cards.
- **"unknown" is a valid value.** If owner, created, or last-used could not be read from an API, write
  `"unknown — could not verify"` (or `"unknown — predates CloudTrail window"`). Never guess. The
  template styles `unknown` values in muted italic automatically.
- **No emojis.** Plain text only.
- **Self-contained.** One file. Fonts and Chart.js load from CDN; the dashboard degrades gracefully to
  a text fallback if Chart.js is blocked. No build step, no local assets.

## Inputs you need before generating

From the verified savings model (Law 5 output contract), collect:

1. **Headline run-rate** — the monthly "pay today" figure, reconciled to Cost Explorer.
2. **Period spend + window** — the analyzed window (e.g. `30d unblended <start> → <end>`) and its total.
3. **Save-now-safely total** — sum of High-confidence, reversible, tested savings only.
4. **Max-theoretical total** — sum of all recommended savings (incl. sign-off / commitment / unverified-
   reversibility items).
5. **Per-resource rows** — for each resource or service group, the full card object (schema below).
6. **Region note** — which Region(s) the live prices were verified for.

## The template

`assets/dashboard-template.html` is the generic source. It contains clearly-marked `{{PLACEHOLDERS}}`
and a small JS loop that renders an array of card objects into the grid and the chart. To generate the
deliverable, **read the template, substitute the placeholders, and write the result as the user's
`index.html`.** Do not modify the template in place.

### String placeholders (plain substitution)

| Placeholder | Fill with | Notes |
|---|---|---|
| `{{TITLE}}` | Page/brand title, e.g. `AWS cost audit` | Used in `<title>` and header |
| `{{ACCOUNT_LABEL}}` | Generic account alias, e.g. `account: prod-shared` | **Never** the raw 12-digit id |
| `{{GENERATED_AT}}` | ISO date/time of the audit data | e.g. `2026-05-28` |
| `{{PERIOD_LABEL}}` | Cost window | e.g. `30d unblended 2026-04-23 → 2026-05-23` |
| `{{TOTAL_MONTHLY}}` | Monthly run-rate number | **no currency symbol** — symbol is separate |
| `{{PERIOD_SPEND}}` | Spend over the window, number | no symbol |
| `{{SAVE_NOW}}` | Save-now-safely total, number | no symbol |
| `{{MAX_THEORETICAL}}` | Max-theoretical total, number | no symbol |
| `{{CURRENCY}}` | Currency symbol, e.g. `$` | Cost Explorer reports in the account's billing currency — use that symbol, do not assume USD |
| `{{REGION_NOTE}}` | Free text on price provenance | e.g. `prices verified live for ap-south-1 + us-east-1` |

### JS data placeholders (substitute with valid JSON)

| Placeholder | Fill with |
|---|---|
| `/*{{SERVICE_CARDS_JSON}}*/` | A JSON array of card objects (schema below). Replaces the `[]` after it. |
| `/*{{SAVINGS_SPLIT_JSON}}*/` | Optional. Only present if you extend the template with an extra chart; the shipped template does not require it. |

Substitute the JSON **immediately after** the `/*{{SERVICE_CARDS_JSON}}*/` comment, replacing the empty
`[]`. For example, the line:

```js
const CARDS = /*{{SERVICE_CARDS_JSON}}*/ [];
```

becomes:

```js
const CARDS = [ { /* card 1 */ }, { /* card 2 */ } ];
```

### Card object schema

Every card needs every field. Where a value is unverifiable, use an `"unknown — …"` string rather than
omitting or guessing it.

```js
{
  name:       "RDS db.r7g.large (prod)",   // resource or service-group label (type/name, NOT an ARN)
  sub:        "marketplace database",       // optional subtitle (purpose hint / generic id — no real ARN)
  cost:       170,                           // current monthly cost, number (from CE/CUR, no symbol)
  save:       85,                            // monthly savings if the action is taken; 0 for KEEP
  purpose:    "Production marketplace DB",   // plain-language purpose
  owner:      "Platform team",               // owning team/app/repo, or "unknown — could not verify"
  created:    "2024-02-11",                  // or "unknown — predates CloudTrail window"
  lastUsed:   "3.8% avg CPU over 14d",       // last-used signal (CW/access-log/last-invocation) or "unknown"
  verdict:    "optimize",                     // delete | optimize | keep | decision  (see below)
  confidence: "HIGH",                         // HIGH | MED | LOW
  evidence:   "14d CloudWatch: 3.8% avg CPU, 1.4 avg connections → oversized",  // why this verdict
  project:    "Marketplace"                   // optional grouping label
}
```

**Verdict → meaning → accent colour** (the template maps these automatically):

| `verdict` | Meaning | Accent |
|---|---|---|
| `delete` | Safe-to-delete: proven unused (multiple signals, 30–90d) + reversible + tested | green |
| `optimize` | Rightsize / change config (gp2→gp3, instance class, log retention) | yellow |
| `keep` | Justified spend, no action | grey |
| `decision` | Needs owner sign-off, a commitment (SP/RI), or has unverified reversibility | red |

Mapping from the SKILL.md classification: `SAFE-TO-DELETE` → `delete`, `OPTIMIZE` → `optimize`,
`KEEP` → `keep`. Anything irreversible or requiring human sign-off (release EIP, delete snapshot, RI/SP
purchase) is `decision`, never `delete`, regardless of confidence.

### Confidence badge

`confidence` ∈ `HIGH | MED | LOW`. It comes straight from the per-item confidence in the savings model
(Law 5). HIGH renders green, MED yellow, LOW red. Only HIGH-confidence + reversible + tested items
should count toward `{{SAVE_NOW}}`; everything else is part of `{{MAX_THEORETICAL}}` only.

## Generation procedure

1. Confirm the savings model is verified (prices live, skeptic pass done). If not, stop — the dashboard
   only renders verified data.
2. Read `assets/dashboard-template.html`.
3. Build the `CARDS` JSON array from the per-resource findings. Scrub every value: no ARNs, IPs,
   account ids, or raw resource ids; `unknown — …` for anything unverifiable.
4. Compute the four headline numbers from the model (run-rate, period spend, save-now, max-theoretical)
   — these are sums of values you already verified, not new estimates.
5. Substitute all `{{…}}` string placeholders and the `/*{{SERVICE_CARDS_JSON}}*/ []` array.
6. Write the result as the user's `index.html` (in their chosen output dir — not over the template).
7. **Verify the output**: open it / load it headless and confirm cards render, the chart draws (or the
   fallback shows), and a grep for forbidden tokens (12-digit ids, `arn:aws:`, `i-`, `vol-`, raw IPs)
   comes back empty.

## Self-check before handing it over

- [ ] No hardcoded price anywhere; every number traces to the verified run.
- [ ] No account id / ARN / IP / resource id; account shown via a generic alias.
- [ ] Every card has owner / created / last-used (or an explicit `unknown — …`).
- [ ] `{{SAVE_NOW}}` ≤ `{{MAX_THEORETICAL}}` and both ≤ run-rate; save-now is HIGH-confidence + reversible only.
- [ ] Verdicts and confidence match the savings model exactly.
- [ ] File opens standalone; chart degrades to text fallback if the CDN is blocked.
- [ ] No emojis.

A filled, synthetic example lives at `examples/sample-dashboard.html` (data is obviously fake and marked
`SAMPLE — synthetic data`). Use it to sanity-check rendering, never as a source of real numbers.
