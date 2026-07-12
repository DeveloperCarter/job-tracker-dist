> **PRE-FLIGHT (first-run check): a resume template is required.**
> Before doing anything else, check `source/template-resume/` for at least one
> `.docx`. If none exists, STOP and tell the user to add a base resume `.docx`
> there and describe it in `TEMPLATES.md`. Never tailor without a template.
---
description: Tailor a resume for a pasted job description (role-match gate → .docx)
---

You are tailoring application materials for {{CANDIDATE_NAME}}. Follow OPERATIONS.md exactly.

## Steps

1. **Read context** (only if not already loaded this session): `OPERATIONS.md`, `source/candidate-considerations.md`, `source/resume-evidence-library.yaml` (the verified evidence families and their prohibited claims), and `source/template-resume/TEMPLATES.md` to pick a template.

2. **Get the job description.**
   - **From the tracker** (e.g. "tailor posting 42" or an Inbox item): preflight `node "app/scripts/tracker.mjs" health`, then `node "app/scripts/tracker.mjs" get --id N` and read `jdText` from the JSON — no paste needed. Still **save a copy** into `source/job-descriptions/` as `company-role.md` so the `.docx` pipeline + final QA cross-check have a file to reference.
   - **From a paste**: save it into `source/job-descriptions/` as `company-role.md` (or `.txt` for plain text).
   - If neither a posting id nor a pasted JD is available, ask for one before continuing.

3. **Role-match rating** (out of 10) before generating anything. Include:
   - Strongest matches
   - Major gaps
   - Likely hiring-manager read
   - Whether the application is worth pursuing
   - Anything {{CANDIDATE_NAME}} should confirm before proceeding

   Gate: `<7.0` → pause and ask. `7.0–7.9` → proceed if attractive. `8.0+` → proceed.

4. **Pick a template** from `source/template-resume/TEMPLATES.md`. Default Template A (SE Pivot). Switch to B (Platform Engineering) if the JD is pure backend/platform with no customer-facing component. Switch to C (Healthcare) if the company is in the healthcare vertical. State the template choice + one-line reasoning before tailoring; the user can override.

5. **Build a requirement-to-evidence map before editing**, using the evidence library.
   - If the posting already has **suggested** structured requirements (seeded during triage), read them first: `node "app/scripts/tracker.mjs" requirements --id {N}`. Validate and correct that list rather than starting from scratch; never inherit a suggestion unchecked.
   - Extract / confirm the five most important hiring criteria from the JD, and assign each a `priority` (1 = highest). The **top 3 by priority** drive bullet order in step 6, so rank honestly.
   - For each criterion, retrieve the evidence families from `source/resume-evidence-library.yaml` that can credibly support it (prefer direct, distinctive evidence over keyword overlap). Record the `evidenceFamilyIds` used, the strongest confirmed evidence, where it should appear (summary / experience / skills / gap), and whether the match is `direct`, `adjacent`, or `unsupported`. Pick an `action` (keep / move / rewrite / add / gap).
   - For each `direct` requirement, set `matchTerms`: a few literal strings that will appear in the finished resume (e.g. `Kubernetes, Rancher`). The finalize QA fails if a direct requirement's terms are absent from the resume text, so keep them faithful to what you actually wrote.
   - Count a requirement as `covered` only when evidence appears in the summary or experience bullets. A skills-list mention alone does not count. Target at least 3 of 5 covered.
   - Honor every family's `prohibitedClaims` and the "Known Gaps / Use With Care" rules. Use a variant as writing guidance only; write a natural final bullet, never splice variant text verbatim.
   - **Never name a specific client / customer account** in any bullet (resume or cover letter). Describe accounts generically ("the company's two largest enterprise healthcare accounts," "a top-tier enterprise healthcare account") while keeping every metric and scope figure exactly as verified. Real names stay internal-only in `candidate-considerations.md`.
   - If you find a credible, truthful experience not yet in the library, you may append it to the library's `proposed:` list for {{CANDIDATE_NAME}} to review later; do not use a proposed family for this pass.

