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

**Knockouts.** At triage, extract the hard ATS gates as structured posting fields (`tracker.mjs set-knockouts`): degree required and whether an "or equivalent experience" clause appears, a hard years-of-experience gate, residency / onsite / work-authorization, security clearance, mandatory certifications. When a hard knockout has no equivalency clause and {{CANDIDATE_NAME}} cannot meet it, cap the recommendation at Borderline regardless of the fit score, and say why. A years gate alone never forces a Skip (stretch roles stay), but it informs the cap.

## Tailoring Approach

- Truthful alignment, not keyword stuffing.
- Use the JD's language only when it accurately describes {{CANDIDATE_NAME}}'s experience.
- Prioritize the top third of the resume for the strongest role match.
- **Requirement-driven bullet order.** After the requirement-to-evidence map is validated, order the experience bullets so the top 3 bullets answer the top 3 requirements (by priority), and each of those bullets' first clause speaks to its requirement. Reordering is free (no truthfulness risk) and is the highest-leverage edit; do it every pass unless the template order already satisfies it.
- **Bullet-pool selection.** Choose the 7-8 visible bullets from the archetype's full approved pool (the template's fixed 8 plus the swappable pool in `TEMPLATES.md`, all grounded in the evidence library), per JD. The template's fixed set is a starting point, not a ceiling. Keep 8 bullets, one page.
- **Rewrite budget.** For every `direct` requirement whose mapped bullet does not lead with it, rewrite the lead clause (the family `coreClaim`/`verifiedOutcomes` stay immutable). Floor by depth: `light` 0-1 substantive bullet edits, `standard` at least 2, `deep` more. Record the actual count on the posting (`set-strategy --rewrites`).
- **Domain translation is a required pre-sign-off step, not a cleanup afterthought.** List every domain-specific term in the draft (healthcare, medical codes, HL7, FHIR, clinical, EHR, terminology) and either justify each against the JD or replace it with a domain-neutral equivalent. No-op for healthcare-vertical JDs (Template C).
- **Adversarial skim review before sign-off.** After the draft, a fresh reviewer with no tailoring context sees only the JD plus the extracted resume text and answers: what does the first third say this person is, would a recruiter for this exact req shortlist them in 6 seconds, and the single highest-leverage change. Address or consciously dismiss its top finding before sign-off. This replaces author self-review as the gate.
- Before editing, identify the five most important hiring criteria and map each to confirmed evidence, its intended resume location, and direct/adjacent/unsupported confidence. Store these as **structured requirement rows** on the posting (`tracker.mjs set-requirements`), not just free text; triage may have already seeded them as `suggested` for you to validate.
- Draw evidence from `source/resume-evidence-library.yaml` (the verified evidence families). Each family's `coreClaim` and `verifiedOutcomes` are immutable; use a `variant` as emphasis guidance only and write a natural final bullet. Honor every `prohibitedClaims` entry. Record the `evidenceFamilyIds` used per requirement.
- Count a criterion as clearly covered only when its evidence appears in the summary or experience bullets. A skills-list mention alone does not count. Target at least 3 of the top 5 covered.
- For each `direct` requirement, set `matchTerms` (literal strings present in the finished resume). Finalize-time QA fails a resume if a direct requirement's terms are missing from the extracted PDF text.
- Strengthen existing bullets before adding new claims.
- Concise, high-signal bullets over longer explanations.
- Employer names, dates, titles, awards, metrics, and education stay accurate.
- Never invent employers, titles, dates, metrics, certifications, or tools.
- **Never name a specific client / customer account** in any externally-shared material (resume, cover letter, LinkedIn, screening answers). Describe accounts generically ("the company's two largest enterprise healthcare accounts," "a top-tier enterprise healthcare account") while keeping every metric, outcome, and scope figure exactly as verified. Real names stay internal-only in `candidate-considerations.md` (decided 2026-07-07); they must never flow into an evidence-library `templateBullet`, a resume, or any other shared document.
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

