---
description: Triage a batch of JDs — rate each, recommend tailor/skip/borderline
---

Triage multiple job descriptions in one pass. Use this when several postings are queued up (typically from a Chrome sourcing session) and you need to decide which ones are worth the full `/tailor` cycle.

The tracker **DB is the source of truth**. Dedupe and bookkeeping go through `app/scripts/tracker.mjs` (health-gated); `source/applications-log.md` and the Chrome prompt's seen-roles block are regenerated snapshots, never hand-edited.

## Sourcing signals (skim aid only)

Server-side sourcing attaches a `fitHint` (`Strong`/`Possible`/`Stretch`/`Weak`) and a `confidence` (0-100 quality) score to each Inbox posting, and routes obvious non-starters to `Pre-Triage-Skip`. Full definitions of the gate, fit hint, and confidence live in `OPERATIONS.md` → Tracker App. Use the fit hint **only to order your pass** — it is NOT the role-match rating. Assign the honest 0-10 score yourself: a `Strong` hint can still be a 6/10, and a `Stretch` an 8/10 once the Mayo-POC / customer-facing framing is applied. Spot-check the `Pre-Triage-Skip` lane occasionally for false negatives and promote anything worth a look back to `Inbox`.

## Steps

1. **Locate the batch** (priority order):
   - **Tracker Inbox**: `node "app/scripts/tracker.mjs" health`, then `inbox` to list `Inbox` postings, then `get --id N` to read each JD (incl. `jdText`) straight from the DB. Triaging an item moves it out of Inbox (the `upsert` in step 7 flips its status).
   - **Batch file**: `source/job-descriptions/_batch-*.md` (or a file the user names).
   - **Pasted JDs**: treat them as the batch in-memory.

2. **Dedupe via the DB.** For each JD run `node "app/scripts/tracker.mjs" find --company "X" --role "Y"`. If it returns a match, mark `DUPLICATE — #id, status [status]` and exclude it from rating. (If the API is down, fall back to scanning `source/applications-log.md`.) Surface the duplicate list at the end so the user can confirm.

3. **Read context** (if not already loaded): `source/candidate-considerations.md`, the SE-pivot memory, and the template resume's signal areas (headline experience, K8s, distributed systems, customer-facing, Mayo POC).

4. **For each JD, produce:**
   - **Role title @ Company**
   - **Location / remote**
   - **Comp (if listed)**
   - **Role-match rating out of 10** (OPERATIONS gate logic — honest, not generous)
   - **Top 2 strongest matches** (one phrase each)
   - **Top 2 gaps** (one phrase each)
   - **Knockouts** — extract the hard ATS gates the resume cannot argue around: degree required (capture the level, and whether an "or equivalent experience" clause appears), a hard years-of-experience gate (a firm minimum, e.g. "8+ years required"; stretch language like "preferred" is not a knockout), residency / onsite / work-authorization requirement, security clearance, mandatory certifications. Write "none stated" when the JD is silent, don't infer gates that aren't there.
   - **Recommended action**: `TAILOR` / `BORDERLINE` / `SKIP`, with a one-phrase reason.

   **Knockout cap:** when a **hard** knockout has no equivalency clause and {{CANDIDATE_NAME}} cannot meet it (a degree he lacks with no "or equivalent" language, a years gate well above his experience, a clearance he does not hold, a residency he cannot satisfy), cap the recommendation at `BORDERLINE` and say why, even if the fit score is otherwise 8.0+. This is honest triage, not pessimism: it is the answer to several of the current auto-rejections. A years gate alone never forces `SKIP` (stretch roles stay), but it does inform the cap.

5. **Sort the output by rating (highest first)** and group: Tailor (8.0+); Tailor if attractive (7.0-7.9); Borderline (6.0-6.9, or knockout-capped, pause-and-ask before tailoring); Skip (<6.0).

6. **End with a summary**: how many to tailor (recommend max 3/day to keep quality up); patterns across the batch; which one to start with and why; duplicates skipped (with their id/status).

7. **Write results to the DB** (the system of record; health-gated). For each **non-duplicate** JD, one `upsert`:

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" \
     --status "{Triaged-Tailor|Triaged-Borderline|Triaged-Skip}" \
     --location "{Location}" --source "{Source, e.g. Chrome batch}" \
     --rating {0-10} --matches "{top 2 matches}" --gaps "{top 2 gaps}" --notes "{one-phrase reason}"
   ```

   Status maps from the rating: >=7.0 -> `Triaged-Tailor`, 6.0-6.9 -> `Triaged-Borderline`, <6.0 -> `Triaged-Skip`. Skip duplicates (they already have a row).

8. **Seed preliminary top-five requirements** (only for `Triaged-Tailor` postings; you already read the full JD). Extract the five most important hiring criteria and write them as **suggested, unreviewed** structured requirement rows. These are placeholders to speed up `/tailor`, never authoritative: `status` is `suggested`, do **not** set `covered`, `evidenceConfidence`, or `matchTerms` (that is `/tailor`'s job after it validates the list). Capture `priority` (1=highest), `reqType` (`required`/`preferred`/`responsibility`/`inferred`), and a short `sourceExcerpt`. Write a JSON array to a temp file and save it:

   ```
   node "app/scripts/tracker.mjs" set-requirements --id {N} --file "{temp requirements.json}"
   ```

   Example element: `{ "requirement": "Customer-facing technical discovery", "priority": 1, "reqType": "required", "sourceExcerpt": "run discovery and scoping with customers", "status": "suggested" }`. Skip this for Borderline/Skip postings.

9. **Record extracted knockouts** (for every non-duplicate posting you rated, since knockouts inform the cap even on Borderline/Skip). Write only the fields the JD actually states; omit the rest. `--degree-equivalency true` records that an "or equivalent experience" clause is present:

   ```
   node "app/scripts/tracker.mjs" set-knockouts --id {N} \
     --degree "Bachelor's" --degree-equivalency true \
     --years 5 --residency "US onsite" --clearance "none" --certifications "none"
   ```

   If the JD states no knockouts at all, skip the call (leaving the fields null = "none stated").

10. **Refresh the generated snapshots** (one deterministic call each, no hand-editing):

   ```
   node "app/scripts/tracker.mjs" export-log
   node "app/scripts/tracker.mjs" seen-roles
   ```

   These rebuild `source/applications-log.md` and the Chrome prompt's seen-roles block from the DB.

## Tracker sync

`/triage`, `/tailor`, and `/package` use `app/scripts/tracker.mjs` (REST wrapper, run with `node` from the repo root) against the local tracker DB — **the source of truth**.

**Preflight, every time:** `node "app/scripts/tracker.mjs" health`.
- Exit 0 -> proceed with the commands above.
- Non-zero (API/Postgres down) -> DB writes and snapshot regen are skipped, and dedupe falls back to reading `source/applications-log.md`. Tell {{CANDIDATE_NAME}}: "tracker DB offline — triage results not persisted; start the stack (`app/runserver.ps1`) and rerun steps 7-9." Do **not** hand-edit the snapshots.

`upsert` matches an existing row by company + role (case-insensitive) and updates in place; only passed fields change. Status transitions are recorded in `status_history` automatically.

## Output rules

- One JD per block, separated by `---`.
- Lead with the rating so the user can skim.
- Be honest. Saying everything is a 7+ to be nice burns the user's time on bad-fit applications.
- If the batch contains duplicates (same role, different boards), call it out and dedupe.
- Do **not** write resumes or cover letters during triage. That's `/tailor`'s job.
