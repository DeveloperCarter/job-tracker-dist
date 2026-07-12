# Job Search Workflow — Cowork Onboarding

A Claude Code workspace for tailoring resumes and cover letters per job posting, with a strict role-match gate and per-application archiving. Designed for a candidate actively pivoting toward customer-facing engineering and pre-sales Solutions Engineering roles.

## What this agent does

1. Takes a pasted job description
2. Saves it, reads candidate context, gives an honest **role-match rating out of 10** before generating anything
3. Tailors a `.docx` resume from a template (preserving formatting, one-page when practical)
4. Optionally drafts a matching cover letter
5. After approved `.docx` files are converted to PDF via the tracker UI **Finalize** button, archives generation files and cleans up the working folders

## Workspace layout

```
CLAUDE.md                            Claude Code entry point
OPERATIONS.md                        Workflow + rules
README.md                            Folder map + quickstart
.claude/
  settings.json                      Permission allowlist
  commands/
    tailor.md                        /tailor — JD → role-match → resume
    package.md                       /package — sign-offs → PDFs → archive
source/
  candidate-considerations.md        Truthful experience, keywords, gaps
  template-resume/                   The base .docx (never edited; copied then modified)
  job-descriptions/                  Saved JDs (.md or .txt)
resumes/                             In-progress tailored .docx (cleared after /package)
cover-letters/                       In-progress CL .docx (cleared after /package)
questions/{Company}/                 Application questions + drafted answers
final/{Company}/                     Final submission PDFs (1_resume, 2_cover letter)
archive/{Company}/                   Generation files after finalization
```

## Slash commands

- **`/tailor`** — full pipeline for a new posting: save JD → context read → role-match rating → tailored `.docx` resume → open for review.
- **`/package`** — final QA, confirm the tracker UI **Finalize** button produced the PDFs in `final/{Company}/`, archive generation files, flip status to `Applied`, delete sources from `resumes/` and `cover-letters/`.

## Hard rules

- **Role-match rating out of 10 before generating documents.** Thresholds: 8.0+ proceed; 7.0–7.9 proceed if attractive; 6.0–6.9 pause and ask; <6.0 recommend skip.
- **Truthful alignment over keyword stuffing.** Never invent employers, titles, dates, metrics, certifications, or tools.
- **One-page resume when practical.** Tighten margins → paragraph spacing → line spacing **before** cutting content.
- **No AI tells.** Direct, practical, technically credible. Sound like a real person.
- **Filename prefixes:** `1_` for resume, `2_` for cover letter in `final/` and `archive/`.
- **Borderline ATS screening filters** (e.g. "5+ years X" when candidate has ~4) default to **Yes** to avoid auto-rejection; credentialed claims (degrees, certs, prior titles) stay strictly honest.

## Tools / skills required

- **`docx` skill** for Word document creation, editing, and text extraction (or Word COM via PowerShell on Windows).
- **PDF conversion** is done by the tracker UI **Finalize** button (LibreOffice on the backend), not the agent.
- File ops (Read, Write, Edit, Glob, Grep, file move/copy).
- A way to open `.docx` and `.pdf` files for visual review (`Start-Process` on Windows).

## Inputs the agent expects

- A pasted **job description** at the start of a `/tailor` run.
- Confirmation of any flagged claims that may overreach (the agent calls these out in the self-review).
- Sign-off after each generated document before moving forward.

## Outputs the agent produces

- Tailored resume `.docx` in `resumes/`
- (Optional) Tailored cover letter `.docx` in `cover-letters/`
- Application question drafts in `questions/{Company}/`
- Final PDFs in `final/{Company}/`
- Archived generation files in `archive/{Company}/`

## State to maintain across runs

- **`source/candidate-considerations.md`** is the truthful experience baseline. Update it whenever new durable facts are confirmed (e.g. a named POC win, a confirmed technology, a clarified gap). Do **not** overwrite existing entries — append.
- Memory files (in `~/.claude/projects/{...}/memory/`) capture durable preferences: career direction, positioning strengths/gaps, workflow feedback, screening-question defaults.

## Suggested first run

1. Read `CLAUDE.md`, then `OPERATIONS.md`, then `source/candidate-considerations.md`.
2. Inventory `resumes/`, `cover-letters/`, `archive/` to see what's in-flight vs. shipped.
3. Wait for the user to paste a JD, then run `/tailor`.

## Notes for the receiving agent

- The workspace is **Claude-first** via `CLAUDE.md` and `.claude/commands/`, with Codex-compatible structure preserved (the folder is still named `Codex-JobSearch` for historical continuity).
- **Default model**: Opus 4.7 for `/tailor` (judgment-heavy). Haiku 4.5 fine for `/package` (mechanical).
- **Default effort**: Medium. Bump to High for borderline role-match ratings or final QA passes.
- The candidate is actively pivoting toward pre-sales Solutions Engineering. For SE-shaped roles, lead with customer-facing technical leadership, the Mayo Clinic POC, and account-strategy participation rather than asterisking them.
