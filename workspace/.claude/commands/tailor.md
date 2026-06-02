> **PRE-FLIGHT (first-run check): a resume template is required.**
> Before doing anything else, check `source/template-resume/` for at least one
> `.docx`. If none exists, STOP and tell the user to add a base resume `.docx`
> there and describe it in `TEMPLATES.md`. Never tailor without a template.
---
description: Tailor a resume for a pasted job description (role-match gate → .docx)
---

You are tailoring application materials for {{CANDIDATE_NAME}}. Follow OPERATIONS.md exactly.

## Steps

1. **Read context** (only if not already loaded this session): `OPERATIONS.md`, `source/candidate-considerations.md`, and `source/template-resume/TEMPLATES.md` to pick a template.

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

5. **Tailor the resume** using the `docx` skill: copy the chosen template, modify text inside, preserve formatting. Light per-role pass — summary tweak + skills reorder + at most one bullet swap. The template already carries most of the per-archetype framing. Keep to one page — tighten margins/paragraph/line spacing before cutting content.

6. **Save** as `resumes/{{CANDIDATE_NAME}} - {Company} {Role}.docx` and open it for {{CANDIDATE_NAME}}'s visual review (`Start-Process`).

7. **Self-review**: give a fit rating out of 10 with strong matches, remaining gaps, anything that may overreach, and one or two improvements that would raise the score if {{CANDIDATE_NAME}} confirms the experience.

Do not generate the cover letter until {{CANDIDATE_NAME}} signs off on the resume. After sign-off, draft the matching cover letter in `cover-letters/` following the same rules.

## Log update

After saving the tailored resume:

1. Update `source/applications-log.md`:
   - If the company+role already has a row (e.g. promoted from `Triaged-Tailor`), update its status to `Tailored-No-Submit`.
   - If it's not in the log yet (direct paste, not from triage), append a new row with today's date, source `direct`, status `Tailored-No-Submit`.
   - `/package` will flip the status to `Applied` after final PDFs are generated.

2. **Refresh the Chrome sourcing prompt's seen-roles block**. Open `source/chrome-job-sourcing-prompt.md`, locate the `<!-- SEEN ROLES START -->` and `<!-- SEEN ROLES END -->` markers, and replace the content between them with a fresh list from `source/applications-log.md`. Format: one bullet per row as `- {Company} — {Role} ({Status})`. Keep the markers intact.

3. **Mirror into the tracker DB** (dual-write — markdown above stays the source of truth). Preflight with `node "app/scripts/tracker.mjs" health`; if it exits non-zero, skip DB sync, keep the markdown updates, and tell {{CANDIDATE_NAME}} "tracker DB offline — markdown updated, DB sync skipped." If healthy:

   a. Upsert the posting to `Tailored-No-Submit`, carrying the role-match analysis. `upsert` matches an existing row by company + role (e.g. one promoted from `Triaged-Tailor`) and updates it in place; otherwise it creates the row. `--jd-file` points at the JD you saved in step 2.

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" --status "Tailored-No-Submit" \
     --rating {role-match score} \
     --matches "{strongest matches}" --gaps "{major gaps}" \
     --hm "{likely hiring-manager read}" \
     --jd-file "source/job-descriptions/{company-role}.md"
   ```

   b. Capture the returned posting id (`{"id":N,...}` on stdout), then register the resume. The path is relative to the workspace root; `--rating` is your self-review score, `--pages` the page count:

   ```
   node "app/scripts/tracker.mjs" add-resume --posting {N} \
     --path "resumes/{{CANDIDATE_NAME}} - {Company} {Role}.docx" \
     --template {A|B|C} --pages 1 --rating {self-review score}
   ```

   c. **After {{CANDIDATE_NAME}} signs off and you draft the cover letter**, register it too:

   ```
   node "app/scripts/tracker.mjs" add-cover --posting {N} \
     --path "cover-letters/{{CANDIDATE_NAME}} - {Company} {Role}.docx"
   ```

   File paths are relative to the workspace root. Status transitions are recorded in `status_history` automatically.
