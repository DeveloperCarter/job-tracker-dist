# Operations

Working instructions for the job-search workspace. Re-read the relevant section before each major pass: **resume tailoring**, **cover letter drafting**, and **final PDF packaging**.

## Session Startup

Read before tailoring anything:

- `README.md`
- `OPERATIONS.md` (this file)
- `source/candidate-considerations.md`
- `source/template-resume/TEMPLATES.md` — picks which of the three template baselines to start from (SE Pivot / Platform Engineering / Healthcare)
- The chosen template `.docx` in `source/template-resume/`

Save each pasted job description into `source/job-descriptions/`:

- `.md` when the posting has useful sections or bullets
- `.txt` for plain copied text
- Filename pattern: `company-role.md`

## Role-Match Gate

Before generating a resume or cover letter, compare the JD against the template resume and `candidate-considerations.md`, then give a rating out of 10 covering:

- Strongest matches
- Major gaps
- Likely hiring-manager read
- Whether the application is worth pursuing
- Anything {{CANDIDATE_NAME}} should confirm before proceeding

Thresholds:

| Rating | Action |
|---|---|
| 8.0+ | Strong fit. Proceed unless {{CANDIDATE_NAME}} says otherwise. |
| 7.0–7.9 | Viable stretch. Proceed if the role is attractive or strategically useful. |
| 6.0–6.9 | Significant stretch. Pause and ask {{CANDIDATE_NAME}} before generating. |
| <6.0 | Poor fit. Recommend not applying unless there is a special reason. |

Do not proceed to generation for roles below 7.0 without explicit approval.

## Tailoring Approach

- Truthful alignment, not keyword stuffing.
- Use the JD's language only when it accurately describes {{CANDIDATE_NAME}}'s experience.
- Prioritize the top third of the resume for the strongest role match.
- Strengthen existing bullets before adding new claims.
- Concise, high-signal bullets over longer explanations.
- Employer names, dates, titles, awards, metrics, and education stay accurate.
- Never invent employers, titles, dates, metrics, certifications, or tools.
- If a requirement is not met, do not imply experience — leave it out and call it out in the rating.
- Remove AI tells: generic enthusiasm, vague claims, repetitive sentence structure, inflated adjectives, phrasing that doesn't sound like a real person.
- **Never use long dashes (em dash `—` or en dash `–`) in any generated content** (resumes, cover letters, screening-question answers, etc.). Rewrite with a comma, period, colon, or parentheses instead. Regular hyphens in compound words (e.g. `post-sale`, `on-premise`) are fine. This is a hard, recurring rule: em dashes read as an AI tell and {{CANDIDATE_NAME}} does not want them anywhere in application materials.

## Resume Output Requirements

- Pick the right template baseline from `source/template-resume/TEMPLATES.md` (Template A: SE Pivot — default; Template B: Platform Engineering; Template C: Healthcare-Specialized). State the chosen template + reasoning before tailoring.
- Use the `docx` skill (Claude Code) to copy the chosen template and edit text inside the copy. Preserve original formatting and structure.
- Save tailored resumes to `resumes/` as `{{CANDIDATE_NAME}} - {Company} {Role}.docx`.
- Always review the opening summary/profile. Update it when it materially improves alignment with role type, domain, customer profile, integration/API focus, or core strengths. Keep it concise and truthful — do not force keywords if the existing version is already the strongest fit.
- Skill-match: move the most relevant explicitly-stated matching technologies to the front of the skills list. Do not add unsupported technologies.
- Keep to one page when practical. If it risks spilling to two pages, tighten in this order:
  1. Top margin
  2. Bottom margin
  3. Paragraph spacing
  4. Line spacing
  5. Overly long bullets
- Verify page count via Word automation when available.
- For visual review: if {{CANDIDATE_NAME}} is at the workstation, open the generated `.docx` (`Start-Process`). If {{CANDIDATE_NAME}} says he is on a remote-control / mobile session, **do not** open the file — instead paste the full document content as plaintext in the chat for review.
- After sign-off, move immediately to the cover letter.

