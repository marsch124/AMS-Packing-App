#!/usr/bin/env node
// diff-answers.mjs — compare two answers documents (see QUESTIONS.md).
//
//   node tools/parity/diff-answers.mjs a.json b.json [--max 20] [--only <question-prefix>] [--quiet]
//
// Walks both documents, prints every differing path with both values (cut short),
// then a per-question summary, and ends with exactly
//     differences: none        (exit 0)
// or  differences: N           (exit 1)
//
// It compares PARSED values, so key order and whitespace never matter; whole numbers
// must be equal, other numbers equal within 1e-9 (relative for big ones). `_info` is not compared, except that
// the two documents must have been made for the same `today`.
//
// 🚨 The paths it prints contain real item names. Read them; do not paste them into
// anything public.

import fs from 'node:fs';

const argv = process.argv.slice(2);
const files = [];
let maxPerQuestion = 20;
let only = '';
let quiet = false;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--max') maxPerQuestion = Math.max(0, Number(argv[++i]) || 0);
  else if (a === '--only') only = String(argv[++i] || '');
  else if (a === '--quiet') quiet = true;
  else if (a === '-h' || a === '--help') usage(0);
  else if (a.startsWith('--')) { console.error(`Unknown option ${a}`); usage(2); }
  else files.push(a);
}
function usage(code) {
  console.error('usage: node tools/parity/diff-answers.mjs a.json b.json [--max 20] [--only <question-prefix>] [--quiet]');
  process.exit(code);
}
if (files.length !== 2) usage(2);

function load(file) {
  let text;
  try { text = fs.readFileSync(file, 'utf8'); } catch (err) { console.error(`cannot read ${file}: ${err.message}`); process.exit(2); }
  try { return JSON.parse(text); } catch (err) { console.error(`${file} is not valid JSON: ${err.message}`); process.exit(2); }
}
const A = load(files[0]);
const B = load(files[1]);
const answersOf = (doc, file) => {
  if (!doc || typeof doc !== 'object' || !doc.answers || typeof doc.answers !== 'object' || Array.isArray(doc.answers)) {
    console.error(`${file} has no "answers" object — not an answers document.`); process.exit(2);
  }
  return doc.answers;
};
const qa = answersOf(A, files[0]);
const qb = answersOf(B, files[1]);

// --- values -------------------------------------------------------------------
const EPS = 1e-9;
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const kind = (v) => (v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v);
function sameNumber(x, y) {
  if (x === y) return true;
  // Two whole numbers are equal or they are not — counts, ids, the FNV hashes of
  // calc.lzw. (A RELATIVE tolerance would wave through a 32-bit hash that is off by 4.)
  if (Number.isInteger(x) && Number.isInteger(y)) return false;
  return Math.abs(x - y) <= EPS * Math.max(1, Math.abs(x), Math.abs(y));
}
// A short, safe picture of a value: never stringifies a big subtree.
function brief(v, room = 100) {
  if (v === undefined) return '(absent)';
  if (v === null) return 'null';
  if (typeof v === 'string') { const s = JSON.stringify(v); return s.length > room ? `${s.slice(0, room - 1)}…" (${v.length} chars)` : s; }
  if (typeof v !== 'object') return String(v);
  if (Array.isArray(v)) {
    if (!v.length) return '[]';
    const head = brief(v[0], 40);
    return `[${head}${v.length > 1 ? `, … ${v.length} items` : ''}]`;
  }
  const keys = Object.keys(v);
  if (!keys.length) return '{}';
  return `{${keys.slice(0, 4).join(', ')}${keys.length > 4 ? `, … ${keys.length} keys` : ''}}`;
}
// Where the two strings first part ways — the useful bit of a long share code.
function firstSplit(x, y) {
  let i = 0; const n = Math.min(x.length, y.length);
  while (i < n && x.charCodeAt(i) === y.charCodeAt(i)) i++;
  return i;
}
const seg = (k) => (/^[A-Za-z_$][\w$]*$/.test(k) ? `.${k}` : `[${JSON.stringify(k)}]`);

