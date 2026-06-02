---
description: Triage a batch of JDs — rate each, recommend tailor/skip/borderline
---

Triage multiple job descriptions in one pass. Use this when several postings are queued up (typically from a Chrome sourcing session) and you need to decide which ones are worth the full `/tailor` cycle.

## Reading sourcing signals (gate + fit hint)

Server-side sourcing (the "Source jobs" button / `JobSourcingService`) pre-processes every listing before it reaches you, so triage spends effort only on plausible roles. Two signals come attached:

- **Pre-triage gate → `Pre-Triage-Skip` lane.** Clear non-starters never enter the Inbox. The gate is deliberately *conservative* (high precision on rejection) and rejects only when a listing is either:
  1. **off-target by function** — title outside the SE / SWE / integration / forward-deployed / implementation family (Account Executive, recruiter, nurse, etc.), or
  2. **over-leveled AND no real stack familiarity** — `10+ yrs` required *or* a Staff/Principal/Director+ title, **combined with** zero (or only incidental, alien-stack) overlap with {{CANDIDATE_NAME}}'s vocabulary.

  Years-of-experience **alone never gates** — stretch roles (senior title or high YoE but real overlap) stay in the Inbox on purpose. The gate reason is written into the posting's `notes` (e.g. *"Pre-triage gate: 12+ yrs required, little overlap with your stack (apex)"*). **Spot-check `Pre-Triage-Skip` occasionally** (`node "app/scripts/tracker.mjs" inbox` shows Inbox only; query the lane in the UI) for false negatives, and promote anything genuinely worth a look back to `Inbox`.

- **Fit hint (`Strong` / `Possible` / `Stretch` / `Weak`).** A coarse keyword-overlap prior shown on each Inbox card and stored on the posting (`fitHint`, also in `notes` as `fit: …`). It measures how much of {{CANDIDATE_NAME}}'s stack/domain vocabulary the JD touches — it is **NOT the role-match rating**. Use it only to **order your pass** and set expectations; always assign the honest 0–10 rating yourself and never inherit the band as the score. A `Strong` hint can still be a 6/10 on real fit, and a `Stretch` can be an 8/10 once the Mayo-POC / customer-facing framing is applied.

  | Band | Meaning | Rough overlap |
  |------|---------|---------------|
  | Strong | Lots of his vocabulary present | ≥6 keyword hits |
  | Possible | Solid partial overlap | 3–5 |
  | Stretch | Some overlap; reach role | 1–2 |
  | Weak | Little/none — scrutinize hard | 0 |

  Also present: **`confidence` (0–100 quality score)** — posting *quality* (recruiter spam / rate-bait / empty JD), a different axis from fit. Low-quality listings are auto-skipped to `Pre-Triage-Skip` too.

## Steps

1. **Locate the batch**. Sources, in priority order:
   - **Tracker Inbox** (JDs pasted into the web app or queued from Claude-in-Chrome). Preflight `node "app/scripts/tracker.mjs" health`; if up, run `node "app/scripts/tracker.mjs" inbox` to list `Inbox`-status postings, then `node "app/scripts/tracker.mjs" get --id N` to read each JD's full text (incl. `jdText`) straight from the DB — no paste needed. Triaging an inbox item **moves it out of Inbox** (the `upsert` in step 8 flips its status to `Triaged-*`).
   - **Batch file** on disk: `source/job-descriptions/_batch-*.md` (or a specific file the user names).
   - **Pasted JDs**: treat them as the batch in-memory.

2. **Dedupe against the log**. Read `source/applications-log.md`. For each JD in the batch, check if Company + Role (or close variant) already appears. If yes, mark as `DUPLICATE — seen on [date], status [status]` and exclude from rating. Surface the duplicate list at the end so the user can confirm.

3. **Read context** (if not already loaded): `source/candidate-considerations.md`, the SE-pivot memory, and the latest template resume's signal areas (headline experience, K8s, distributed systems, customer-facing, Mayo POC).

