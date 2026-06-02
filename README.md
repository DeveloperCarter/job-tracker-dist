# Job Search Tracker

A personal, self-hosted job-search tracker with an AI-assisted resume/cover-letter
tailoring workflow. You run it on your own Windows PC with Docker; an AI coding
agent (Claude Code, Codex CLI, …) drives the tailoring.

> Using an AI agent to set this up? Point it at **AGENTS.md** — it has the full
> operating guide.

---

## Quick start (Windows)

**Easiest — one line, nothing preinstalled.** Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/DeveloperCarter/job-tracker-dist/main/install.ps1 | iex
```

This installs Git + Git LFS if you don't have them, downloads the app, and starts
it. (Git LFS is required — the app images are stored with it.) When it finishes,
open **http://localhost:8088**.

**Already have Git + Git LFS?** Clone and bootstrap manually instead:

```powershell
git clone https://github.com/DeveloperCarter/job-tracker-dist
cd job-tracker-dist
./bootstrap.ps1
```

`bootstrap.ps1` checks for prerequisites (Docker + a small toolchain), shows you
exactly what it would install, asks for confirmation, installs via `winget`,
loads the app images, and starts everything. Then open **http://localhost:8088**.

That's it for running the app. To actually *tailor* resumes, do the two setup
steps below.

### Before your first tailoring pass

- **Add a resume template.** This package ships with none. Drop a base resume
  `.docx` into `workspace/source/template-resume/` and note it in that folder's
  `TEMPLATES.md`. (Tailoring is blocked until you do.)
- **Fill in `workspace/source/candidate-considerations.md`** with your real
  experience. The agent tailors *from this* — accurate in, accurate out.

---

## Day-to-day

- **Open the app:** http://localhost:8088
- **Stop it:** `./teardown.ps1` (or `docker compose down`) — your data is kept.
- **Start it again:** `./bootstrap.ps1` (or `docker compose up -d`).
- **Add a job:** "Add JD" in the app, or let the agent run `/triage` and `/tailor`.

## Updating

This deploy folder is a clone of the published **distribution repo** (compiled
images + compose + scripts — no source). To pull the latest build and redeploy:

```powershell
./update.ps1
```

It runs `git pull`, reloads the refreshed images, and recreates the containers —
your tracked data is preserved (the backend migrates the database automatically
if the new build changed the schema). You can also update + start in one step:

```powershell
./bootstrap.ps1 -Update
```

If this folder isn't a git checkout, update manually: drop in the newer
`images/*.tar` + `docker-compose.yml`, then run `./bootstrap.ps1` again.

## Stopping & removing

```powershell
./teardown.ps1            # stop the app, keep all data
./teardown.ps1 -Volumes   # also delete tracked data (asks first)
./teardown.ps1 -Images    # also remove the app images (frees disk)
```

Your tracked data lives in a Docker volume (`jobsearch-pgdata`); your documents
live in the `workspace/` folder next to this README.

---

## Tailscale (optional) — reach the tracker from your phone or iPad

**What it is.** [Tailscale](https://tailscale.com) is a free, secure private
network (a "VPN", but the easy kind). You install it on your PC and on your phone,
sign in to the same account on both, and they can reach each other directly — as
if they were on the same Wi-Fi — no matter where you are. Nothing is exposed to
the public internet; only your own devices can connect.

**Why you'd want it here.** This app runs only on your PC. With Tailscale you can
open the board on your phone or iPad (great for triaging on the couch) by visiting
your PC's Tailscale name, without port-forwarding or any security risk.

**Setup (5 minutes):**
1. Let `bootstrap.ps1` install Tailscale when it offers (or get it from
   https://tailscale.com/download), then run it and **sign in** (Google/Microsoft/
   email — free "Personal" plan is plenty).
2. Install the **Tailscale app on your phone/iPad** and sign in to the **same**
   account. Toggle it on.
3. On your PC, find its Tailscale name: run `tailscale status` (or look in the
   Tailscale menu — it's usually like `your-pc.tailXXXX.ts.net`).
4. On your phone's browser, go to **`http://your-pc.tailXXXX.ts.net:8088`**.

That's it — the board loads on your phone. (Optional: `tailscale serve` can put it
on clean HTTPS without the `:8088`; see Tailscale's docs.)

---

## Troubleshooting

- **"Docker is not running":** open Docker Desktop and wait for it to start. A
  brand-new install usually needs a Windows **reboot** (and WSL2 enabled).
- **Port already in use (8080 or 8088):** something else on your PC is using that
  port (e.g. another app, or a separate development copy of this tracker). This
  stack runs under its own isolated project name (`jobsearch-tracker`) so it never
  fights another copy over container names — but host ports are still shared. Edit
  the `ports:` lines in `docker-compose.yml` (e.g. `"8089:80"`) and re-run.
- **Preview/download is blank:** make sure your AI agent is working inside the
  `workspace/` folder (that's the folder shared with the app).
- **Reset everything (deletes tracked data):** `docker compose down -v`.

See **AGENTS.md** for the architecture and the full workflow reference.