## Cover Letter Requirements

- Standard industry length, format, and formality. One page unless asked otherwise.
- Professional business-letter structure: contact details, date, company/hiring team, greeting, concise opening, 2–3 focused body paragraphs, concise closing, signature.
- Write like an intelligent human. No AI indicators, no generic filler, no inflated phrasing, no buzzword polish.
- Sound like {{CANDIDATE_NAME}}: direct, practical, technically credible, grounded in real experience.
- Stay aligned with the resume, `candidate-considerations.md`, and the JD. No new unsupported claims.
- Save to `cover-letters/` as `{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.docx`. Visual review follows the same rule as the resume: open via `Start-Process` at the workstation; paste plaintext in chat if {{CANDIDATE_NAME}} is on a remote-control / mobile session.

## Application Questions

If a posting includes written questions:

- Save each question and drafted answer in `questions/{Company}/`.
- Use `.txt` for simple Q/A; `.md` when formatting or multiple sections help.
- Treat answers like cover letter content: human tone, no AI indicators, no inflated claims, no unsupported experience.
- After finalization, copy the question files into `archive/{Company}/` as well.

## Final QA Pass (before sign-off on each document)

Cross-check the document against the saved JD. This is an application-specific cleanup, not a general proofread.

- Remove residue from prior applications: stale keywords, repeated positioning, low-signal technologies, prior-company domain language.
- Remove generic, filler, redundant, weakly-supported, or off-topic material — even if it's accurate.
- Confirm the skills list is ordered by the job's explicitly stated matching technologies.
- Confirm the cover letter does not introduce technologies, responsibilities, or domain signals that aren't important to the JD.
- For each keyword or technical detail, ask: *"Would a hiring manager for this exact role care about this?"* If not, remove or demote.
- Resume and cover letter should reinforce the same strongest story without repeating sentences.
- Call out remaining gaps honestly in the fit rating; do not hide them with vague language.

## Final Submission Package

- **PDF conversion is done in the tracker UI, not by the agent.** Open the posting, **Preview** the `.docx` to review it, then click **Finalize** — the app converts the signed-off `.docx` to PDF (LibreOffice on the backend), writes it to `final/{Company}/` with the naming below, and registers it as a new doc version. The agent no longer runs the `pdf` skill for this step.
- Naming (produced by the Finalize button):
  - `1_{{CANDIDATE_NAME}} - {Company} {Role} Resume.pdf`
  - `2_{{CANDIDATE_NAME}} - {Company} {Role} Cover Letter.pdf`
- The agent's remaining packaging role is the bookkeeping below (archive, log, seen-roles refresh) plus flipping the card to `Applied`. The Finalize button does **not** change status or touch markdown.
- Keep the source `.docx` files in `resumes/` and `cover-letters/` — do not move them.
- Verify PDFs created successfully. If {{CANDIDATE_NAME}} is at the workstation, open for visual review; if on a remote-control / mobile session, skip opening and confirm the file paths in chat.
- Archive generation files into `archive/{Company}/` using `1_` / `2_` prefixes for the resume and cover letter `.docx`:
  - Saved JD
  - Tailored resume `.docx`
  - Cover letter `.docx`
  - Draft notes or markdown, if any
  - Application question drafts, if any
- After the archive is verified, **delete** the tailored `.docx` files from `resumes/` and `cover-letters/`. The archive is the source of truth — keeping the loose source copies clutters the working folders.
- Do not archive or move reusable sources: template resume, `candidate-considerations.md`, `README.md`, `OPERATIONS.md`.

## Tracker App (local web UI)

A local-first web app in `app/` (Spring Boot + React + Postgres) tracks every posting, its status, JD text, role-match notes, and links to the generated docs. It does **not** generate documents — tailoring stays in Claude Code. The markdown files (`source/applications-log.md`, etc.) remain the source of truth; the app is a dual-write mirror until cutover is confirmed.

