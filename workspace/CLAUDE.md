# CLAUDE.md

This is {{CANDIDATE_NAME}}'s job-search workspace. The full workflow and rules live in [OPERATIONS.md](OPERATIONS.md); this file tells you how to operate inside it.

## Before any tailoring pass

Read in this order:

1. [OPERATIONS.md](OPERATIONS.md) — workflow, role-match gate, output requirements, QA pass
2. [source/candidate-considerations.md](source/candidate-considerations.md) — truthful experience, keywords, known gaps
3. [source/template-resume/TEMPLATES.md](source/template-resume/TEMPLATES.md) — picks which of the three template baselines to start from (SE Pivot / Platform Engineering / Healthcare)
4. The chosen template `.docx` in [source/template-resume/](source/template-resume/) — the layout/content baseline

Re-read OPERATIONS.md before each major pass (resume, cover letter, final package). The rules are strict and easy to drift from.

## Tools to use

- **Word documents (`.docx`)** — use the `docx` skill. Do not write ad-hoc python-docx scripts. The skill handles copying templates, editing in place, preserving formatting, tightening spacing/margins for one-page fit, and page-count verification.
- **PDFs** — use the `pdf` skill for the final submission conversion.
- **Opening files for visual review** — use `Start-Process` via PowerShell so Word / the default PDF viewer launches. Ask before opening if a previous open prompt was denied. **If {{CANDIDATE_NAME}} says he is on a remote-control / mobile session, do not open files** — paste the full document content as plaintext in chat for review instead.

## Hard rules (full version in OPERATIONS.md)

- Always provide a role-match rating out of 10 **before** generating documents. Do not proceed below 7.0 without explicit approval.
- Truthful alignment over keyword stuffing. Never invent employers, titles, dates, metrics, certifications, or tools.
- One-page resume when practical. Tighten margins/spacing before cutting content.
- No AI tells: generic enthusiasm, vague claims, inflated adjectives, repetitive structure. Sound like {{CANDIDATE_NAME}} — direct, practical, technically credible.
- Filename prefixes for final/archive: `1_` resume, `2_` cover letter.

## Slash commands

- `/triage` — rate a batch of JDs (from the tracker Inbox, a batch file, or paste) and recommend tailor/skip/borderline
- `/tailor` — full pipeline for a new posting (get JD → role-match → tailored `.docx` resume)
- `/package` — convert signed-off `.docx` resume + cover letter to final PDFs and archive

## Tracker app (`app/`)

Local web app (Spring Boot + React + Postgres) for tracking postings/status/docs. Tailoring stays here in Claude Code; markdown stays the source of truth (dual-write mirror). Full details in [OPERATIONS.md](OPERATIONS.md#tracker-app-local-web-ui).

- **Run/stop:** `app/runserver.ps1` (menu, or `-Action start|stop|status -Scope full|backend|frontend|db`).
- **Inbox flow:** JDs added in the UI (or via Claude-in-Chrome) land in the `Inbox` lane. "Triage the inbox" / "tailor posting N" reads the JD from the DB via `app/scripts/tracker.mjs get --id N` — no paste, no API.
- Skills sync to the DB best-effort via `tracker.mjs` (health-gated). If the API is down, they keep the markdown updates and say so.

## Folder map

```
source/job-descriptions/   pasted JDs (.md or .txt, named company-role.md)
source/template-resume/    the source .docx (do not edit; copy then modify)
source/candidate-considerations.md
resumes/                   tailored .docx resumes
cover-letters/             tailored .docx cover letters
questions/{Company}/       application questions + drafted answers
final/{Company}/           final PDFs (1_..., 2_...)
archive/{Company}/         post-finalization generation files
```
