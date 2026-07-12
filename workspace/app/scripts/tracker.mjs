#!/usr/bin/env node
// tracker.mjs — thin CLI over the job-search tracker REST API.
//
// Used by the /triage, /tailor, and /package skills to mirror their markdown
// bookkeeping into the local Postgres-backed tracker. The markdown files remain
// the source of truth until the cutover is confirmed; this is a *dual-write*
// helper, so every command is safe to skip if the API is down.
//
// Base URL: env TRACKER_API, else http://localhost:8080
//
// Commands:
//   health
//       Exit 0 if the API answers, non-zero otherwise. Skills call this first
//       and fall back to markdown-only when it fails.
//
//   find    --company "X" --role "Y"
//       Print matching postings (JSON array of {id,company,roleTitle,status}).
//       Case-insensitive; role matches exactly or as a substring either way.
//       Used for dedupe.
//
//   inbox
//       Print postings in the Inbox lane (pasted via the UI / queued from
//       Claude-in-Chrome, not yet triaged), one per line: id, company — role.
//       The triage skill reads this to pick up JDs queued from the browser.
//
//   get     --id N
//       Print the full posting JSON (including jdText). Lets skills read a JD
//       out of the DB instead of having it pasted into chat.
//
//   upsert  --company "X" --role "Y" [--status L] [--location ..] [--comp ..]
//           [--source ..] [--url ..] [--jd-file path | --jd "text"]
//           [--rating 8.5] [--matches ..] [--gaps ..] [--hm ..] [--notes ..]
//           [--date-added YYYY-MM-DD] [--date-applied YYYY-MM-DD]
//       Create the posting, or update the existing company+role match in place
//       (merging — only the flags you pass are changed). Prints the resulting
//       posting JSON. Status changes are recorded server-side in status_history.
//
//   set-status (--id N | --company X --role Y) --status "Label"
//       Convenience wrapper around upsert that only flips status.
//
//   set-strategy --id N [--requirements-file path] [--evidence-file path]
//                [--coverage 0-5] [--depth light|standard|deep]
//                [--rewrites N] [--cover-strategy none|required|transition|motivation|outreach]
//       Store the free-text requirement-to-evidence research record (fallback /
//       human-readable summary) for a tailored posting. --rewrites records the
//       count of substantive bullet edits made this pass (>= 2 at standard depth);
//       --cover-strategy records the selective cover-letter decision. Both are only
//       written when passed, so a plain strategy save doesn't wipe them.
//
//   set-knockouts --id N [--degree "Bachelor's"] [--degree-equivalency true|false]
//                 [--years N] [--residency ..] [--clearance ..] [--certifications ..]
//       Store the structured knockout fields extracted at triage. Only the flags
//       you pass are updated. A hard knockout (degree/years) without an equivalency
//       clause is meant to cap the pursuit recommendation regardless of fit score.
//
//   set-pursuit --id N [--strategic low|medium|high] [--referral <status>]
//               [--referral-notes "…"]
//       Store the human-set pursuit inputs. --referral <status> is one of
//       none|searching|connection-1st|connection-2nd|employee-warm|recruiter-known
//       (record the referral-hunt result even when "none"). The pursuit SCORE itself
//       is computed server-side (see PursuitService) and echoed back in .pursuit.
//
//   add-contact --posting N --name "…" [--title ..] [--email ..] [--phone ..]
//               [--relationship hiring-manager|same-function|recruiter|referral|other]
//               [--channel linkedin|email|other] [--outreach-status none|drafted|sent|replied|no-response]
//               [--draft-file path] [--notes ..]
//       Create a contact against a posting. --draft-file reads the outreach note text
//       from a file (keeps multi-line drafts out of argv). Outreach is draft-only:
//       {{CANDIDATE_NAME}} sends the note himself; this only records it.
//
//   set-outreach --id <contactId> [--status ..] [--channel ..] [--sent-at now|ISO]
//                [--draft-file path]
//       Update only the outreach fields on an existing contact (partial). --sent-at now
//       stamps the current time ({{CANDIDATE_NAME}} marking that he sent it).
//
//   requirements --id N
//       Print the structured top-five requirement rows for a posting (JSON array).
//
//   set-requirements --id N --file path.json
//       Replace the structured top-five requirement rows from a JSON array file.
//       Each element: { requirement (required), priority, reqType, sourceExcerpt,
//       status, evidence, evidenceLocation, evidenceConfidence, action,
//       evidenceFamilyIds, matchTerms, covered }. Recomputes evidence coverage.
//       This is the primary tailoring write path; set-strategy stays as the
//       human-readable mirror.
//
//   add-resume  --posting N --path "rel/path.docx" [--template A] [--pages 1]
//               [--rating 8.5] [--version N] [--template-version v1]
//   add-cover   --posting N --path "rel/path.docx" [--version N]
//       Register a generated document against a posting. add-resume also stamps the
//       posting's template-version cohort (Phase 3): --template-version overrides the
//       current resume.templateVersion setting, and it only stamps if not already set.
//
//   list
//       Print all postings (id, status, company — role), one per line.
//
//   analytics
//       Print the full analytics payload (funnel, cohorts, and the Phase 3 learning-loop
//       cuts: template cohorts, response rate by decision dimension, evidence-family
//       performance) as JSON on stdout. Feeds the monthly /retro skill.
//
//   export-log  [--file path]
//       Regenerate source/applications-log.md from the DB (the DB is the source
//       of truth; this file is a generated snapshot). Preserves the preamble up
//       to the table separator; rebuilds the data rows. Run after status changes
//       instead of hand-editing the log.
//
//   seen-roles  [--file path]
//       Regenerate the <!-- SEEN ROLES START/END --> block in
//       source/chrome-job-sourcing-prompt.md from the DB. Preserves the markers
//       and surrounding prompt text.
//
// Exit codes: 0 success, 1 usage/arg error, 2 API/network error, 3 not found.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const BASE = (process.env.TRACKER_API || "http://localhost:8080").replace(/\/+$/, "");