- **Run it:** `app/runserver.ps1` (double-click or `-Action start`). Interactive menu, or `-Action start|stop|restart|status -Scope full|backend|frontend|db`. Backend `:8080`, frontend `:5173`, Postgres in Docker `:5433`. The in-app **Shut down** button calls the same script.
- **Inbox intake:** the app's **Add JD** button (and Claude-in-Chrome) drop JDs into the `Inbox` lane. In Claude Code, "triage the inbox" / "tailor posting N" reads the JD from the DB via `app/scripts/tracker.mjs` — no re-paste, no Anthropic API (Claude Code is the compute).
- **Source jobs button:** runs the LinkedIn guest-endpoint sweep **server-side** (`JobSourcingService`, no Chrome / no agent / works under remote-control). For each role it fetches cards + JD bodies, dedupes by stable `external_id` (then company+role), and applies a cheap deterministic pre-pass before anything lands:
  - **Quality score** (`confidence` 0–100) — penalizes recruiter/staffing names, pay-rate-bait titles, promotional pipes, and empty JDs. Low scores auto-route to `Pre-Triage-Skip`.
  - **Pre-triage gate** — keeps obvious non-starters out of the Inbox so LLM triage never burns effort on junk. Conservative: rejects only on **off-target function** (non-SE/eng title) or **over-leveled AND no real stack overlap** (`10+ yrs` *or* Staff/Principal+ title combined with zero/incidental-alien overlap). **Years alone never reject** — stretch roles stay. Gated rows go to `Pre-Triage-Skip` with the reason in `notes`; spot-check that lane for false negatives.
  - **Fit hint** (`Strong`/`Possible`/`Stretch`/`Weak`) — a keyword-overlap *prior* on each kept posting (shown as an Inbox badge, stored in `fit_hint`). A skim aid and triage prior **only — not the role-match rating.** See `/triage` for how to weigh it.

  Survivors land in `Inbox`; the keyword lists live in `JobSourcingService` and are sourced from `candidate-considerations.md`.
- **Dual-write sync:** `/triage`, `/tailor`, `/package` mirror their markdown bookkeeping into the DB via `tracker.mjs` (health-gated; markdown-only fallback if the API is down). See those skills for exact commands.

## Review Standard

After generating a tailored resume, give an objective fit rating out of 10 from a seasoned hiring manager's perspective. Mention:

- Strong matches
- Remaining gaps
- Any wording that may overreach
- One or two improvements that would raise the score if {{CANDIDATE_NAME}} confirms the experience is real

## {{CANDIDATE_NAME}}'s Reusable Positioning

Confirmed strengths (use when the JD genuinely calls for them):

- Enterprise integrations
- Customer-facing technical discovery
- Ambiguous implementation environments
- REST/SOAP APIs, OAuth, pagination, rate-limit-aware design
- Production rollout and support
- Cloud migrations
- Reusable automation
- Senior stakeholder communication (CTO/CEO)
- Healthcare enterprise customer experience
- Post-sale discovery and requirements gathering
- High-value (6–7 figure) enterprise account continuity
- AI-assisted development workflows
- Product/technical demos and account-strategy participation

Recurring gaps — do **not** overstate:

- Direct MarTech platform implementation (Braze, SFMC, AEP, Contentful, AEM)
- DAM / CDP / ESP platform ownership
- AI-native content operations
- Marketing automation, ecommerce, analytics, mobile/SDK ownership
- Salesforce Marketing Cloud ({{CANDIDATE_NAME}}'s Salesforce use is customer tracking, opportunities, credential storage)
- Direct ownership of competitive presales wins or Proof of Value plans (participation is real; ownership is not unless confirmed)
- Network engineering ownership (practical implementation-side networking — ports, protocols, TLS, firewalls — is real)
- Formal data engineering / data warehouse ownership (ETL-adjacent support work is real)
