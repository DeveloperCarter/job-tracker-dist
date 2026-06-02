---
description: Convert signed-off resume + cover letter .docx to final PDFs and archive
---

Final submission packaging for the company the user names. Follow OPERATIONS.md "Final Submission Package".

## Steps

1. **Identify the files**: the signed-off `.docx` resume in `resumes/` and cover letter in `cover-letters/` for `{Company}`. If ambiguous, ask which exact files.

2. **Final QA cross-check** against the saved job description in `source/job-descriptions/`. Look specifically for:
   - Residue from prior applications (stale keywords, irrelevant tech, prior-company positioning)
   - Filler, generic enthusiasm, AI tells
   - Skills list ordered by this job's explicitly stated matching technologies
   - Cover letter not introducing tech/responsibilities outside the JD
   - Any remaining gaps called out honestly in the fit rating, not hidden

   Report findings. If non-trivial changes are needed, pause for approval before editing.

3. **Create PDFs** using the `pdf` skill in `final/{Company}/`:
   - `1_{{CANDIDATE_NAME}} - {Company} {Role} Resume.pdf`
   - `2_{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.pdf`

4. **Open** the final PDFs for visual review (`Start-Process`).

5. **Archive** generation files into `archive/{Company}/`:
   - Saved job description
   - Tailored resume `.docx` (prefix `1_`)
   - Cover letter `.docx` (prefix `2_`)
   - Application question drafts, if any
   - Any draft markdown notes created during tailoring

   Do **not** move the template resume, `candidate-considerations.md`, `README.md`, or `OPERATIONS.md`.

6. **Clean up**: after verifying the archive contents, delete the tailored `.docx` files from `resumes/` and `cover-letters/`. The archive is the source of truth.

7. **Update the log**: in `source/applications-log.md`, flip the matching company+role row's status to `Applied`. If no matching row exists, append one with today's date and source `direct`.

8. **Refresh the Chrome sourcing prompt's seen-roles block**. Open `source/chrome-job-sourcing-prompt.md`, locate the `<!-- SEEN ROLES START -->` and `<!-- SEEN ROLES END -->` markers, and replace the content between them with a fresh list from `source/applications-log.md`. Format: one bullet per row as `- {Company} — {Role} ({Status})`. Keep the markers intact.

9. **Mirror into the tracker DB** (dual-write — markdown above stays the source of truth). Preflight with `node "app/scripts/tracker.mjs" health`; if it exits non-zero, skip DB sync, keep the markdown updates, and tell {{CANDIDATE_NAME}} "tracker DB offline — markdown updated, DB sync skipped." If healthy:

   a. Flip the posting to `Applied` and stamp today's applied date in one call (it prints `{"id":N,...}` — keep that id for step b):

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" \
     --status "Applied" --date-applied {YYYY-MM-DD}
   ```

   b. Step 6 deletes the working `.docx` files, so register the **final PDFs** as the current documents (paths relative to the workspace root) — this is what the tracker UI previews. Use the posting id from step a:

   ```
   node "app/scripts/tracker.mjs" add-resume --posting {N} \
     --path "final/{Company}/1_{{CANDIDATE_NAME}} - {Company} {Role} Resume.pdf" \
     --template {A|B|C} --pages 1
   node "app/scripts/tracker.mjs" add-cover --posting {N} \
     --path "final/{Company}/2_{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.pdf"
   ```

   These create new resume/cover-letter versions (newest wins in the UI) pointing at the archived final PDFs. Status transitions are recorded in `status_history` automatically.
