#!/usr/bin/env node
// check-invented.mjs — proves mechanically that invented-backup.json holds nothing real.
//
//   node tools/parity/fixtures/check-invented.mjs [private/<backup>.json] [--show]
//
// Compares every string of the invented backup with every string of the REAL backup
// (which never leaves private/): no whole value may be shared, and no word of five
// letters or more — apart from the model's own vocabulary (category and container
// names, enum values…), which both files hold because the app writes it. Prints counts
// only; --show lists the offenders ON YOUR SCREEN ONLY — they are real strings.
// Exits 1 when anything is shared.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const show = args.includes('--show');
const realPath = args.find((a) => !a.startsWith('--')) || path.join(HERE, '..', '..', '..', 'private', 'migration-2026-09-21.json');
const modelPath = process.env.PARITY_MODEL || path.join(HERE, '..', '..', '..', '..', 'AMS Packing', 'js', 'model.js');
const real = JSON.parse(fs.readFileSync(realPath, 'utf8'));
const inv = JSON.parse(fs.readFileSync(path.join(HERE, 'invented-backup.json'), 'utf8'));
const M = await import(pathToFileURL(path.resolve(modelPath)).href);

const norm = (s) => s.trim().toLowerCase();
const vocab = new Set(['ams-packing-list', 'base', 'transport', 'loose', 'container', 'item', 'reminder', 'trip', 'quick', 'active', 'done', 'todo', 'shopping', 'high', 'normal', 'dark', 'light']);
const addVocab = (v) => { if (typeof v === 'string') vocab.add(norm(v)); else if (Array.isArray(v)) v.forEach(addVocab); else if (v && typeof v === 'object') Object.values(v).forEach(addVocab); };
for (const v of Object.values(M)) if (typeof v !== 'function') addVocab(v);
const stringsOf = (root) => { const out = new Set(); const walk = (v) => { if (typeof v === 'string') { if (norm(v).length >= 3) out.add(norm(v)); } else if (Array.isArray(v)) v.forEach(walk); else if (v && typeof v === 'object') Object.values(v).forEach(walk); }; walk(root); return out; };
const wordsOf = (set) => { const w = new Set(); for (const s of set) for (const x of s.split(/[^\p{L}\p{N}]+/u)) if (x.length >= 5) w.add(x); return w; };

const realS = stringsOf({ ...real, photos: [] });
const invS = stringsOf(inv);
const machine = (s) => /^\d{4}-\d{2}/.test(s) || /^#[0-9a-f]{3,8}$/.test(s);
const sharedValues = [...invS].filter((s) => realS.has(s) && !vocab.has(s) && !machine(s));
const vocabWords = wordsOf(vocab); const realW = wordsOf(realS);
const sharedWords = [...wordsOf(invS)].filter((w) => realW.has(w) && !vocabWords.has(w));
console.log(`real strings ${realS.size} · invented strings ${invS.size} · shared whole values ${sharedValues.length} · shared words ${sharedWords.length}`);
if (show) { console.log(JSON.stringify(sharedValues)); console.log(JSON.stringify(sharedWords)); }
process.exit(sharedValues.length || sharedWords.length ? 1 : 0);
