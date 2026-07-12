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

3. **Confirm the final PDFs exist.** PDF conversion now happens in the tracker UI: {{CANDIDATE_NAME}} opens the posting, **Preview**s the `.docx`, and clicks **Finalize**, which converts it (LibreOffice on the backend) into `final/{Company}/` and registers it in the DB. Do **not** run the `pdf` skill. Verify the files exist:
   - `1_{{CANDIDATE_NAME}} - {Company} {Role} Resume.pdf`
   - `2_{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.pdf`

   If either is missing, ask {{CANDIDATE_NAME}} to click **Finalize** on that doc in the app (don't convert them yourself).

4. (Already reviewed in-app via the Preview button — no separate open needed.)

5. **Archive** generation files into `archive/{Company}/`:
   - Saved job description
   - Tailored resume `.docx` (prefix `1_`)
   - Cover letter `.docx` (prefix `2_`)
   - Application question drafts, if any
   - Any draft markdown notes created during tailoring

   Do **not** move the template resume, `candidate-considerations.md`, `README.md`, or `OPERATIONS.md`.

6. **Clean up**: after verifying the archive contents, delete the tailored `.docx` files from `resumes/` and `cover-letters/`. The archive is the source of truth.

7. **Update the tracker DB (source of truth).** Preflight `node "app/scripts/tracker.mjs" health`; if it's down, skip persistence and tell {{CANDIDATE_NAME}} "tracker DB offline — start the stack (`app/runserver.ps1`) and rerun steps 7-8." Do **not** hand-edit the snapshots. If healthy, flip the posting to `Applied` and stamp today's applied date (prints `{"id":N,...}` — keep the id):

   ```
   node "app/scripts/tracker.mjs" upsert \
     --company "{Company}" --role "{Role}" \
     --status "Applied" --date-applied {YYYY-MM-DD}
   ```

   The **Finalize** button already registered the final PDFs as new doc versions (newest wins in the UI), so you normally do **not** re-add them. Only if a PDF exists on disk but isn't showing in the app (produced outside the button), register it:

   ```
   node "app/scripts/tracker.mjs" add-resume --posting {N} \
     --path "final/{Company}/1_{{CANDIDATE_NAME}} - {Company} {Role} Resume.pdf" \
     --template {A|B|C} --pages 1
   node "app/scripts/tracker.mjs" add-cover --posting {N} \
     --path "final/{Company}/2_{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.pdf"
   ```

8. **Refresh the generated snapshots** from the DB (no hand-editing):

   ```
   node "app/scripts/tracker.mjs" export-log
   node "app/scripts/tracker.mjs" seen-roles
   ```

   Status transitions are recorded in `status_history` automatically.