// Repo root is two levels up from app/scripts/, so the snapshot regen commands
// resolve source/* the same way regardless of the caller's cwd.
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        out[key] = true;
      } else {
        out[key] = next;
        i++;
      }
    }
  }
  return out;
}

function die(code, msg) {
  if (msg) process.stderr.write(msg + "\n");
  process.exit(code);
}

async function api(method, path, body) {
  let res;
  try {
    res = await fetch(BASE + path, {
      method,
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    die(2, `tracker: API unreachable at ${BASE} (${e.message})`);
  }
  if (res.status === 404) return { _notFound: true };
  if (!res.ok) {
    let detail = "";
    try {
      const j = await res.json();
      detail = j.detail || j.message || JSON.stringify(j);
    } catch {
      detail = await res.text().catch(() => "");
    }
    die(2, `tracker: ${method} ${path} -> ${res.status} ${detail}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

const norm = (s) => (s || "").toLowerCase().replace(/\s+/g, " ").trim();

function rolesMatch(a, b) {
  const x = norm(a), y = norm(b);
  if (!x || !y) return false;
  return x === y || x.includes(y) || y.includes(x);
}

async function findPostings(company, role) {
  const all = await api("GET", "/api/postings");
  const c = norm(company);
  return all.filter((p) => norm(p.company) === c && (role ? rolesMatch(p.roleTitle, role) : true));
}

// Build a full PostingRequest body from an existing response (for full-replace PUT),
// then overlay any provided flags.
function mergeBody(existing, flags) {
  const base = existing
    ? {
        company: existing.company,
        roleTitle: existing.roleTitle,
        location: existing.location,
        comp: existing.comp,
        source: existing.source,
        url: existing.url,
        jdText: existing.jdText,
        status: existing.status,
        roleMatchRating: existing.roleMatchRating,
        strongestMatches: existing.strongestMatches,
        gaps: existing.gaps,
        hiringManagerRead: existing.hiringManagerRead,
        notes: existing.notes,
        dateAdded: existing.dateAdded,
        dateApplied: existing.dateApplied,
      }
    : {
        company: null, roleTitle: null, location: null, comp: null, source: null,
        url: null, jdText: null, status: null, roleMatchRating: null,
        strongestMatches: null, gaps: null, hiringManagerRead: null, notes: null,
        dateAdded: null, dateApplied: null,
      };
  const map = {
    company: "company", role: "roleTitle", location: "location", comp: "comp",
    source: "source", url: "url", status: "status", rating: "roleMatchRating",
    matches: "strongestMatches", gaps: "gaps", hm: "hiringManagerRead",
    notes: "notes", "date-added": "dateAdded", "date-applied": "dateApplied",
  };
  for (const [flag, field] of Object.entries(map)) {
    if (flags[flag] !== undefined) base[field] = flags[flag];
  }
  if (flags["jd-file"] !== undefined) {
    base.jdText = readFileSync(flags["jd-file"], "utf8");
  } else if (flags.jd !== undefined) {
    base.jdText = flags.jd;
  }
  if (base.roleMatchRating != null) base.roleMatchRating = Number(base.roleMatchRating);
  return base;
}

async function cmdHealth() {
  await api("GET", "/api/postings");
  process.stdout.write("ok\n");
}

async function cmdFind(flags) {
  if (!flags.company) die(1, "find: --company required");
  const matches = await findPostings(flags.company, flags.role);
  process.stdout.write(
    JSON.stringify(matches.map((p) => ({ id: p.id, company: p.company, roleTitle: p.roleTitle, status: p.status })), null, 2) + "\n"
  );
}

async function cmdInbox() {
  const all = await api("GET", "/api/postings?status=Inbox");
  process.stdout.write(`inbox: ${all.length}\n`);
  for (const p of all) process.stdout.write(`${p.id}\t${p.company} — ${p.roleTitle}\n`);
}

async function cmdGet(flags) {
  if (!flags.id) die(1, "get: --id required");
  const p = await api("GET", `/api/postings/${flags.id}`);
  if (p._notFound) die(3, `get: posting #${flags.id} not found`);
  process.stdout.write(JSON.stringify(p, null, 2) + "\n");
}

async function cmdUpsert(flags) {
  if (!flags.company || !flags.role) die(1, "upsert: --company and --role required");
  const matches = await findPostings(flags.company, flags.role);
  let result;
  if (matches.length === 0) {
    const body = mergeBody(null, flags);
    body.company = flags.company;
    body.roleTitle = flags.role;
    result = await api("POST", "/api/postings", body);
    process.stderr.write(`tracker: created posting #${result.id} (${result.status})\n`);
  } else {
    const existing = matches[0];
    if (matches.length > 1) {
      process.stderr.write(`tracker: ${matches.length} matches for "${flags.company} — ${flags.role}"; updating #${existing.id}. Others: ${matches.slice(1).map((m) => "#" + m.id).join(", ")}\n`);
    }
    // --company/--role are lookup keys on update; never let them clobber the
    // canonical stored values. Only explicit field flags should change data.
    const { company: _c, role: _r, ...fieldFlags } = flags;
    const body = mergeBody(existing, fieldFlags);
    result = await api("PUT", `/api/postings/${existing.id}`, body);
    process.stderr.write(`tracker: updated posting #${result.id} (${result.status})\n`);
  }
  process.stdout.write(JSON.stringify({ id: result.id, status: result.status }) + "\n");
}

async function cmdSetStatus(flags) {
  if (!flags.status) die(1, "set-status: --status required");
  if (flags.id) {
    const existing = await api("GET", `/api/postings/${flags.id}`);
    if (existing._notFound) die(3, `set-status: posting #${flags.id} not found`);
    const body = mergeBody(existing, { status: flags.status });
    const result = await api("PUT", `/api/postings/${flags.id}`, body);
    process.stderr.write(`tracker: posting #${result.id} -> ${result.status}\n`);
    process.stdout.write(JSON.stringify({ id: result.id, status: result.status }) + "\n");
    return;
  }
  if (!flags.company || !flags.role) die(1, "set-status: --id, or --company and --role, required");
  await cmdUpsert({ company: flags.company, role: flags.role, status: flags.status });
}

async function cmdSetStrategy(flags) {
  if (!flags.id) die(1, "set-strategy: --id required");
  const coverage = flags.coverage == null ? null : Number(flags.coverage);
  if (coverage != null && (!Number.isInteger(coverage) || coverage < 0 || coverage > 5)) {
    die(1, "set-strategy: --coverage must be an integer from 0 to 5");
  }
  const depth = flags.depth ?? null;
  if (depth != null && !["light", "standard", "deep"].includes(depth)) {
    die(1, "set-strategy: --depth must be light, standard, or deep");
  }
  let rewrites = null;
  if (flags.rewrites != null) {
    rewrites = Number(flags.rewrites);
    if (!Number.isInteger(rewrites) || rewrites < 0) {
      die(1, "set-strategy: --rewrites must be a non-negative integer");
    }
  }
  const coverStrategy = flags["cover-strategy"] ?? null;
  const COVER_STRATEGIES = ["none", "required", "transition", "motivation", "outreach"];
  if (coverStrategy != null && !COVER_STRATEGIES.includes(coverStrategy)) {
    die(1, `set-strategy: --cover-strategy must be one of ${COVER_STRATEGIES.join(", ")}`);
  }
  const body = {
    topRequirements: flags["requirements-file"]
      ? readFileSync(flags["requirements-file"], "utf8").trim() || null
      : null,
    evidenceMap: flags["evidence-file"]
      ? readFileSync(flags["evidence-file"], "utf8").trim() || null
      : null,
    evidenceCoverage: coverage,
    tailoringDepth: depth,
    rewriteCount: rewrites,
    coverLetterStrategy: coverStrategy,
  };
  const result = await api("PUT", `/api/postings/${flags.id}/strategy`, body);
  if (result._notFound) die(3, `set-strategy: posting #${flags.id} not found`);
  process.stderr.write(
    `tracker: strategy saved for posting #${result.id} (${result.evidenceCoverage ?? 0}/5, ${result.tailoringDepth ?? "unrated"}`
    + `${result.rewriteCount != null ? `, ${result.rewriteCount} rewrites` : ""}`
    + `${result.coverLetterStrategy ? `, cover: ${result.coverLetterStrategy}` : ""})\n`
  );
  process.stdout.write(JSON.stringify({
    id: result.id,
    evidenceCoverage: result.evidenceCoverage,
    tailoringDepth: result.tailoringDepth,
    rewriteCount: result.rewriteCount,
    coverLetterStrategy: result.coverLetterStrategy,
  }) + "\n");
}

async function cmdSetKnockouts(flags) {
  if (!flags.id) die(1, "set-knockouts: --id required");
  const body = {};
  if (flags.degree !== undefined) body.degree = flags.degree === true ? null : flags.degree;
  if (flags["degree-equivalency"] !== undefined) {
    const v = String(flags["degree-equivalency"]).toLowerCase();
    if (!["true", "false"].includes(v)) {
      die(1, "set-knockouts: --degree-equivalency must be true or false");
    }
    body.degreeEquivalency = v === "true";
  }
  if (flags.years !== undefined) {
    const y = Number(flags.years);
    if (!Number.isInteger(y) || y < 0) die(1, "set-knockouts: --years must be a non-negative integer");
    body.years = y;
  }
  if (flags.residency !== undefined) body.residency = flags.residency === true ? null : flags.residency;
  if (flags.clearance !== undefined) body.clearance = flags.clearance === true ? null : flags.clearance;
  if (flags.certifications !== undefined) {
    body.certifications = flags.certifications === true ? null : flags.certifications;
  }
  if (Object.keys(body).length === 0) {
    die(1, "set-knockouts: pass at least one of --degree/--degree-equivalency/--years/--residency/--clearance/--certifications");
  }
  const result = await api("PUT", `/api/postings/${flags.id}/knockouts`, body);
  if (result._notFound) die(3, `set-knockouts: posting #${flags.id} not found`);
  process.stderr.write(
    `tracker: knockouts saved for posting #${result.id}`
    + ` (degree: ${result.knockoutDegree ?? "-"}`
    + `${result.knockoutDegreeEquivalency != null ? `/equiv:${result.knockoutDegreeEquivalency}` : ""}`
    + `, years: ${result.knockoutYears ?? "-"})\n`
  );
  process.stdout.write(JSON.stringify({
    id: result.id,
    knockoutDegree: result.knockoutDegree,
    knockoutDegreeEquivalency: result.knockoutDegreeEquivalency,
    knockoutYears: result.knockoutYears,
    knockoutResidency: result.knockoutResidency,
    knockoutClearance: result.knockoutClearance,
    knockoutCertifications: result.knockoutCertifications,
  }) + "\n");
}

async function cmdSetPursuit(flags) {
  if (!flags.id) die(1, "set-pursuit: --id required");
  const body = {};
  const STRATEGIC = ["low", "medium", "high"];
  const REFERRALS = ["none", "searching", "connection-1st", "connection-2nd", "employee-warm", "recruiter-known"];
  if (flags.strategic !== undefined) {
    const v = flags.strategic === true ? null : String(flags.strategic);
    if (v != null && !STRATEGIC.includes(v)) die(1, `set-pursuit: --strategic must be one of ${STRATEGIC.join(", ")}`);
    body.strategicValue = v;
  }
  if (flags.referral !== undefined) {
    const v = flags.referral === true ? null : String(flags.referral);
    if (v != null && !REFERRALS.includes(v)) die(1, `set-pursuit: --referral must be one of ${REFERRALS.join(", ")}`);
    body.referralStatus = v;
  }
  if (flags["referral-notes"] !== undefined) {
    body.referralNotes = flags["referral-notes"] === true ? null : flags["referral-notes"];
  }
  if (Object.keys(body).length === 0) {
    die(1, "set-pursuit: pass at least one of --strategic/--referral/--referral-notes");
  }
  const result = await api("PUT", `/api/postings/${flags.id}/pursuit`, body);
  if (result._notFound) die(3, `set-pursuit: posting #${flags.id} not found`);
  const pursuit = result.pursuit || {};
  process.stderr.write(
    `tracker: pursuit inputs saved for posting #${result.id}`
    + ` (strategic: ${result.strategicValue ?? "-"}, referral: ${result.referralStatus ?? "-"}`
    + `; score ${pursuit.score ?? "?"}/${pursuit.band ?? "?"})\n`
  );
  process.stdout.write(JSON.stringify({
    id: result.id,
    strategicValue: result.strategicValue,
    referralStatus: result.referralStatus,
    referralNotes: result.referralNotes,
    pursuit,
  }) + "\n");
}

async function cmdRequirements(flags) {
  if (!flags.id) die(1, "requirements: --id required");
  const rows = await api("GET", `/api/postings/${flags.id}/requirements`);
  if (rows && rows._notFound) die(3, `requirements: posting #${flags.id} not found`);
  process.stdout.write(JSON.stringify(rows, null, 2) + "\n");
}

async function cmdSetRequirements(flags) {
  if (!flags.id) die(1, "set-requirements: --id required");
  if (!flags.file) die(1, "set-requirements: --file (JSON array) required");
  let rows;
  try {
    rows = JSON.parse(readFileSync(flags.file, "utf8"));
  } catch (e) {
    die(1, `set-requirements: cannot read/parse ${flags.file} (${e.message})`);
  }
  if (!Array.isArray(rows)) die(1, "set-requirements: file must contain a JSON array");
  const result = await api("PUT", `/api/postings/${flags.id}/requirements`, rows);
  if (result && result._notFound) die(3, `set-requirements: posting #${flags.id} not found`);
  const covered = result.filter((r) => r.covered).length;
  process.stderr.write(
    `tracker: ${result.length} requirements saved for posting #${flags.id} (${covered} covered)\n`
  );
  process.stdout.write(JSON.stringify({ count: result.length, covered }) + "\n");
}

async function cmdAddResume(flags) {
  if (!flags.posting || !flags.path) die(1, "add-resume: --posting and --path required");
  const body = {
    templateUsed: flags.template ?? null,
    filePath: flags.path,
    pageCount: flags.pages != null ? Number(flags.pages) : null,
    selfReviewRating: flags.rating != null ? Number(flags.rating) : null,
    version: flags.version != null ? Number(flags.version) : null,
    templateVersion: flags["template-version"] && flags["template-version"] !== true
      ? String(flags["template-version"]) : null,
  };
  const r = await api("POST", `/api/postings/${flags.posting}/resumes`, body);
  if (r._notFound) die(3, `add-resume: posting #${flags.posting} not found`);
  process.stderr.write(`tracker: resume #${r.id} v${r.version} on posting #${r.postingId}\n`);
  process.stdout.write(JSON.stringify({ id: r.id, version: r.version }) + "\n");
}

async function cmdAddCover(flags) {
  if (!flags.posting || !flags.path) die(1, "add-cover: --posting and --path required");
  const body = { filePath: flags.path, version: flags.version != null ? Number(flags.version) : null };
  const r = await api("POST", `/api/postings/${flags.posting}/cover-letters`, body);
  if (r._notFound) die(3, `add-cover: posting #${flags.posting} not found`);
  process.stderr.write(`tracker: cover letter #${r.id} v${r.version} on posting #${r.postingId}\n`);
  process.stdout.write(JSON.stringify({ id: r.id, version: r.version }) + "\n");
}

async function cmdAddContact(flags) {
  if (!flags.posting || !flags.name) die(1, "add-contact: --posting and --name required");
  const RELATIONSHIPS = ["hiring-manager", "same-function", "recruiter", "referral", "other"];
  const CHANNELS = ["linkedin", "email", "other"];
  const STATUSES = ["none", "drafted", "sent", "replied", "no-response"];
  if (flags.relationship && !RELATIONSHIPS.includes(String(flags.relationship))) {
    die(1, `add-contact: --relationship must be one of ${RELATIONSHIPS.join(", ")}`);
  }
  if (flags.channel && !CHANNELS.includes(String(flags.channel))) {
    die(1, `add-contact: --channel must be one of ${CHANNELS.join(", ")}`);
  }
  if (flags["outreach-status"] && !STATUSES.includes(String(flags["outreach-status"]))) {
    die(1, `add-contact: --outreach-status must be one of ${STATUSES.join(", ")}`);
  }
  const body = {
    name: flags.name,
    title: flags.title === true ? null : flags.title ?? null,
    email: flags.email === true ? null : flags.email ?? null,
    phone: flags.phone === true ? null : flags.phone ?? null,
    notes: flags.notes === true ? null : flags.notes ?? null,
    relationship: flags.relationship ?? null,
    outreachChannel: flags.channel ?? null,
    outreachStatus: flags["outreach-status"] ?? (flags["draft-file"] ? "drafted" : "none"),
    outreachDraft: flags["draft-file"] ? readFileSync(flags["draft-file"], "utf8").trim() || null : null,
    outreachSentAt: null,
  };
  const r = await api("POST", `/api/postings/${flags.posting}/contacts`, body);
  if (r._notFound) die(3, `add-contact: posting #${flags.posting} not found`);
  process.stderr.write(
    `tracker: contact #${r.id} (${r.name}${r.relationship ? `, ${r.relationship}` : ""}) on posting #${r.postingId}`
    + ` [outreach: ${r.outreachStatus}]\n`
  );
  process.stdout.write(JSON.stringify({ id: r.id, postingId: r.postingId, outreachStatus: r.outreachStatus }) + "\n");
}

async function cmdSetOutreach(flags) {
  if (!flags.id) die(1, "set-outreach: --id (contact id) required");
  const STATUSES = ["none", "drafted", "sent", "replied", "no-response"];
  const CHANNELS = ["linkedin", "email", "other"];
  const body = {};
  if (flags.status !== undefined) {
    const v = flags.status === true ? null : String(flags.status);
    if (v != null && !STATUSES.includes(v)) die(1, `set-outreach: --status must be one of ${STATUSES.join(", ")}`);
    body.outreachStatus = v;
  }
  if (flags.channel !== undefined) {
    const v = flags.channel === true ? null : String(flags.channel);
    if (v != null && !CHANNELS.includes(v)) die(1, `set-outreach: --channel must be one of ${CHANNELS.join(", ")}`);
    body.outreachChannel = v;
  }
  if (flags["draft-file"] !== undefined) {
    body.outreachDraft = flags["draft-file"] === true ? null : (readFileSync(flags["draft-file"], "utf8").trim() || null);
  }
  if (flags["sent-at"] !== undefined) {
    const raw = String(flags["sent-at"]);
    body.outreachSentAt = raw === "now" ? new Date().toISOString() : raw;
  }
  if (Object.keys(body).length === 0) {
    die(1, "set-outreach: pass at least one of --status/--channel/--draft-file/--sent-at");
  }
  const r = await api("PUT", `/api/contacts/${flags.id}/outreach`, body);
  if (r._notFound) die(3, `set-outreach: contact #${flags.id} not found`);
  process.stderr.write(`tracker: outreach updated for contact #${r.id} [${r.outreachStatus}]\n`);
  process.stdout.write(JSON.stringify({ id: r.id, outreachStatus: r.outreachStatus, outreachSentAt: r.outreachSentAt }) + "\n");
}

async function cmdList() {
  const all = await api("GET", "/api/postings");
  process.stdout.write(`count: ${all.length}\n`);
  for (const p of all) process.stdout.write(`${p.id}\t${p.status}\t${p.company} — ${p.roleTitle}\n`);
}

async function cmdAnalytics() {
  const result = await api("GET", "/api/analytics");
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

// Escape a cell for a markdown table row: pipes break columns, newlines break rows.
function cell(v) {
  if (v == null) return "";
  return String(v).replace(/\r?\n/g, " ").replace(/\|/g, "\\|").trim();
}

// Postings sorted oldest-first by dateAdded, then id — a stable, deterministic
// order so the regenerated snapshots diff cleanly run to run.
function chronological(postings) {
  return [...postings].sort((a, b) => {
    const da = a.dateAdded || "0000-00-00";
    const db = b.dateAdded || "0000-00-00";
    if (da !== db) return da < db ? -1 : 1;
    return (a.id || 0) - (b.id || 0);
  });
}

// Regenerate source/applications-log.md from the DB. The DB is the source of
// truth; this file is a generated, human-readable snapshot. Everything in the
// file up to and including the table separator line (|---|...) is preserved as
// a static preamble; the data rows below it are rebuilt from the DB.
async function cmdExportLog(flags) {
  const file = flags.file ? resolve(flags.file) : resolve(REPO_ROOT, "source", "applications-log.md");
  const all = chronological(await api("GET", "/api/postings"));
  let existing;
  try {
    existing = readFileSync(file, "utf8");
  } catch {
    die(2, `export-log: cannot read ${file}`);
  }
  const lines = existing.split(/\r?\n/);
  const sepIdx = lines.findIndex((l) => /^\s*\|\s*-{2,}/.test(l));
  if (sepIdx < 0) {
    die(2, "export-log: table separator (|---|...) not found in applications-log.md");
  }
  const preamble = lines.slice(0, sepIdx + 1).join("\n");
  const rows = all.map((p) => {
    const date = p.dateAdded || "(pre-2026)";
    return `| ${date} | ${cell(p.company)} | ${cell(p.roleTitle)} | ${cell(p.location)} | `
      + `${cell(p.source)} | ${cell(p.status)} | ${cell(p.notes)} |`;
  });
  writeFileSync(file, preamble + "\n" + rows.join("\n") + "\n", "utf8");
  process.stdout.write(`export-log: wrote ${rows.length} rows to ${file}\n`);
}

// Regenerate the seen-roles block in source/chrome-job-sourcing-prompt.md from
// the DB, preserving the <!-- SEEN ROLES START/END --> markers and everything
// outside them. One bullet per posting: "- {Company} — {Role} ({Status})".
async function cmdSeenRoles(flags) {
  const file = flags.file ? resolve(flags.file) : resolve(REPO_ROOT, "source", "chrome-job-sourcing-prompt.md");
  const START = "<!-- SEEN ROLES START -->";
  const END = "<!-- SEEN ROLES END -->";
  const all = chronological(await api("GET", "/api/postings"));
  let existing;
  try {
    existing = readFileSync(file, "utf8");
  } catch {
    die(2, `seen-roles: cannot read ${file}`);
  }
  const startIdx = existing.indexOf(START);
  const endIdx = existing.indexOf(END);
  if (startIdx < 0 || endIdx < 0 || endIdx < startIdx) {
    die(2, "seen-roles: SEEN ROLES START/END markers not found (or out of order)");
  }
  const bullets = all
    .map((p) => `- ${cell(p.company)} — ${cell(p.roleTitle)} (${cell(p.status)})`)
    .join("\n");
  const before = existing.slice(0, startIdx + START.length);
  const after = existing.slice(endIdx);
  writeFileSync(file, `${before}\n${bullets}\n${after}`, "utf8");
  process.stdout.write(`seen-roles: wrote ${all.length} roles to ${file}\n`);
}

const [cmd, ...rest] = process.argv.slice(2);
const flags = parseArgs(rest);
const table = {
  health: cmdHealth,
  find: () => cmdFind(flags),
  inbox: cmdInbox,
  get: () => cmdGet(flags),
  upsert: () => cmdUpsert(flags),
  "set-status": () => cmdSetStatus(flags),
  "set-strategy": () => cmdSetStrategy(flags),
  "set-knockouts": () => cmdSetKnockouts(flags),
  "set-pursuit": () => cmdSetPursuit(flags),
  requirements: () => cmdRequirements(flags),
  "set-requirements": () => cmdSetRequirements(flags),
  "add-resume": () => cmdAddResume(flags),
  "add-cover": () => cmdAddCover(flags),
  "add-contact": () => cmdAddContact(flags),
  "set-outreach": () => cmdSetOutreach(flags),
  list: cmdList,
  analytics: cmdAnalytics,
  "export-log": () => cmdExportLog(flags),
  "seen-roles": () => cmdSeenRoles(flags),
};
if (!cmd || !table[cmd]) {
  die(1, `usage: node tracker.mjs <health|find|inbox|get|upsert|set-status|set-strategy|set-knockouts|set-pursuit|add-contact|set-outreach|requirements|set-requirements|add-resume|add-cover|list|analytics|export-log|seen-roles> [flags]`);
}
table[cmd]().catch((e) => die(2, `tracker: ${e.message}`));