- **Selective, not automatic.** Decide a cover-letter strategy per application and record it (`set-strategy --cover-strategy`): `none` (default; a strong tailored resume plus outreach beats a boilerplate letter), `required` (the posting/form mandates one), `transition` (the SE-pivot narrative needs explaining), `motivation` (a genuine company/mission reason the resume can't carry), or `outreach` (the letter doubles as a note to a named contact). Only write one when the strategy is not `none`.
- When one is written, {{CANDIDATE_NAME}} must edit at least one sentence before it is finalized (a 100% agent-written letter is a tell).
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
- **Automated finalize QA (deterministic backstop, not a replacement for the above):** when a resume `.docx` is finalized to PDF (the Finalize button / `/package`), the backend extracts the PDF text and flags: more than one page, any em/en dash, empty bullets, suspiciously low word count, and any `direct` requirement whose `matchTerms` are absent. The verdict (pass / warn / fail) and findings show on the resume row in the posting drawer. Resolve a `fail` before submitting.

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

A local-first web app in `app/` (Spring Boot + React + Postgres) tracks every posting, its status, JD text, role-match notes, and links to the generated docs. It does **not** generate documents — tailoring stays in Claude Code. The **tracker DB is the source of truth.** `source/applications-log.md` and the Chrome prompt's seen-roles block are now *generated snapshots*: regenerate them from the DB with `node "app/scripts/tracker.mjs" export-log` / `seen-roles` after status changes. Do **not** hand-edit them — the next regen overwrites the data rows.

- **Run it:** `app/runserver.ps1` (double-click or `-Action start`). Interactive menu, or `-Action start|stop|restart|status -Scope full|backend|frontend|db`. Backend `:8080`, frontend `:5173`, Postgres in Docker `:5433`. The in-app **Shut down** button calls the same script.
- **Inbox intake:** the app's **Add JD** button (and Claude-in-Chrome) drop JDs into the `Inbox` lane. In Claude Code, "triage the inbox" / "tailor posting N" reads the JD from the DB via `app/scripts/tracker.mjs` — no re-paste, no Anthropic API (Claude Code is the compute).
- **Source jobs button:** runs the LinkedIn guest-endpoint sweep **server-side** (`JobSourcingService`, no Chrome / no agent / works under remote-control). For each role it fetches cards + JD bodies, dedupes by stable `external_id` (then company+role), and applies a cheap deterministic pre-pass before anything lands:
  - **Quality score** (`confidence` 0–100) — penalizes recruiter/staffing names, pay-rate-bait titles, promotional pipes, and empty JDs. Low scores auto-route to `Pre-Triage-Skip`.
  - **Pre-triage gate** — keeps obvious non-starters out of the Inbox so LLM triage never burns effort on junk. Conservative: rejects only on **off-target function** (non-SE/eng title) or **over-leveled AND no real stack overlap** (`10+ yrs` *or* Staff/Principal+ title combined with zero/incidental-alien overlap). **Years alone never reject** — stretch roles stay. Gated rows go to `Pre-Triage-Skip` with the reason in `notes`; spot-check that lane for false negatives.
  - **Fit hint** (`Strong`/`Possible`/`Stretch`/`Weak`) — a keyword-overlap *prior* on each kept posting (shown as an Inbox badge, stored in `fit_hint`). A skim aid and triage prior **only — not the role-match rating.** See `/triage` for how to weigh it.

  Survivors land in `Inbox`; the keyword lists live in `JobSourcingService` and are sourced from `candidate-considerations.md`.
- **Permission entries:** `.claude/settings.local.json` accumulates auto-approved `Bash(...)`/`PowerShell(...)` command patterns over time. Avoid baking in absolute paths to this project folder (e.g. hardcoding `C:\Users\carte\...\Codex-JobSearch\...`); the folder has already moved once and every hardcoded-path entry silently went dead when that happened. Prefer relative paths or command-name/glob patterns so entries survive a future move.
- **DB writes:** `/triage`, `/tailor`, `/package` persist directly to the DB via `tracker.mjs` (health-gated), then regenerate the markdown snapshots with `export-log` / `seen-roles`. If the API is down, persistence is skipped (they say so) and dedupe falls back to reading the snapshot. See those skills for exact commands.
- **Phase 1 fields (V20):** `/triage` writes structured knockouts via `set-knockouts` (degree + equivalency, years gate, residency, clearance, certifications). `/tailor` records the substantive-edit count (`set-strategy --rewrites`) and the selective cover-letter decision (`set-strategy --cover-strategy none|required|transition|motivation|outreach`). All are additive, nullable posting fields and surface in the posting drawer.
- **Phase 2 fields (V21) — selection & amplification:**
  - **Pursuit score (computed, not stored).** A deterministic 0–100 score, separate from the fit/role-match rating: it answers "is this the best use of the next hour?", not "can {{CANDIDATE_NAME}} do the job." `PursuitService` computes it on the fly (so it auto-updates as a posting ages or gains contacts) from **freshness** (days since added/last seen), **comp** (parsed midpoint), **hard knockouts** (a degree gate with no equivalency, a high years gate, clearance, or residency subtracts), **warm-funnel availability** (a recorded referral connection or any attached contact adds), a **strategic-value** nudge, and a **light fit factor** so a weak-fit role can't top the list. Bands: **hot ≥ 70, warm 45–69, cool < 45**. It shows in the posting drawer's Selection section (with the reason breakdown) and drives the Work Queue **Pursue** bucket, which lists not-yet-submitted postings ranked by score; a fresh + hot posting carries a 24h apply-target nudge (age is the timer).
  - **Human-set inputs.** `set-pursuit --id N [--strategic low|medium|high] [--referral none|searching|connection-1st|connection-2nd|employee-warm|recruiter-known] [--referral-notes "…"]`. The referral hunt result is recorded **even when "none"** so checked-and-empty is distinguishable from unchecked. Editable in the drawer.
  - **Outreach (draft-only).** Contacts carry `relationship`, `outreach_channel`, `outreach_status` (`none|drafted|sent|replied|no-response`), the drafted note, and a sent timestamp. `/outreach` drafts a short note grounded in the top requirement + strongest direct evidence and stores it via `add-contact` / `set-outreach`; **{{CANDIDATE_NAME}} always sends it himself** (nothing is ever sent on his behalf). The draft and status show in the drawer's Contacts section with a copy button and a "mark sent" action.
  - **Learning loop.** Registering the first resume for a posting stamps the current template version (Settings > Resume template cohort, default `v1`); later resumes do not rewrite that cohort. Analytics cuts the mature measured cohort by template version, evidence coverage, rewrite count, cover-letter strategy, outreach, posting age, knockout presence, and pursuit band, and reports evidence-family response performance. These cuts are observational only. Run `/retro` monthly to compare a saved snapshot and propose one human-reviewed workflow adjustment.
- **Agent runner (`launch-agent.ps1`):** each agent launch **auto-updates the selected CLI** first (best-effort, throttled once/day per agent via `app/logs/agents/.cli-update-<agent>`; failures are logged and never block the run). Bypass with `-SkipCliUpdate`. The **agent window's model picker** lists Claude models as floating aliases (`opus`/`sonnet`/`haiku`/`fable`) that auto-track the latest version, each with its own reasoning-effort range, default, cost/speed, and a one-line blurb; Codex models stay auto-detected from the CLI's model cache (which the auto-update keeps current).

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