// Iterative walk (an explicit stack), so depth and size are never a problem.
function diffValues(a, b, basePath, report) {
  let count = 0;
  const stack = [[a, b, basePath]];
  while (stack.length) {
    const [x, y, p] = stack.pop();
    if (x === y) continue;
    const kx = kind(x); const ky = kind(y);
    if (x === undefined || y === undefined || kx !== ky) { count++; report(p, x, y); continue; }
    if (kx === 'number') { if (!sameNumber(x, y)) { count++; report(p, x, y); } continue; }
    if (kx === 'string') { count++; report(p, x, y, x.length > 60 || y.length > 60 ? `first differ at char ${firstSplit(x, y)}` : ''); continue; }
    if (kx === 'array') {
      if (x.length !== y.length) { count++; report(`${p}.length`, x.length, y.length); }
      const n = Math.min(x.length, y.length);
      for (let i = n - 1; i >= 0; i--) stack.push([x[i], y[i], `${p}[${i}]`]);
      continue;
    }
    if (kx === 'object') {
      const keys = new Set([...Object.keys(x), ...Object.keys(y)]);
      const sorted = [...keys].sort().reverse();
      for (const k of sorted) stack.push([Object.hasOwn(x, k) ? x[k] : undefined, Object.hasOwn(y, k) ? y[k] : undefined, `${p}${seg(k)}`]);
      continue;
    }
    count++; report(p, x, y);   // booleans that differ
  }
  return count;
}

// --- the walk -----------------------------------------------------------------
const out = [];
const say = (line) => { if (!quiet) out.push(line); };
const flush = () => { if (out.length) { process.stdout.write(`${out.join('\n')}\n`); out.length = 0; } };

const ia = (A._info && typeof A._info === 'object') ? A._info : {};
const ib = (B._info && typeof B._info === 'object') ? B._info : {};
say(`a: ${files[0]}  (${ia.generator || '?'}, today ${ia.today || '?'}, ${Object.keys(qa).length} questions)`);
say(`b: ${files[1]}  (${ib.generator || '?'}, today ${ib.today || '?'}, ${Object.keys(qb).length} questions)`);
say('');

let total = 0;
const summary = [];   // [question, entities, differences, note]
if ((ia.today || '') !== (ib.today || '')) {
  total += 1;
  say(`_info.today\n    a: ${brief(ia.today)}\n    b: ${brief(ib.today)}\n    the two documents were made for different days — most date answers cannot agree`);
  summary.push(['_info.today', 1, 1, 'different days']);
}
for (const k of ['locale', 'contract']) {
  if (ia[k] !== undefined && ib[k] !== undefined && ia[k] !== ib[k]) say(`note: _info.${k} differs (a: ${brief(ia[k])}, b: ${brief(ib[k])}) — not counted`);
}

const questions = [...new Set([...Object.keys(qa), ...Object.keys(qb)])].filter((q) => !only || q.startsWith(only)).sort();
let identical = 0;
for (const q of questions) {
  const ea = qa[q]; const eb = qb[q];
  let n = 0; let shown = 0; let note = '';
  const report = (p, x, y, extra = '') => {
    if (shown < maxPerQuestion) {
      say(`${p}\n    a: ${brief(x)}\n    b: ${brief(y)}${extra ? `\n    ${extra}` : ''}`);
    }
    shown++;
  };
  if (!isObj(ea) || !isObj(eb)) {
    // a whole question is missing on one side: one difference per answer it holds
    const present = isObj(ea) ? ea : (isObj(eb) ? eb : {});
    n = Math.max(1, Object.keys(present).length);
    note = isObj(ea) ? 'missing in b' : 'missing in a';
    say(`${q}\n    ${note} (${n} answer${n === 1 ? '' : 's'})`);
  } else {
    const entities = [...new Set([...Object.keys(ea), ...Object.keys(eb)])].sort();
    for (const e of entities) {
      const base = `${q}${seg(e)}`;
      if (!Object.hasOwn(ea, e) || !Object.hasOwn(eb, e)) { n++; report(base, Object.hasOwn(ea, e) ? ea[e] : undefined, Object.hasOwn(eb, e) ? eb[e] : undefined); continue; }
      n += diffValues(ea[e], eb[e], base, report);
    }
    if (shown > maxPerQuestion) say(`    … and ${shown - maxPerQuestion} more in ${q}`);
  }
  const entityCount = new Set([...Object.keys(isObj(ea) ? ea : {}), ...Object.keys(isObj(eb) ? eb : {})]).size;
  if (n) { summary.push([q, entityCount, n, note]); total += n; } else identical++;
  flush();
}

// --- the summary ----------------------------------------------------------------
const lines = [];
lines.push('');
lines.push('per question');
if (summary.length) {
  const w = Math.max(...summary.map((r) => r[0].length), 8);
  for (const [q, ents, n, note] of summary) lines.push(`  ${q.padEnd(w)}  ${String(n).padStart(7)} difference${n === 1 ? ' ' : 's'} in ${ents} answer${ents === 1 ? '' : 's'}${note ? `  (${note})` : ''}`);
}
lines.push(`  ${identical} of ${questions.length} questions identical`);
lines.push('');
lines.push(total ? `differences: ${total}` : 'differences: none');
process.stdout.write(`${lines.join('\n')}\n`);
process.exit(total ? 1 : 0);