3. **For each JD in the batch**, produce:
   - **Role title @ Company**
   - **Location / remote**
   - **Comp (if listed)**
   - **Role-match rating out of 10** (use the OPERATIONS gate logic — don't be generous, be honest)
   - **Top 2 strongest matches** (one phrase each)
   - **Top 2 gaps** (one phrase each)
   - **Recommended action**: `TAILOR` / `BORDERLINE` / `SKIP`, with a one-phrase reason

4. **Sort the output** by rating (highest first). Group as:
   - **Tailor (8.0+)**: top priority, run `/tailor` on these first
   - **Tailor if attractive (7.0–7.9)**: judgment calls
   - **Borderline (6.0–6.9)**: pause-and-ask before tailoring; usually skip unless something is unique
   - **Skip (<6.0)**: hard gaps or function mismatch

5. **End with a summary**:
   - How many to tailor (recommend max 3 per day to keep quality up)
   - Patterns noticed across the batch (e.g., "most asking for 5+ years SE title — your Mayo POC + customer-facing framing is the strongest counter")
   - Which one to start with and why
   - List of duplicates skipped, with the original log date/status

6. **Append all new entries to `source/applications-log.md`**. One row per non-duplicate JD with today's date, company, role, location, `Source: Chrome batch` (or as specified), the assigned status (`Triaged-Tailor` for ≥7.0, `Triaged-Borderline` for 6.0–6.9, `Triaged-Skip` for <6.0), and a one-phrase note. Do **not** add duplicate rows.

7. **Refresh the Chrome sourcing prompt's seen-roles block**. Open `source/chrome-job-sourcing-prompt.md`, locate the `<!-- SEEN ROLES START -->` and `<!-- SEEN ROLES END -->` markers, and replace the content between them with a fresh list pulled from `source/applications-log.md`. Format: one bullet per row as `- {Company} — {Role} ({Status})`. Exclude pre-2026 placeholder rows only if they have no real company/role data; otherwise include everything. Keep the markers themselves intact.

8. **Mirror into the tracker DB** (dual-write — markdown above stays the source of truth). See [Tracker sync](#tracker-sync) for the preflight. If the API is up, for each **non-duplicate** JD run one `upsert`:

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" \
     --status "{Triaged-Tailor|Triaged-Borderline|Triaged-Skip}" \
     --location "{Location}" --source "{Source, e.g. Chrome batch}" \
     --rating {0-10} \
     --matches "{top 2 strongest matches}" \
     --gaps "{top 2 gaps}" \
     --notes "{one-phrase reason}"
   ```

   Skip duplicates (they already have a row). Status maps from the rating exactly like the log: ≥7.0 → `Triaged-Tailor`, 6.0–6.9 → `Triaged-Borderline`, <6.0 → `Triaged-Skip`.

## Tracker sync

The `/triage`, `/tailor`, and `/package` skills mirror their markdown bookkeeping into the local tracker DB via `app/scripts/tracker.mjs` (REST wrapper, run with `node` from the repo root). This is a **dual-write**: the markdown files remain the source of truth until the cutover is explicitly confirmed, so DB sync is best-effort and never blocks the markdown updates.

**Preflight, every time:** run `node "app/scripts/tracker.mjs" health` first.
- Exit 0 → proceed with the sync commands below.
- Non-zero (API/Postgres down) → **skip all DB sync**, finish the markdown updates normally, and tell {{CANDIDATE_NAME}}: "tracker DB offline — markdown updated, DB sync skipped."

`upsert` matches an existing row by company + role (case-insensitive); on a match it updates in place and only the fields you pass change. Status transitions are recorded in `status_history` automatically. File paths passed to `add-resume`/`add-cover` are relative to the workspace root (e.g. `resumes/...`, `final/{Company}/...`).

## Output rules

- One JD per block, separated by `---`
- Lead with the rating so the user can skim
- Be honest. Saying everything is a 7+ to be nice burns the user's time on bad-fit applications.
- If the batch contains duplicates (same role, different boards), call it out and dedupe.
- Do **not** write resumes or cover letters during triage. That's `/tailor`'s job.