6. **Tailor the resume** using the `docx` skill: copy the chosen template, modify text inside, preserve formatting. The goal is that the **first third of the resume is provably about this JD**, not template-generic. Always review the summary and skills, then apply these four passes:

   a. **Requirement-driven bullet order (do this first, it is free).** Reorder the experience bullets so the **top 3 bullets answer the top 3 requirements** (by `priority` from step 5), in that order. Each of those three bullets' **first clause** must speak directly to its requirement. Reordering carries no truthfulness risk and is the single highest-leverage edit, so it must happen on every pass unless the template order already satisfies it (say so if it does).

   b. **Bullet-pool selection.** Choose which 7-8 bullets appear from the archetype's full approved pool (the template's fixed 8 **plus** the swappable pool documented per template in `TEMPLATES.md`, all grounded in `resume-evidence-library.yaml`). Swap a pool bullet in when it answers a top requirement better than a default bullet, and drop the weakest default. The template's fixed 8 is a starting point, not a ceiling. Keep 8 visible bullets, one page.

   c. **Rewrite budget tied to the map.** For every `direct` requirement whose mapped bullet does not already lead with that requirement, **rewrite the lead clause** so it does (the family's `coreClaim` and `verifiedOutcomes` stay immutable; you are re-emphasizing, not inventing). Enforce a floor by depth: `light` may make 0-1 substantive bullet edits (only when the template already proves the criteria), **`standard` requires at least 2 substantive bullet edits**, `deep` more. Count each reorder-with-lead-clause-rewrite or pool swap-with-rewrite as one substantive edit; a pure reorder with no wording change does not count. Record the **actual** count as `--rewrites` in step 2 of Bookkeeping.

   d. Move the most relevant matching technologies to the front of the skills list (no unsupported tech). Keep to one page, tightening margins / paragraph / line spacing before cutting content. Confirm the finished resume actually contains every `direct` requirement's match terms (the finalize QA enforces this).

7. **Domain translation (required before sign-off).** List every domain-specific term in the draft (e.g. healthcare, medical codes, HL7, FHIR, clinical, EHR, terminology). For **each** term, either justify it against the JD (the role genuinely calls for it) or replace it with a domain-neutral equivalent. For healthcare-vertical JDs (Template C) this is a no-op; for generalist SE/platform roles it is where the healthcare framing gets removed so the resume reads as built for this req. State the outcome ("no domain residue" or the list of terms replaced).

8. **Save** as `resumes/{{CANDIDATE_NAME}} - {Company} {Role}.docx`. For visual review, follow the OPERATIONS rule: open via `Start-Process` if {{CANDIDATE_NAME}} is at the workstation; paste the full document as plaintext in chat if he is on a remote-control / mobile session.

9. **Adversarial skim review (gate, do this before self-review).** Spawn a **fresh subagent with no tailoring context** (the `task` tool, `explore` type). Give it **only** two things: the JD text and the extracted resume text (extract the `.docx` to plaintext so it sees exactly what a parser would). Do **not** tell it the evidence map, the template choice, or your reasoning. It must answer three questions:
   1. Reading only the first third, what does this person appear to be (title / seniority / domain)?
   2. Would a recruiter for **this exact req** shortlist them in a 6-second skim? Yes / no / borderline, and why.
   3. What single change would most improve the shortlist odds?

   **Gate:** address the reviewer's top finding, or consciously dismiss it with a one-line reason, before sign-off. This replaces grading-your-own-homework; report the reviewer's answers and what you did about #3.

10. **Self-review**: give a fit rating out of 10 with strong matches, remaining gaps, anything that may overreach, the final evidence coverage out of five, the rewrite count and cover-letter strategy you chose, and one or two improvements that would raise the score if {{CANDIDATE_NAME}} confirms the experience. Note: when the resume is finalized to PDF (the `/package` Finalize step), the backend runs deterministic QA (page count, banned em/en dashes, empty bullets, and `direct`-requirement coverage from `matchTerms`). A QA `fail` shows in the drawer and should be resolved before submitting.

11. **Decide the cover-letter strategy (selective, not automatic).** Choose one and record it as `--cover-strategy` in Bookkeeping:
    - `none` — default. Skip the cover letter (most applications; a strong tailored resume plus, where possible, outreach beats a boilerplate letter).
    - `required` — the posting requires one, or a form has a mandatory cover-letter field.
    - `transition` — the role needs the SE-pivot narrative explained (title gap vs capability).
    - `motivation` — a specific, genuine reason to want this company / mission that the resume can't carry.
    - `outreach` — the letter doubles as a note to a named hiring manager / contact.

    Do not generate the cover letter until {{CANDIDATE_NAME}} signs off on the resume, and only generate one when the strategy is not `none`. After sign-off, draft the matching cover letter in `cover-letters/` following the same rules, then **ask {{CANDIDATE_NAME}} to edit at least one sentence** before it is finalized (the human-edit signal: a letter that is 100% agent-written is a tell).

## Bookkeeping (after saving the tailored resume)

The tracker **DB is the source of truth**. Preflight with `node "app/scripts/tracker.mjs" health`; if it exits non-zero, skip persistence and tell {{CANDIDATE_NAME}} "tracker DB offline — start the stack (`app/runserver.ps1`) and rerun the bookkeeping." Do **not** hand-edit the snapshots. If healthy:

1. **Upsert the posting to `Tailored-No-Submit`**, carrying the role-match analysis. `upsert` matches an existing row by company + role (e.g. one promoted from `Triaged-Tailor`) and updates it in place; otherwise it creates the row. `--jd-file` points at the JD you saved in step 2.

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" --status "Tailored-No-Submit" \
     --rating {role-match score} \
     --matches "{strongest matches}" --gaps "{major gaps}" \
     --hm "{likely hiring-manager read}" \
     --jd-file "source/job-descriptions/{company-role}.md"
   ```

2. **Capture the returned posting id** (`{"id":N,...}` on stdout), then save the requirement-to-evidence record. **Primary path: the structured requirement rows.** Write the validated top-five as a JSON array (each element `{ requirement, priority, reqType, sourceExcerpt, status: "reviewed", evidence, evidenceLocation, evidenceConfidence, action, evidenceFamilyIds, matchTerms, covered }`) and save it. Saving recomputes coverage server-side from the `covered` rows:

   ```
   node "app/scripts/tracker.mjs" set-requirements --id {N} --file "{requirements.json}"
   ```

   Then mirror a human-readable summary into the free-text strategy fields (keeps the drawer summary + depth in sync). `--coverage` should match the count of `covered` rows; `--depth` is `light`, `standard`, or `deep`; `--rewrites` is the **actual** substantive-bullet-edit count from step 6c (>= 2 at `standard`); `--cover-strategy` is the step 11 decision (`none|required|transition|motivation|outreach`):

   ```
   node "app/scripts/tracker.mjs" set-strategy --id {N} \
     --requirements-file "{temporary top-requirements file}" \
     --evidence-file "{temporary evidence-map file}" \
     --coverage {0-5} --depth {light|standard|deep} \
     --rewrites {substantive edit count} --cover-strategy {none|required|transition|motivation|outreach}
   ```

   Register the resume using a path relative to the workspace root; `--rating` is your self-review score and `--pages` the page count:

   ```
   node "app/scripts/tracker.mjs" add-resume --posting {N} \
     --path "resumes/{{CANDIDATE_NAME}} - {Company} {Role}.docx" \
     --template {A|B|C} --pages 1 --rating {self-review score}
   ```

3. **After {{CANDIDATE_NAME}} signs off** (and, when the cover-letter strategy is not `none`, you draft and he edits the cover letter), register the cover letter if one exists:

   ```
   node "app/scripts/tracker.mjs" add-cover --posting {N} \
     --path "cover-letters/{{CANDIDATE_NAME}} - {Company} {Role}.docx"
   ```

   Skip this step entirely when the cover-letter strategy is `none`.

4. **Refresh the generated snapshots** from the DB (no hand-editing):

   ```
   node "app/scripts/tracker.mjs" export-log
   node "app/scripts/tracker.mjs" seen-roles
   ```

Status transitions are recorded in `status_history` automatically. `/package` flips the status to `Applied` after the final PDFs are generated.

5. **Warm the funnel (Phase 2).** Once the application is submitted, for **8.0+ roles** run `/outreach` for this posting: it records the referral hunt (a LinkedIn 1st/2nd-degree check, logged even when the result is "none") and drafts a short note for {{CANDIDATE_NAME}} to send himself. Every application currently goes in cold; a recorded referral and a drafted note are the highest-leverage next step. This is draft-only, never a send.
