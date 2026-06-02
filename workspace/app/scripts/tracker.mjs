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
//   add-resume  --posting N --path "rel/path.docx" [--template A] [--pages 1]
//               [--rating 8.5] [--version N]
//   add-cover   --posting N --path "rel/path.docx" [--version N]
//       Register a generated document against a posting.
//
//   list
//       Print all postings (id, status, company — role), one per line.
//
// Exit codes: 0 success, 1 usage/arg error, 2 API/network error, 3 not found.

import { readFileSync } from "node:fs";

const BASE = (process.env.TRACKER_API || "http://localhost:8080").replace(/\/+$/, "");

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

async function cmdAddResume(flags) {
  if (!flags.posting || !flags.path) die(1, "add-resume: --posting and --path required");
  const body = {
    templateUsed: flags.template ?? null,
    filePath: flags.path,
    pageCount: flags.pages != null ? Number(flags.pages) : null,
    selfReviewRating: flags.rating != null ? Number(flags.rating) : null,
    version: flags.version != null ? Number(flags.version) : null,
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

async function cmdList() {
  const all = await api("GET", "/api/postings");
  process.stdout.write(`count: ${all.length}\n`);
  for (const p of all) process.stdout.write(`${p.id}\t${p.status}\t${p.company} — ${p.roleTitle}\n`);
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
  "add-resume": () => cmdAddResume(flags),
  "add-cover": () => cmdAddCover(flags),
  list: cmdList,
};
if (!cmd || !table[cmd]) {
  die(1, `usage: node tracker.mjs <health|find|inbox|get|upsert|set-status|add-resume|add-cover|list> [flags]`);
}
table[cmd]().catch((e) => die(2, `tracker: ${e.message}`));
