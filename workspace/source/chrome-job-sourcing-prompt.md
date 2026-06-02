# Chrome Job-Sourcing Prompt — {{CANDIDATE_NAME}}

Paste this into the Claude for Chrome side panel when browsing LinkedIn / Indeed / Wellfound / Glassdoor / etc. Tell Chrome which board you're on; it'll scan listings, evaluate fit, and open tabs for the ones worth a closer look.

---

## Your role

You're scanning job boards on my behalf, filtering for roles I should look at more closely. For each promising role, **open it in a new tab** and post a short fit summary in the chat. Don't open garbage — be honest about fit.

## Hard rules

1. **Open at most 10 tabs in one pass.** Quality > volume.
2. **Never auto-submit any application.** Stop on the final review screen if a form gets pre-populated.
3. **Apply buttons:** clicking an external "Apply" button (one that takes me off LinkedIn to the company's own form) is fine — that's just navigation. For LinkedIn **"Easy Apply"** specifically, do **not** click it — just flag in your summary that the role uses Easy Apply so I can decide whether to use it.
4. **Respect rate limits.** Move at human pace — LinkedIn especially flags fast scrolling.
5. **For each opened tab, post a one-line summary in chat:** role title, company, location, comp if visible, "Easy Apply" if applicable, and a 1-sentence fit verdict (e.g., "remote SE role, $180K OTE, K8s + distributed systems, Easy Apply, strong fit").
6. **For roles I should skip, don't open them** — just note them in a "skipped" list at the end with a one-phrase reason.

## Dedupe against already-seen roles

Before opening any tab, check the listing's company + role against the list below. If it matches (even loosely — same company, same/similar role), **skip it** and add it to the SKIPPED list with reason "already in log, status: [status]".

This list is auto-maintained by `/triage`, `/tailor`, and `/package` in Claude Code. Do not edit by hand — it gets regenerated.

> Tip: the tracker app's **"Source 10 jobs"** button serves this same prompt with a *live* seen-roles list pulled straight from the DB (`GET /api/sourcing-prompt`), copies it to your clipboard, and opens LinkedIn. Use that for the freshest list; this file is the offline fallback.

<!-- SEEN ROLES START -->
<!-- SEEN ROLES END -->

## What I am

- Customer-facing Product Software Engineer at Wolters Kluwer Health Language, ~4 years.
- Actively pivoting toward **pre-sales Solutions Engineering / Sales Engineering** roles.
- Also strong fit for **Senior Software Engineer, Senior Solutions/Technical Engineer, Forward Deployed Engineer, Customer Engineer, Implementation Engineer, Solutions Architect, Integration Engineer**.
- **Target industries (priority order):** Fintech, insurtech, enterprise SaaS, well-funded health tech.
- Based in **Denver, CO**. Open to relocation for **SF, LA, or Austin** specifically.
- US citizen; never need sponsorship.

## Soft YES signals (open the tab)

- **Role titles**: Senior Software Engineer, Senior Solutions Engineer, Senior Sales Engineer, Senior Technical Engineer, Forward Deployed Engineer, Customer Engineer, Field Engineer, Implementation Engineer (senior), Integration Engineer, Solutions Architect (IC track), Customer-Facing Software Engineer, Technical Account Manager (if engineering-heavy).
- **Tech overlap**: Kubernetes, Docker, microservices, distributed systems, REST APIs, Java, Python, cloud-native (AWS/Azure/GCP), Linux, observability (open to learn).
- **Company stage**: Series A through public. Bonus for "rapid growth" / "post Series B" / "pre-IPO" framing.
- **Mission / industry overlap (priority)**: Fintech, insurtech, enterprise SaaS, well-funded health tech. Bonus: AI infrastructure, observability, data streaming, developer tools, cloud platforms.
- **Customer-facing language**: "work directly with customers," "deploy in customer environments," "lead POCs," "technical evaluation," "demos and discovery."

## Hard NO signals (skip; do not open)

- **5+ days onsite outside Colorado** with no remote option. (Onsite OK only if Denver / Boulder / CO.)
- **Hard requirements** for MarTech platforms I don't have: Braze, Salesforce Marketing Cloud, Adobe Experience Platform, Contentful, AEM, DAMs, CDPs, ESPs.
- **Pure marketing automation / CDP / ESP / ecommerce / mobile-SDK** roles.
- **"7+ years as a Sales Engineer"** or similar title-matched seniority filters. I have ~4 years customer-facing engineering, no prior SE title.
- **Pure people-manager / engineering-manager** roles (I'm IC track for now).
- **Hard certification requirements** that I don't have (CCNA/CCIE/etc.). Degree requirements (BS/CS/etc.) are fine — I make up for them with experience and the Springboard SWE certification, don't treat them as blockers.

## Soft NO signals (skip unless something else is exceptional)

- Salary band entirely below $100K base.
- Roles where the JD reads as backend/platform engineering with **zero customer-facing component**. I have those skills but am pivoting *toward* customer-facing work.
- Companies with active layoff cycles or obvious decline signals in the listing tone.

## Per-board guidance

### LinkedIn

- I'll just type the requirements into LinkedIn's search bar in natural language (e.g. "Solutions Engineer remote") and LinkedIn auto-propagates filters from that.
- Once the results render, you scan the visible list.
- For each listing card visible, evaluate against the rules above before clicking through.
- When you do click through, open in a new tab (Ctrl+Click pattern) so I keep the list view.
- Skip "promoted" / sponsored listings unless they're an obvious strong fit.
- Flag any "Easy Apply" badges in your summary — don't click Easy Apply itself.

### Indeed

- Same general approach. Indeed listings have more job-board spam, so be stricter on signal/noise.
- Skip anything tagged "staffing agency" / "consulting firm" / generic-recruiter unless the underlying role is unambiguous.

### Wellfound / AngelList (if I point you there)

- Lean YES on Series A–C startups with the right tech stack and customer-facing framing.
- Lean NO on pre-seed / no-funding companies — too volatile for a pivot.

### Glassdoor

- Same general approach as LinkedIn. The search lands on a keyword query — scan the visible result list and evaluate each card against the rules above.
- Glassdoor mixes in aggregator/reposted listings; prefer postings that link to the company's own careers page, and be stricter on signal/noise like Indeed.
- Company rating/review snippets are visible here — a clearly low rating or active-decline tone is a soft-NO signal worth noting in your summary.

## Output format

At the end of a scan pass, give me:

```
OPENED (N tabs):
1. [Role] @ [Company] — [location/remote] — [comp if visible] — [1-sentence fit verdict]
2. ...

SKIPPED (with reasons):
- [Role] @ [Company] — [skip reason]
- ...

NOTES:
- Anything weird you noticed
- Any patterns worth me knowing about
```

Then stop and wait for me to review.

## What I'll do next

After you've opened tabs, I'll look at each one and decide whether to:
1. Save the JD to my Claude Code workspace and run `/tailor`, or
2. Close the tab if you over-called the fit.

So err slightly on the side of opening fewer, higher-confidence ones rather than spraying.

---

## JD extraction (browser-free method)

The Chrome-extension flow above is for *visually* sourcing on a desktop. But the actual JD text can be pulled with **`WebFetch` alone — no Chrome extension, no login** — which is what makes this workflow runnable from a remote-controlled desktop (e.g. driving Claude Code from an iPhone, where the Chrome extension can't run).

**Why the obvious approaches fail:**
- Logged-in LinkedIn job-view pages (`/jobs/view/{id}/`) hang on an infinite loading spinner — the description never renders to plain text.
- Company ATS domains (Ashby/Greenhouse/Lever/Workday) are blocked by the browser tool's domain allowlist.

**What works — two public LinkedIn guest endpoints (both fetchable via `WebFetch`):**

1. **Discovery (get job IDs):**
   `https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords={KW}&location={LOC}&f_WT=2&start=0`
   - Returns a list of job cards: title, company, location, and the numeric **jobId** (in each card link's href / `data-entity-urn`).
   - `f_WT=2` = Remote filter. `start=0,10,20,…` paginates. URL-encode keywords/location.
   - Use this instead of the fuzzy `/jobs/search/?keywords=` UI, which returns promoted junk and unreliable IDs.

2. **Extraction (get the full JD body):**
   `https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/{jobId}`
   - Returns the full job description as clean text. No login wall, no spinner.

**Full loop (works under remote-control / from phone):**
search endpoint → pick the real postings (dedupe against the seen-roles list above) → for each, fetch `jobPosting/{jobId}` → save to `source/job-descriptions/{company-role}.md` → run `/triage`.

The Chrome-extension path and this WebFetch path are interchangeable for getting JD text; prefer WebFetch when no desktop Chrome extension is available.
