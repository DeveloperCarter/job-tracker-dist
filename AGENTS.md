# AGENTS.md — operating guide for the Job Search Tracker

This file orients an AI coding agent (Claude Code, Codex CLI, etc.) **and** a
human. Read it fully before doing anything. If a human is driving, the
**README.md** quickstart is the friendlier path.

---

## What this is

A personal job-search tracker with an AI-assisted tailoring workflow:

- A **web app** (Kanban-style board) that tracks postings through stages
  (Inbox → Triaged → Tailored → Applied → …), previews/downloads tailored
  resumes & cover letters, and can source roles from LinkedIn.
- A **workflow** driven by you (the agent) via three skills — `/triage`,
  `/tailor`, `/package` — that read job descriptions, rate fit, and produce
  tailored `.docx`/`.pdf` documents.

The app ships as **prebuilt Docker images** (no application source). You operate
the *workflow and content*; you cannot modify the app internals — by design.

---

## Architecture (read this — it explains the one non-obvious thing)

```
   Your machine (host)                      Docker
  ┌────────────────────┐        ┌─────────────────────────────────┐
  │  AI agent (you)     │        │  web (nginx)  :8088  ← browser   │
  │  + the skills       │        │     │  /api → proxy              │
  │  write .docx/.pdf   │        │  backend (Spring Boot) :8080     │
  │  into ./workspace   │◄──────►│     reads/serves ./workspace     │
  └────────────────────┘  bind  │  postgres (named volume)         │
                          mount  └─────────────────────────────────┘
```

**The critical detail:** the `workspace/` folder is **bind-mounted** into the
backend container. You (the agent) run on the host and write generated documents
into `workspace/resumes/`, `workspace/final/`, etc. The backend serves those same
files to the web UI. That shared folder is why document preview/download works.
**Always run the agent with `workspace/` as your project root, and keep generated
files inside it.**

- Browser → `http://localhost:8088` (or `http://<tailscale-name>:8088` from a phone).
- Host workflow CLI (`workspace/app/scripts/tracker.mjs`) → talks to the backend
  on `http://localhost:8080` (the default; no config needed). **If port 8080 was
  busy at setup**, bootstrap chose another port (it prints it, and records both in
  the `.env` file next to `docker-compose.yml` as `BACKEND_PORT`). In that case set
  `TRACKER_API` to match before running the CLI, e.g.
  `$env:TRACKER_API = 'http://localhost:<BACKEND_PORT>'`.

---

## First-time setup

1. **Bootstrap (installs prerequisites, with your consent, then starts the app):**
   ```powershell
   ./bootstrap.ps1
   ```
   It checks what's missing and asks before installing anything (see "Consent &
   installs"). When it finishes, the app is at http://localhost:8088.

2. **Add a resume template (REQUIRED before tailoring).** The handoff ships with
   **no** resume templates. Put at least one base resume `.docx` into
   `workspace/source/template-resume/` and describe it in that folder's
   `TEMPLATES.md`. The `/tailor` skill will refuse to run until one exists.

3. **Fill in `workspace/source/candidate-considerations.md`.** This is the
   truthful experience the agent tailors from. Quality in = quality out.

4. **(Optional) integrations.** See `secrets/secrets.properties.template`.
   Everything works without it.

---

## Consent & installs (what bootstrap.ps1 may install)

Via `winget`, only after showing you the list and getting a "yes":

- **Docker Desktop** — runs the app. (Needs WSL2 + virtualization; may require a
  one-time reboot the script cannot do for you — it will tell you.)
- **Git, Node LTS, Python, pandoc, LibreOffice** — the host-side toolchain the
  tailoring skills use (LibreOffice converts `.docx` → `.pdf`; Microsoft Word is
  NOT required).
- **Tailscale** — *optional*, only if you opt in (see README "Tailscale").

The script never installs silently and never elevates without telling you why.

---

## Running the app

- Start:  `docker compose up -d`   (bootstrap does this)
- Stop:   `docker compose down`    (your data persists in the `jobsearch-pgdata` volume)
- Logs:   `docker compose logs -f backend`
- The in-app "Shut down" button is **disabled in this packaged build** — use
  `docker compose down`.

---

## The workflow skills

Run these from `workspace/` as your project root. They are defined in
`workspace/.claude/commands/`. Full rules live in `workspace/OPERATIONS.md`.

- **/triage** — rate a batch of job descriptions 0–10, recommend tailor/skip.
- **/tailor** — for one posting: save the JD, rate fit, produce a tailored
  one-page resume `.docx` (and, on request, a cover letter).
- **/package** — convert the signed-off `.docx` to final PDFs and archive.

These need the **docx** and **pdf** skills (from Anthropic's skills plugin) for
document conversion, plus the host toolchain above. The DB bridge is
`workspace/app/scripts/tracker.mjs` (`node app/scripts/tracker.mjs health`).

> **LinkedIn sourcing warning.** The app's "Source jobs" button scrapes LinkedIn
> guest endpoints. That is gray-area under LinkedIn's ToS and can get your IP
> rate-limited or blocked. Default limits are conservative; use sparingly, or
> just add postings manually with "Add JD".

---

## What you may and may not change

- ✅ Edit workflow content: `candidate-considerations.md`, the skills in
  `.claude/commands/`, templates, `OPERATIONS.md`, your resumes/JDs/logs.
- ✅ Edit configuration: `docker-compose.yml`, `secrets/`, ports.
- ❌ You do **not** have the app's source code (backend/frontend). It runs as
  compiled images. To change app behavior you'd need source from the author.

---

## Troubleshooting

- **App won't load:** `docker compose ps` — is `web` and `backend` up? Check
  `docker compose logs backend`. Postgres healthy?
- **Preview/download shows nothing:** the file isn't under `workspace/`, or you
  ran the agent in a different folder than the one bind-mounted. Confirm the path
  the DB stored exists under `workspace/`.
- **Port 8088/8080 in use:** edit the `ports:` in `docker-compose.yml`.
- **Docker not ready:** Docker Desktop must be running (and WSL2 enabled). A
  fresh install often needs a reboot.
