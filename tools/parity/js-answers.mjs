#!/usr/bin/env node
// js-answers.mjs — the JavaScript half of the AMS Packing PARITY CHECKER.
//
//   node tools/parity/js-answers.mjs <backup.json> [--today 2026-09-21]
//        [--model <path/to/model.js>] [--locale en-US]  > answers.json
//
// Runs the web app's pure model (../AMS Packing/js/model.js, READ-ONLY) over a real
// backup file and writes ONE canonical JSON document of answers to stdout. The
// Swift package answers the same questions; tools/parity/diff-answers.mjs compares
// the two. Every question, its arguments and how its result is written down are
// specified in tools/parity/QUESTIONS.md — that document is the contract, this
// file is its reference implementation. Change one, change the other.
//
// 🚨 PRIVACY. The backup is the owner's real data and this repository is public.
// Send the output into private/ only. Nothing in this file names a real thing.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

// ---------------------------------------------------------------------------
// 0. Arguments
// ---------------------------------------------------------------------------
const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const opts = { today: '2026-09-21', model: process.env.PARITY_MODEL || '', locale: 'en-US', backup: '' };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--today') opts.today = argv[++i];
  else if (a === '--model') opts.model = argv[++i];
  else if (a === '--locale') opts.locale = argv[++i];
  else if (a === '-h' || a === '--help') { usage(0); }
  else if (a.startsWith('--')) { console.error(`Unknown option ${a}`); usage(2); }
  else opts.backup = a;
}
function usage(code) {
  console.error('usage: node tools/parity/js-answers.mjs <backup.json> [--today YYYY-MM-DD] [--model path/to/model.js] [--locale en-US] > answers.json');
  process.exit(code);
}
if (!opts.backup) usage(2);
if (!/^\d{4}-\d{2}-\d{2}$/.test(opts.today)) { console.error('--today must be YYYY-MM-DD'); process.exit(2); }

// ---------------------------------------------------------------------------
// 1. A settled collation. `a.localeCompare(b)` uses the runtime's DEFAULT locale,
//    and Node takes that from the environment (LC_ALL) — 'sv-SE' files å ä ö after
//    z, 'en-US' files them with a and o. The contract fixes it (default en-US, the
//    language his Mac and Safari run in); if this process started under another
//    one, start again under the right one.
// ---------------------------------------------------------------------------
{
  const have = new Intl.Collator().resolvedOptions().locale;
  if (have !== opts.locale && !process.env.PARITY_LOCALE_PINNED) {
    const r = spawnSync(process.execPath, process.argv.slice(1), {
      stdio: 'inherit',
      env: { ...process.env, LC_ALL: `${opts.locale.replace('-', '_')}.UTF-8`, PARITY_LOCALE_PINNED: '1' },
    });
    process.exit(r.status == null ? 1 : r.status);
  }
  if (have !== opts.locale) console.error(`warning: wanted collation locale ${opts.locale}, running under ${have}`);
}

// ---------------------------------------------------------------------------
// 2. A frozen clock. "Now" is <today>T12:00:00.000Z for every function that reads
//    the real clock (nowISO, id(), a missing todayISO…). Installed before the model
//    is imported; the model looks `Date` up at call time, so this is enough.
// ---------------------------------------------------------------------------
const TODAY = opts.today;
const NOW = `${TODAY}T12:00:00.000Z`;
{
  const RealDate = Date;
  const FROZEN = RealDate.parse(NOW);
  class FrozenDate extends RealDate {
    constructor(...a) { if (a.length === 0) super(FROZEN); else super(...a); }
    static now() { return FROZEN; }
  }
  globalThis.Date = FrozenDate;
}

// ---------------------------------------------------------------------------
// 3. The model and the backup
// ---------------------------------------------------------------------------
const modelPath = path.resolve(opts.model || path.join(HERE, '..', '..', '..', 'AMS Packing', 'js', 'model.js'));
if (!fs.existsSync(modelPath)) { console.error(`model not found: ${modelPath}`); process.exit(2); }
const M = await import(pathToFileURL(modelPath).href);
const B = JSON.parse(fs.readFileSync(path.resolve(opts.backup), 'utf8'));
if (!B || typeof B !== 'object' || !(Array.isArray(B.lists) || Array.isArray(B.events))) {
  console.error('That file does not look like an AMS Packing backup.'); process.exit(2);
}

// ---------------------------------------------------------------------------
// 4. Small tools
// ---------------------------------------------------------------------------
const asArr = (v) => (Array.isArray(v) ? v : []);
const nonEmptyArr = (v) => Array.isArray(v) && v.length > 0;
const clone = (v) => structuredClone(v);
const str = (v) => (typeof v === 'string' ? v : (v == null ? '' : String(v)));
const cmpCodeUnit = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // JS `<` on strings IS UTF-16 code-unit order
const distinct = (arr) => [...new Set(arr)];
const ID = '<id>';
const NOWMARK = '<now>';

// Canonical value: see QUESTIONS.md §2.
function canon(v) {
  if (v === undefined || typeof v === 'function' || typeof v === 'symbol') return undefined;
  if (v === null) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? (Object.is(v, -0) ? 0 : v) : null;
  if (typeof v === 'string' || typeof v === 'boolean') return v;
  if (typeof v === 'bigint') return Number(v);
  if (v instanceof Set) return [...v].map(canon).sort(cmpCodeUnit);
  if (v instanceof Map) { const o = Object.create(null); for (const [k, x] of v) { const c = canon(x); if (c !== undefined) o[String(k)] = c; } return o; }
  if (ArrayBuffer.isView(v)) return Array.from(v);
  if (Array.isArray(v)) return v.map((x) => { const c = canon(x); return c === undefined ? null : c; });
  const o = Object.create(null);
  for (const k of Object.keys(v)) { const c = canon(v[k]); if (c !== undefined) o[k] = c; }
  return o;
}
// Canonical JSON TEXT: keys in UTF-16 code-unit order, no whitespace, strings and
// numbers exactly as JSON.stringify writes them. (Not JSON.stringify of the whole
// thing: a JS object always lists integer-like keys first, which is not an order.)
function CJ(v) {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'number') return Number.isFinite(v) ? JSON.stringify(Object.is(v, -0) ? 0 : v) : 'null';
  if (typeof v === 'string' || typeof v === 'boolean') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(CJ).join(',')}]`;
  const keys = Object.keys(v).filter((k) => v[k] !== undefined).sort(cmpCodeUnit);
  return `{${keys.map((k) => `${JSON.stringify(k)}:${CJ(v[k])}`).join(',')}}`;
}
const utf8 = (s) => new TextEncoder().encode(s);
function fnv1a(bytes) { let h = 2166136261; for (const b of bytes) { h ^= b; h = Math.imul(h, 16777619) >>> 0; } return h >>> 0; }

// ---------------------------------------------------------------------------
// 5. Shapes — the fixed key sets every entity is written down with (§3)
// ---------------------------------------------------------------------------
const ITEM_NORMALISED = [
  'seasons', 'contexts', 'transports', 'catering', 'weather', 'sub', 'phase', 'category', 'itemType',
  'charging', 'chargeType', 'shortList', 'swedish', 'stats', 'weight', 'liquid', 'restricted', 'perNight',
  'consumable', 'section', 'kit', 'packer', 'storage', 'photos', 'thumb', 'maintenance', 'color', 'size',
  'manufacturer', 'model', 'ownedBy', 'acquired', 'price', 'currency', 'purchaseLink', 'expiry', 'condition',
  'retired', 'retiredReason', 'serial', 'qtyOwned', 'warranty', 'capacityL', 'maxKg',
];
const ITEM_STRINGS = ['id', 'name', 'qty', 'container', 'note', 'sourceListId', 'sourceItemId'];
const ITEM_BOOLS = ['custom', 'checked', 'skipped', '_edited', 'keep'];
const ITEM_OPT_BOOL = ['used'];
const ITEM_OPT_STR = ['_ovContainer', '_tplContainer', '_defContainer', '_ovPhase', '_defPhase', '_itemId', '_memId'];
const ITEM_KEYS = new Set([...ITEM_NORMALISED, ...ITEM_STRINGS, ...ITEM_BOOLS, ...ITEM_OPT_BOOL, ...ITEM_OPT_STR]);

// A sub-item is a NAME. The web app's trip bundle mangles a string sub-item into a
// character map ({"0":"a","1":"b"}); the contract writes it back as the string, so
// the Swift side is not asked to reproduce that. See QUESTIONS.md §3.1 and §9.
function subShape(s) {
  if (typeof s === 'string') return s;
  if (s && typeof s === 'object' && !Array.isArray(s)) {
    const idx = Object.keys(s).filter((k) => /^(0|[1-9]\d*)$/.test(k)).sort((a, b) => Number(a) - Number(b));
    if (idx.length) return idx.map((k) => String(s[k])).join('');
  }
  return canon(s);
}
function shapeItem(it, map = {}) {
  if (!it || typeof it !== 'object') return canon(it);
  const o = {};
  for (const k of ITEM_NORMALISED) o[k] = k === 'sub' ? asArr(it.sub).map(subShape) : it[k];
  for (const k of ITEM_STRINGS) o[k] = str(it[k]);
  for (const k of ITEM_BOOLS) o[k] = !!it[k];
  for (const k of ITEM_OPT_BOOL) if (typeof it[k] === 'boolean') o[k] = it[k];
  for (const k of ITEM_OPT_STR) if (typeof it[k] === 'string') o[k] = it[k];
  if (map.id) { o.id = map.id(o.id); if ('_itemId' in o) o._itemId = map.id(o._itemId); }
  if (map.mem && '_memId' in o) o._memId = map.mem(o._memId);
  if (map.section) o.section = map.section(o.section);
  if (map.dropId) delete o.id;
  return o;
}
function shapeSlimEntry(o) {   // an entry as a trip bundle carries it: only the keys that are there
  const out = {};
  for (const k of Object.keys(o || {})) {
    if (!ITEM_KEYS.has(k)) continue;
    out[k] = k === 'sub' ? asArr(o.sub).map(subShape) : o[k];
  }
  return out;
}
const shapeSection = (s, map = {}) => ({ id: map.sectionId ? map.sectionId(s.id) : str(s.id), name: str(s.name) });
function shapeList(l, map = {}) {
  if (!l || typeof l !== 'object') return canon(l);
  return {
    id: map.listId ? map.listId(str(l.id)) : str(l.id), name: str(l.name), emoji: l.emoji, color: l.color,
    sections: asArr(l.sections).map((s) => shapeSection(s, map)),
    group: l.group, role: l.role, transport: l.transport, defaultContainer: l.defaultContainer,
    builtin: !!l.builtin,
    createdAt: map.stamps ? NOWMARK : str(l.createdAt), updatedAt: map.stamps ? NOWMARK : str(l.updatedAt),
    items: asArr(l.items).map((it) => shapeItem(it, map)),
  };
}
function shapeEvent(e, map = {}, entryShape = (x) => shapeItem(x, map.entry || {})) {
  if (!e || typeof e !== 'object') return canon(e);
  return {
    id: map.eventId ? ID : str(e.id), name: str(e.name), mode: e.mode, activities: e.activities,
    transport: str(e.transport), season: str(e.season), contexts: e.contexts, weatherOn: e.weatherOn,
    catering: str(e.catering), startDate: str(e.startDate), endDate: e.endDate, nights: e.nights,
    laundry: e.laundry, destination: e.destination, weather: e.weather, geo: e.geo,
    entries: asArr(e.entries).map(entryShape),
    status: e.status, reviewedAt: e.reviewedAt, generatedAt: str(e.generatedAt),
    createdAt: map.stamps ? NOWMARK : str(e.createdAt), updatedAt: map.stamps ? NOWMARK : str(e.updatedAt),
  };
}
const shapeAction = (a) => ({
  id: str(a.id), text: a.text, kind: a.kind, itemId: a.itemId, itemName: a.itemName, priority: a.priority,
  whenPhase: a.whenPhase, whenDate: a.whenDate, done: a.done, doneAt: a.doneAt, createdAt: a.createdAt, updatedAt: a.updatedAt,
});
const shapeKit = (k) => ({ id: str(k.id), name: k.name, emoji: k.emoji, note: k.note, itemIds: k.itemIds, createdAt: k.createdAt, updatedAt: k.updatedAt });
const shapePhase = (p) => (p ? { id: p.id, label: p.label, hint: p.hint, emoji: p.emoji, color: p.color, task: p.task, leadDays: p.leadDays, order: p.order } : null);
const shapeCondition = (c) => (c ? { id: c.id, label: c.label, tone: c.tone, replace: c.replace } : null);
const shapePerson = (p, minted = false) => ({ id: minted ? ID : str(p.id), name: p.name, color: p.color });
const shapeMembership = (m, map = {}) => ({
  id: map.mem ? map.mem(str(m.id)) : str(m.id), itemId: map.id ? map.id(str(m.itemId)) : str(m.itemId), templateId: str(m.templateId),
  seasons: m.seasons, contexts: m.contexts, transports: m.transports, catering: m.catering, weather: m.weather,
  container: m.container, section: m.section, kit: m.kit, phase: m.phase, itemType: m.itemType, qty: m.qty, note: m.note, order: m.order,
});
const shapeRow = (r) => ({ id: r.id, kind: r.kind, key: r.key, name: r.name, order: r.order, data: r.data });

// The identifying tuples used inside grouping results (§3.9).
const entryRef = (e) => [str(e && e.sourceItemId), str(e && e.name), str(e && e.container), str(e && e.phase)].join('|');
const buildRef = (e) => `${str(e && e.sourceListId)}|${entryRef(e)}`;
const itemRef = (it) => `${str(it && it.id)}|${str(it && it.name)}`;
const refs = (arr) => asArr(arr).map(entryRef);

// ---------------------------------------------------------------------------
// 6. Setup (§4) — in this order, exactly as a restore feeds the model
// ---------------------------------------------------------------------------
const prefs = (B.prefs && typeof B.prefs === 'object') ? B.prefs : {};
const RAW = { lists: clone(asArr(B.lists)), events: clone(asArr(B.events)), actions: clone(asArr(B.actions)), kits: clone(asArr(B.kits)), things: clone(asArr(B.things)), phases: clone(asArr(B.phases)) };

// 6.1 The sync layer's bookkeeping is not data. `realmId` goes everywhere; `owner`
// goes everywhere EXCEPT on an item-shaped record with no string `ownedBy`, where
// coerceItem's legacy rule still has to see it (it is deleted after coercion).
const strip = (o, keepOwner = false) => { if (o && typeof o === 'object') { delete o.realmId; if (!keepOwner) delete o.owner; } };
const stripItem = (it) => strip(it, !!it && typeof it === 'object' && typeof it.ownedBy !== 'string');
for (const l of RAW.lists) { strip(l); for (const it of asArr(l && l.items)) stripItem(it); }
for (const e of RAW.events) { strip(e); for (const it of asArr(e && e.entries)) stripItem(it); }
for (const a of RAW.actions) strip(a);
for (const k of RAW.kits) strip(k);
for (const t of RAW.things) stripItem(t);

// Keys in the data that no shape carries — reported in _info, never compared.
const unknownKeys = { list: new Set(), item: new Set(), event: new Set(), entry: new Set(), action: new Set(), kit: new Set(), phase: new Set() };
const LIST_KEYS = new Set(['id', 'name', 'emoji', 'color', 'sections', 'group', 'role', 'transport', 'defaultContainer', 'builtin', 'createdAt', 'updatedAt', 'items']);
const EVENT_KEYS = new Set(['id', 'name', 'mode', 'activities', 'transport', 'season', 'contexts', 'weatherOn', 'catering', 'startDate', 'endDate', 'nights', 'laundry', 'destination', 'weather', 'geo', 'entries', 'status', 'reviewedAt', 'generatedAt', 'createdAt', 'updatedAt']);
const ACTION_KEYS = new Set(['id', 'text', 'kind', 'itemId', 'itemName', 'priority', 'whenPhase', 'whenDate', 'done', 'doneAt', 'createdAt', 'updatedAt']);
const KIT_KEYS = new Set(['id', 'name', 'emoji', 'note', 'itemIds', 'createdAt', 'updatedAt']);
const PHASE_KEYS = new Set(['id', 'label', 'hint', 'emoji', 'color', 'task', 'leadDays', 'order']);
const note = (bucket, o, known) => { for (const k of Object.keys(o || {})) if (!known.has(k)) unknownKeys[bucket].add(k); };
for (const l of RAW.lists) { note('list', l, LIST_KEYS); for (const it of asArr(l && l.items)) note('item', it, ITEM_KEYS); }
for (const e of RAW.events) { note('event', e, EVENT_KEYS); for (const it of asArr(e && e.entries)) note('entry', it, ITEM_KEYS); }
for (const a of RAW.actions) note('action', a, ACTION_KEYS);
for (const k of RAW.kits) note('kit', k, KIT_KEYS);
for (const p of RAW.phases) note('phase', p, PHASE_KEYS);

// 6.2 Phases first (applyBackup does the same), then the conditions from prefs.
{
  const incoming = RAW.phases.map((p, i) => M.coercePhase(clone(p), i)).filter((p) => p.id && p.label);
  M.setPhases(incoming.length ? incoming : []);
}
if (nonEmptyArr(prefs.conditions)) M.setItemConditions(clone(prefs.conditions)); else M.setItemConditions([]);

// 6.3 The Settings lists in force.
const CONDITIONS_IN = nonEmptyArr(prefs.conditions) ? clone(prefs.conditions) : M.DEFAULT_ITEM_CONDITIONS.map((c) => ({ ...c }));
const PEOPLE_IN = nonEmptyArr(prefs.people) ? clone(prefs.people) : M.DEFAULT_PEOPLE.map((p) => ({ ...p }));
const PLACES_IN = nonEmptyArr(prefs.storageLocations) ? clone(prefs.storageLocations) : M.DEFAULT_STORAGE_LOCATIONS.slice();
const OWNERS_IN = nonEmptyArr(prefs.owners) ? clone(prefs.owners) : [];
const PEOPLE = M.peopleFromRows(M.peopleToRows(clone(PEOPLE_IN)));
const PEOPLE_NAMES = PEOPLE.map((p) => p.name);

// 6.4 Coerce everything once. These are the inputs of every later question, and
// every question works on its OWN deep copy (the model mutates what it is given).
const dropOwner = (it) => { if (it && typeof it === 'object') delete it.owner; return it; };
const LISTS = clone(RAW.lists).map((l) => { const c = M.coerceList(l); asArr(c && c.items).forEach(dropOwner); return c; });
const EVENTS = clone(RAW.events).map((e) => { const c = M.coerceEvent(e); asArr(c && c.entries).forEach(dropOwner); return c; });
const ACTIONS = clone(RAW.actions).map((a) => M.coerceAction(a));
const KITS = clone(RAW.kits).map((k) => M.coerceKit(k));
const THINGS = clone(RAW.things).map((t) => dropOwner(M.coerceItem(t))).filter((t) => t && typeof t === 'object');

// 6.5 The synthetic overlays (§5) — real data as the base, deterministic changes on
// top, so questions the real data leaves empty still have something to answer.
const ITEM_ORDER = new Map();   // item id -> k, first appearance across LISTS
for (const l of LISTS) for (const it of asArr(l.items)) if (!ITEM_ORDER.has(it.id)) ITEM_ORDER.set(it.id, ITEM_ORDER.size);
function synthLists() {
  const lists = clone(LISTS);
  for (const l of lists) for (const it of asArr(l.items)) {
    const k = ITEM_ORDER.get(it.id);
    if (k % 5 === 0) it.expiry = M.addDays(TODAY, (k % 120) - 40);
    if (k % 7 === 1) it.condition = M.ITEM_CONDITION_IDS[k % M.ITEM_CONDITION_IDS.length];
    else if (k % 13 === 3) it.condition = 'mystery';
    if (k % 6 === 0) it.consumable = true;
    if (k % 17 === 5) it.retired = true;
    if (k % 8 === 2) {
      it.maintenance = {
        notes: 'Synthetic care note', link: '', intervalDays: [30, 90, 182, 365, 0][k % 5],
        lastDone: (k % 3 === 0) ? '' : M.addDays(TODAY, -((k * 7) % 400)), log: [],
      };
    }
    if (k % 10 === 4) it.stats = { packed: k % 4, used: (k % 3 === 0) ? 0 : 1, unused: 0, skipped: k % 3, lastReviewed: '' };
  }
  return lists;
}
function synthEvent(ev) {
  const e = clone(ev);
  e.entries.forEach((x, i) => {
    if (i % 5 === 0) x.expiry = M.addDays(TODAY, (i % 120) - 40);
    if (i % 4 === 1 && PEOPLE_NAMES.length) x.packer = PEOPLE_NAMES[Math.floor(i / 4) % PEOPLE_NAMES.length];
    else if (i % 11 === 2) x.packer = 'Zed Guest';
    else if (i % 11 === 6) x.packer = 'amy guest';
    if (i % 6 === 2) x.kit = `Kit ${'ABC'[Math.floor(i / 6) % 3]}`;
    x.skipped = (i % 9 === 4);
    x.checked = (i % 2 === 0);
    x.used = (i % 3 !== 0);
  });
  return e;
}
function synthActions() {
  const items = [...ITEM_ORDER.keys()].slice(0, 12);
  const byId = new Map(); for (const l of LISTS) for (const it of asArr(l.items)) if (!byId.has(it.id)) byId.set(it.id, it);
  return items.map((iid, i) => M.coerceAction({
    id: `synth-action-${i}`, text: `Synthetic ${i}`, kind: i % 3 === 0 ? 'shopping' : 'todo',
    itemId: iid, itemName: str(byId.get(iid).name), priority: i % 2 === 0 ? 'high' : 'normal',
    whenPhase: i % 4 === 1 ? (M.PHASE_IDS[i % M.PHASE_IDS.length] || '') : (i % 4 === 2 ? 'no-such-phase' : ''),
    whenDate: i % 4 === 0 ? M.addDays(TODAY, i) : '',
    done: i % 5 === 0, doneAt: i % 5 === 0 ? NOW : '',
    createdAt: `${M.addDays('2026-01-01', i % 7)}T00:00:00.000Z`, updatedAt: `${M.addDays('2026-01-01', i % 7)}T00:00:00.000Z`,
  }));
}

// ---------------------------------------------------------------------------
// 7. Asking
// ---------------------------------------------------------------------------
const answers = Object.create(null);
function ask(key, entity, fn) {
  let v;
  try { v = fn(); } catch (err) { v = { $error: String((err && err.message) || err) }; }
  const c = canon(v);
  if (!answers[key]) answers[key] = Object.create(null);
  answers[key][String(entity)] = c === undefined ? null : c;
}
const ALL = '*';

// === §6 Setup state ==========================================================
ask('setup.phases', ALL, () => ({
  phases: M.PHASES.map(shapePhase), ids: M.PHASE_IDS.slice(), customised: M.phasesCustomised(), defaultPhaseId: M.defaultPhaseId(),
}));
ask('setup.conditions', ALL, () => ({ conditions: M.ITEM_CONDITIONS.map(shapeCondition), ids: M.ITEM_CONDITION_IDS.slice() }));
ask('setup.people', ALL, () => PEOPLE.map((p) => shapePerson(p)));
RAW.phases.forEach((p, i) => ask('coerce.phase', i, () => shapePhase(M.coercePhase(clone(p), i))));
CONDITIONS_IN.forEach((c, i) => ask('coerce.condition', i, () => shapeCondition(M.coerceCondition(clone(c)))));
PEOPLE_IN.forEach((p, i) => ask('coerce.person', i, () => {
  const minted = !(p && typeof p.id === 'string' && p.id);
  return shapePerson(M.coercePerson({ ...(p && typeof p === 'object' ? clone(p) : {}) }), minted);
}));

// === §7 Coercion — whole objects ============================================
RAW.lists.forEach((raw, i) => ask('coerce.list', str(raw && raw.id) || `#${i}`, () => {
  const l = clone(raw);
  // a section that arrived without an id has one minted: write that one down by position
  const known = new Set(asArr(l.sections).map((s) => ((s && typeof s.id === 'string' && s.id) ? s.id : null)).filter(Boolean));
  const c = M.coerceList(l);
  const minted = new Map();
  c.sections.forEach((s, j) => { if (!known.has(s.id)) minted.set(s.id, `S${j}`); });
  asArr(c.items).forEach(dropOwner);
  return shapeList(c, { sectionId: (x) => minted.get(x) || x });
}));
RAW.events.forEach((raw, i) => ask('coerce.event', str(raw && raw.id) || `#${i}`, () => shapeEvent(M.coerceEvent(clone(raw)))));
RAW.actions.forEach((raw, i) => ask('coerce.action', str(raw && raw.id) || `#${i}`, () => {
  const o = shapeAction(M.coerceAction(clone(raw)));
  if (typeof raw.createdAt !== 'string') { o.createdAt = NOWMARK; if (typeof raw.updatedAt !== 'string') o.updatedAt = NOWMARK; }
  return o;
}));
RAW.kits.forEach((raw, i) => ask('coerce.kit', str(raw && raw.id) || `#${i}`, () => shapeKit(M.coerceKit(clone(raw)))));
RAW.things.forEach((raw, i) => ask('coerce.thing', str(raw && raw.id) || `#${i}`, () => shapeItem(dropOwner(M.coerceItem(clone(raw))))));

// === §8 Per list =============================================================
const listKey = (l, i) => str(l.id) || `#${i}`;
LISTS.forEach((L0, i) => {
  const k = listKey(L0, i);
  ask('list.cover', k, () => {
    const l = clone(L0);
    return {
      emoji: M.listEmoji(l), color: M.listColor(l),
      hashedById: M.listColor({ id: l.id, name: l.name }), hashedByName: M.listColor({ name: l.name }),
      contextApplies: M.contextApplies(l), defaults: M.templateDefaults(l), groupLabel: M.groupLabel(l.group),
    };
  });
  ask('list.sectionNames', k, () => { const l = clone(L0); return l.items.map((it) => M.sectionName(l, it.section)); });
  ask('list.groupItemsBySection', k, () => {
    const l = clone(L0);
    return M.groupItemsBySection(l.items, l.sections).map((g) => ({ section: g.section ? shapeSection(g.section) : null, items: g.items.map(itemRef) }));
  });
  ask('list.photos', k, () => {
    const l = clone(L0);
    return { hasInline: M.hasInlinePhotos(l.items), refs: l.items.reduce((n, it) => n + M.photoRefs(it).length, 0), inline: l.items.reduce((n, it) => n + M.inlinePhotos(it).length, 0) };
  });
  // Share round trip: the code itself, what it decodes to, and the template it becomes.
  let code = null;
  ask('list.share.encoded', k, () => { code = M.encodeListShare(clone(L0)); return code; });
  if (typeof code === 'string') {
    ask('list.share.decoded', k, () => {
      const d = M.decodeListShare(`https://example.invalid/app/#/l/${code}`);
      for (const it of d.items) delete it.owner;   // legacy key, always '' once §4.1 has run
      return d;
    });
    ask('list.share.imported', k, () => {
      const made = M.listFromShare(M.decodeListShare(code));
      const secIds = new Map(made.sections.map((s, j) => [s.id, `S${j}`]));
      return shapeList(made, {
        listId: () => ID, stamps: true, sectionId: (x) => secIds.get(x) || x,
        id: () => ID, section: (x) => (x ? (secIds.get(x) || x) : ''),
      });
    });
  }
});

// === §9 Per event ============================================================
const NIGHTS_PROBE = 7;
const byName = (a, b) => String((a && a.name) || '').localeCompare(String((b && b.name) || ''), undefined, { sensitivity: 'base' });
const ENTRY_SORTS = [
  ['name', (r) => r.name, { tie: null }], ['storage', (r) => r.storage, { tie: byName }],
  ['container', (r) => r.container, { tie: byName }], ['weight', (r) => r.weight, { num: true, tie: byName }],
];
const ENTRY_GROUPS = () => [
  ['category', (r) => r.category, { order: M.CATEGORIES }], ['container', (r) => r.container, { order: M.CONTAINERS }],
  ['storage', (r) => r.storage, {}], ['packer', (r) => r.packer, { order: PEOPLE_NAMES, emptyLabel: 'Anyone' }],
];
const eventKey = (e, i) => str(e.id) || `#${i}`;
const bundleShape = (b) => ({ app: b.app, kind: b.kind, version: b.version, exportedAt: b.exportedAt, event: shapeEvent(b.event, {}, shapeSlimEntry) });
const importedEventShape = (ev) => shapeEvent(ev, { eventId: true, stamps: true, entry: { id: () => ID } });

EVENTS.forEach((E0, i) => {
  const k = eventKey(E0, i);
  const ev = () => clone(E0);
  const lists = () => clone(LISTS);

  ask('event.listsForEvent', k, () => M.listsForEvent(ev(), lists()).map((l) => l.id));
  ask('event.matchCounts', k, () => {
    const e = ev(); const out = {};
    for (const l of lists()) out[l.id] = l.items.filter((it) => M.itemMatchesEvent(it, e, l)).length;
    return out;
  });
  ask('event.buildTotalEntries', k, () => M.buildTotalEntries(ev(), lists()).map((x) => shapeItem(x, { dropId: true })));
  ask('event.buildTotalEntries.weatherAll', k, () => {
    const e = ev(); e.weatherOn = M.WEATHER_CONDITION_IDS.slice();
    return M.buildTotalEntries(e, lists()).map(buildRef);
  });
  ask('event.regenerateEntries', k, () => {
    const e = ev(); const had = new Set(e.entries.map((x) => x.id));
    return M.regenerateEntries(e, lists()).map((x) => `${entryRef(x)}|${had.has(x.id) ? x.id : '<new>'}`);
  });

  // grouping — real entries, then the synthetic overlay
  for (const [suffix, make] of [['', ev], ['.synth', () => synthEvent(E0)]]) {
    ask(`event.entriesByPhase${suffix}`, k, () => M.entriesByPhase(make().entries).map((g) => ({ phase: shapePhase(g.phase), entries: refs(g.entries) })));
    for (const mode of ['category', 'container', 'section', 'stored', 'when']) {
      ask(`event.groupBy.${mode}${suffix}`, k, () => M.groupBy(mode, make().entries).map((g) => ({ label: g.label, hint: g.hint, entries: refs(g.entries) })));
    }
    ask(`event.progress${suffix}`, k, () => { const e = make(); return { progress: M.progress(e.entries), packable: M.packable(e.entries).length, setAside: e.entries.filter((x) => M.isSetAside(x)).length }; });
    ask(`event.packSteps${suffix}`, k, () => M.packSteps(make().entries).map((s) => ({ phase: s.phase.id, total: s.total, done: s.done, remaining: s.remaining, entries: refs(s.entries) })));
    ask(`event.assignedPeople${suffix}`, k, () => M.assignedPeople(make().entries));
    ask(`event.groupByPacker${suffix}`, k, () => M.groupByPacker(make().entries, PEOPLE_NAMES).map((g) => ({ packer: g.packer, entries: refs(g.entries) })));
    ask(`event.clusterByKit${suffix}`, k, () => M.clusterByKit(make().entries).map((g) => ({ kit: g.kit, entries: refs(g.entries) })));
    ask(`event.expiringOnTrip${suffix}`, k, () => {
      const e = make();
      const end = M.tripEndDate(e) || M.addDays(TODAY, 14);
      return M.expiringOnTrip(e.entries, end, TODAY).map((r) => ({ entry: entryRef(r.entry), expiry: r.expiry, alreadyOut: r.alreadyOut, daysLeft: r.daysLeft }));
    });
    ask(`event.bagLoads${suffix}`, k, () => { const e = make(); return M.bagLoads(e.entries, M.qtyNights(e), M.containerLimits(lists())); });
    ask(`event.packingFlags${suffix}`, k, () => { const e = make(); return M.packingFlags(e.entries, M.qtyNights(e)); });
    ask(`event.tripNudge${suffix}`, k, () => M.tripNudge(make(), TODAY));
  }
  ask('event.groupByContainer', k, () => M.groupByContainer(ev().entries).map((g) => ({ container: g.container, entries: refs(g.entries) })));
  ask('event.groupByCategory', k, () => M.groupByCategory(ev().entries).map((g) => ({ category: g.category, entries: refs(g.entries) })));
  ask('event.groupBySection', k, () => M.groupBySection(ev().entries).map((g) => ({ label: g.label, entries: refs(g.entries) })));
  ask('event.groupByStorage', k, () => M.groupByStorage(ev().entries).map((g) => ({ label: g.label, entries: refs(g.entries) })));
  for (const [name, valOf, o] of ENTRY_SORTS) for (const dir of ['asc', 'desc']) {
    ask(`event.sortRowsBy.${name}.${dir}`, k, () => refs(M.sortRowsBy(ev().entries, valOf, { ...o, dir })));
  }
  for (const [name, keyOf, o] of ENTRY_GROUPS()) {
    ask(`event.groupRowsBy.${name}`, k, () => M.groupRowsBy(synthEvent(E0).entries, keyOf, o).map((g) => ({ key: g.key, label: g.label, rows: refs(g.rows) })));
  }

  // quantities and weight
  ask('event.qtyNights', k, () => M.qtyNights(ev()));
  ask('event.effectiveQty', k, () => {
    const e = ev(); const n = M.qtyNights(e); const out = {};
    e.entries.forEach((x, j) => { out[str(x.id) || `#${j}`] = [M.effectiveQty(x, n), M.effectiveQty(x, 0), M.effectiveQty(x, NIGHTS_PROBE)]; });
    return out;
  });
  ask('event.bagLoads.n7', k, () => M.bagLoads(ev().entries, NIGHTS_PROBE));
  ask('event.packingFlags.n7', k, () => M.packingFlags(ev().entries, NIGHTS_PROBE));

  // dates
  ask('event.dates', k, () => {
    const e = ev(); const d = M.daysUntil(e.startDate, TODAY);
    return {
      daysUntil: d, countdown: M.countdownLabel(d), nightsBetween: M.nightsBetween(e.startDate, e.endDate),
      tripEndDate: M.tripEndDate(e), endFromNights: M.endFromNights(e.startDate, e.nights),
      monthKeyStart: M.monthKey(e.startDate), monthKeyEnd: M.monthKey(e.endDate),
      orderRange: M.orderRange(e.startDate, e.endDate), orderRangeReversed: M.orderRange(e.endDate, e.startDate),
    };
  });
  ask('event.tripNudge.sweep', k, () => {
    const e = synthEvent(E0); const out = {};
    const start = e.startDate || TODAY; e.startDate = start;
    for (const d of [40, 30, 8, 7, 2, 1, 0, -1]) out[String(d)] = M.tripNudge(e, M.addDays(start, -d));
    return out;
  });
  ask('event.rangeCells', k, () => {
    const e = ev(); const key = M.monthKey(e.startDate);
    if (!key) return null;
    return M.monthGrid(key, 1).days.map((d) => M.rangeCellState(d.iso, e.startDate, e.endDate));
  });

  // weather and place
  ask('event.deriveWeather', k, () => M.deriveWeather(ev()));
  ask('event.weatherGear', k, () => M.weatherGear(ev(), lists()));
  ask('event.pendingWeatherItems', k, () => M.pendingWeatherItems(ev(), lists()));
  ask('event.weatherSuggestions', k, () => M.weatherSuggestions(ev(), lists()));
  ask('event.weatherSuggestions.synth', k, () => {
    // a fixed forecast laid over the trip: one wet cool day, one hot windy one, one snowy one
    const e = ev(); const d0 = e.startDate || TODAY;
    e.entries = [];
    e.weather = M.coerceEvent({ weather: { place: 'Testville, XX', lat: 12.25, lon: -12.25, fetchedAt: NOW, daily: [
      { date: d0, code: 61, tmax: 12.5, tmin: 4.5, precipProb: 80, wind: 10 },
      { date: M.addDays(d0, 1), code: 1, tmax: 27.5, tmin: 15.49, precipProb: 49.5, wind: 35 },
      { date: M.addDays(d0, 2), code: 73, tmax: -0.5, tmin: -2.5, precipProb: 0, wind: 34.4 },
    ] } }).weather;
    return { derived: M.deriveWeather(e), suggestions: M.weatherSuggestions(e, lists()), coords: M.eventCoords(e) };
  });
  ask('event.eventCoords', k, () => M.eventCoords(ev()));

  // export and sharing
  ask('event.totalListRows', k, () => M.totalListRows(ev(), lists()));
  let bundleCanon = null;
  ask('event.tripBundle', k, () => { bundleCanon = canon(bundleShape(M.buildTripBundle(ev(), NOW))); return bundleCanon; });
  ask('event.tripBundle.parsed', k, () => importedEventShape(M.parseTripBundle(JSON.stringify(M.buildTripBundle(ev(), NOW)))));
  ask('event.tripLink', k, () => {
    const link = M.encodeTripLink(ev(), NOW);
    if (link === null) return { fits: false, roundTrip: null };
    return { fits: true, prefix: link.slice(0, 4), roundTrip: importedEventShape(M.decodeTripLink(link.slice(4))) };
  });
  if (bundleCanon && !bundleCanon.$error) {
    ask('event.packedCanonical', k, () => {
      const text = CJ(bundleCanon); const packed = M.packShare(text);
      return { packed, textLength: text.length, roundTrip: M.unpackShare(`${packed}.`) === text };
    });
  }

  // presets and the review
  ask('event.presetConfig', k, () => M.presetConfigFromEvent(ev()));
  ask('event.applyPresetConfig', k, () => {
    const target = ev(); const donor = clone(EVENTS[(i + 1) % EVENTS.length]);
    const out = M.applyPresetConfig(target, M.presetConfigFromEvent(donor));
    return M.presetConfigFromEvent(out);
  });
  const review = (e) => {
    const ls = lists();
    const changed = M.applyReview(e, ls, NOW);
    const stats = {};
    for (const l of changed) { stats[l.id] = {}; for (const it of l.items) if (it.stats && it.stats.lastReviewed === NOW) stats[l.id][it.id] = it.stats; }
    const prune = (minTrips) => M.pruneSuggestions(ls, { minTrips }).map((p) => ({ listId: p.listId, listName: p.listName, item: itemRef(p.item), stats: p.stats, reason: p.reason, times: p.times }));
    return { changed: changed.map((l) => l.id), stats, prune1: prune(1), prune2: prune(2) };
  };
  ask('event.applyReview.real', k, () => review(ev()));
  ask('event.applyReview.synth', k, () => review(synthEvent(E0)));
  ask('event.applyReview.synthUnticked', k, () => { const e = synthEvent(E0); e.entries.forEach((x) => { x.checked = false; }); return review(e); });
  ask('event.itemFromEntry', k, () => {
    const e = ev(); const out = {};
    e.entries.forEach((x, j) => { if (j < 10 || x.custom) out[String(j)] = shapeItem(M.itemFromEntry(x), { id: () => ID }); });
    return out;
  });
});

// === §10 Probe trips — one dimension moved at a time =========================
{
  const tickable = LISTS.filter((l) => !l.role).map((l) => l.id);
  const base = { id: 'probe', name: 'Probe', mode: 'trip', activities: tickable, transport: 'Car', season: 'Summer', contexts: [], weatherOn: [], catering: 'mixed', entries: [] };
  const probes = [['baseline', {}]];
  for (const s of M.SEASONS) probes.push([`season=${s}`, { season: s }]);
  for (const t of M.TRANSPORTS) probes.push([`transport=${t}`, { transport: t }]);
  for (const c of M.CATERING) probes.push([`catering=${c.id}`, { catering: c.id }]);
  for (const c of M.CONTEXTS) probes.push([`contexts=${c}`, { contexts: [c] }]);
  probes.push(['contexts=Indoor+Race', { contexts: ['Indoor', 'Race'] }]);
  probes.push(['mode=quick', { mode: 'quick' }]);
  probes.push(['weatherOn=all', { weatherOn: M.WEATHER_CONDITION_IDS.slice() }]);
  probes.push(['activities=reversed', { activities: tickable.slice().reverse() }]);
  for (const [name, patch] of probes) {
    ask('probe.buildTotalEntries', name, () => M.buildTotalEntries(M.coerceEvent({ ...clone(base), ...clone(patch) }), clone(LISTS)).map(buildRef));
  }
  ask('probe.weatherGear', 'baseline', () => M.weatherGear(M.coerceEvent(clone(base)), clone(LISTS)));
}

// === §11 The whole library ===================================================
ask('library.containerNames', ALL, () => M.containerNames(clone(LISTS)));
ask('library.containerLimits', ALL, () => M.containerLimits(clone(LISTS)));
ask('library.backupCounts', ALL, () => M.backupCounts({ lists: clone(LISTS), events: clone(EVENTS), actions: clone(ACTIONS) }));
for (const gid of [...M.GROUP_IDS, '']) {
  ask('library.orderActivities', gid, () => M.orderActivities(gid, clone(LISTS).filter((l) => l.group === gid && !l.role)).map((l) => l.id));
}
ask('library.orderActivities', 'WET-reversed', () => M.orderActivities('WET', clone(LISTS).filter((l) => l.group === 'WET' && !l.role).reverse()).map((l) => l.id));

// --- the relational core: fold into a catalogue, resolve back -----------------
const CAT = M.buildCatalog(clone(LISTS));    // ids are minted: written down by position
const itemPos = new Map(CAT.items.map((it, n) => [it.id, `I${n}`]));
const memPos = new Map(CAT.memberships.map((m, n) => [m.id, `M${n}`]));
const catMap = { id: (x) => itemPos.get(x) || x, mem: (x) => memPos.get(x) || x };
ask('library.buildCatalog.items', ALL, () => CAT.items.map((it) => shapeItem(it, catMap)));
ask('library.buildCatalog.memberships', ALL, () => CAT.memberships.map((m) => shapeMembership(m, catMap)));
ask('library.buildCatalog.templates', ALL, () => CAT.templates.map((t) => shapeList(t)));
CAT.templates.forEach((t, i) => {
  ask('library.resolveTemplate', listKey(t, i), () => shapeList(M.resolveTemplate(clone(t), clone(CAT.items), clone(CAT.memberships)), catMap));
  ask('library.resolveTemplate.drift', listKey(t, i), () => {
    const back = M.resolveTemplate(clone(t), clone(CAT.items), clone(CAT.memberships)).items;
    const orig = LISTS[i].items.filter((it) => String(it.name || '').trim());
    const fields = ['name', 'container', 'phase', 'itemType', 'qty', 'note', 'section', 'seasons', 'contexts', 'transports', 'catering', 'weather', 'category', 'weight', 'storage', 'swedish', 'packer', 'ownedBy'];
    const drift = [];
    orig.forEach((o, j) => {
      const b = back[j] || {};
      const diff = fields.filter((f) => CJ(canon(o[f])) !== CJ(canon(b[f])));
      if (diff.length) drift.push({ index: j, fields: diff });
    });
    return { original: orig.length, resolved: back.length, drift };
  });
});
CAT.templates.forEach((t, i) => ask('library.resolveTemplateItems', listKey(t, i), () => {
  // the same resolve, handed the catalogue as a Map and the memberships back to front
  const byId = new Map(clone(CAT.items).map((it) => [it.id, it]));
  return M.resolveTemplateItems(clone(t), byId, clone(CAT.memberships).reverse()).map((it) => `${catMap.id(it.id)}|${str(it.name)}|${str(it.container)}|${str(it.phase)}`);
}));
ask('library.resolveItemAlone', ALL, () => CAT.items.slice(0, 25).map((c) => shapeItem(M.resolveItemAlone(clone(c)), catMap)));
ask('library.applyIntrinsic', ALL, () => CAT.items.slice(0, 25).map((c) => {
  let src = null;
  for (const l of LISTS) { src = l.items.find((it) => M.normName(it.name) === M.normName(c.name)); if (src) break; }
  return shapeItem(M.applyIntrinsic(clone(c), clone(src)), catMap);
}));
ask('library.planContainerMigration', ALL, () => planShape(M.planContainerMigration(clone(CAT.items), clone(CAT.memberships), clone(CAT.templates))));
ask('library.planContainerMigration.legacy', ALL, () => {
  // the pre-v108 shape: every real choice an override, every default frozen
  const items = clone(CAT.items); const mems = clone(CAT.memberships); const tpls = clone(CAT.templates);
  const byId = new Map(items.map((it) => [it.id, it]));
  const tplDef = new Map(tpls.map((t) => [t.id, M.templateDefaults(t).container]));
  for (const m of mems) m.container = m.container || tplDef.get(m.templateId) || (byId.get(m.itemId) || {}).container || '';
  for (const it of items) it.container = 'Carry-on / hand luggage';
  return planShape(M.planContainerMigration(items, mems, tpls));
});
function planShape(p) {
  const mapKeys = (m, pos) => { const o = {}; for (const [k, v] of m) o[pos.get(k) || k] = v; return o; };
  return {
    defaults: mapKeys(p.defaults, itemPos), effective: mapKeys(p.effective, memPos),
    itemChanges: p.itemChanges.map((c) => ({ id: itemPos.get(c.id) || c.id, container: c.container })),
    memChanges: p.memChanges.map((c) => ({ id: memPos.get(c.id) || c.id, container: c.container })),
  };
}
// the save path: one resolved item -> catalogue item + membership -> resolved again
LISTS.forEach((L0, i) => {
  const k = listKey(L0, i);
  ask('library.decompose', k, () => {
    const l = clone(L0); let order = 0; const out = [];
    for (const it of l.items) {
      if (!String(it.name || '').trim()) continue;
      const cat = M.catalogItemFromResolved(it);
      const m = M.membershipFromResolved(cat, l.id, it, order++);
      const back = M.resolveMembership(cat, m, M.templateDefaults(l));
      out.push({ membership: shapeMembership(m, { id: () => ID, mem: () => ID }), resolved: shapeItem(back, { id: () => ID }) });
    }
    return out;
  });
  ask('library.decompose.inferred', k, () => {
    const l = clone(L0); let order = 0; const out = [];
    for (const it of l.items) {
      if (!String(it.name || '').trim()) continue;
      const cat = M.catalogItemFromResolved(it);
      const bare = { ...it }; delete bare._ovContainer; delete bare._ovPhase;
      bare._tplContainer = M.templateDefaults(l).container;
      out.push(shapeMembership(M.membershipFromResolved(cat, l.id, bare, order++), { id: () => ID, mem: () => ID }));
    }
    return out;
  });
  ask('library.containerOverrideFor', k, () => {
    const l = clone(L0);
    return l.items.map((it) => M.containerOverrideFor(it.container, M.templateDefaults(l).container, typeof it._defContainer === 'string' ? it._defContainer : ''));
  });
  const next = LISTS[(i + 1) % LISTS.length];
  ask('library.mapSectionAcrossTemplates', `${k}>${listKey(next, (i + 1) % LISTS.length)}`, () => {
    const a = clone(L0); const b = clone(next); const out = {};
    for (const s of a.sections) out[s.id] = M.mapSectionAcrossTemplates(s.id, a, b);
    out['(unknown)'] = M.mapSectionAcrossTemplates('no-such-section', a, b);
    out['(blank)'] = M.mapSectionAcrossTemplates('', a, b);
    return out;
  });
  ask('library.linkFromResolved', k, () => {
    const a = clone(L0); const b = clone(next);
    const it = a.items[0];
    if (!it) return null;
    const link = M.linkFromResolved(it, it._itemId || it.id, { section: M.mapSectionAcrossTemplates(it.section, a, b) });
    const o = {};
    for (const f of ['_itemId', '_link', 'name', ...M.CONTEXTUAL_FIELDS, 'section', '_ovContainer', '_ovPhase']) o[f] = link[f];
    return o;
  });
});
ask('library.containerDefaultsFrom', ALL, () => {
  const rows = []; for (const l of clone(LISTS)) for (const it of l.items) rows.push({ itemId: it.id, container: it.container });
  return M.containerDefaultsFrom(rows);
});

// --- the overview, duplicates, care, shopping ---------------------------------
const catalogueRows = (lists) => M.catalogRows(lists, clone(THINGS));
ask('library.catalogRows', ALL, () => catalogueRows(clone(LISTS)).map((r) => ({ id: r.id, name: r.name, item: itemRef(r.item), templates: r.templates })));
ask('library.duplicateGroups', ALL, () => M.duplicateGroups(catalogueRows(clone(LISTS))).map((g) => ({ key: g.key, exact: g.exact, rows: g.rows.map((r) => r.id) })));
ask('library.duplicateIds', ALL, () => M.duplicateIds(catalogueRows(clone(LISTS))));
const ROW_SORTS = [
  ['name', (r) => r.item.name, { tie: null }], ['manufacturer', (r) => r.item.manufacturer, { tie: byName }],
  ['storage', (r) => r.item.storage, { tie: byName }], ['weight', (r) => r.item.weight, { num: true, tie: byName }],
  ['price', (r) => r.item.price, { num: true, tie: byName }],
];
for (const [name, valOf, o] of ROW_SORTS) for (const dir of ['asc', 'desc']) {
  ask(`library.sortRowsBy.${name}.${dir}`, ALL, () => M.sortRowsBy(catalogueRows(clone(LISTS)), valOf, { ...o, dir }).map((r) => r.id));
}
for (const [name, keyOf, o] of [['category', (r) => r.item.category, { order: M.CATEGORIES }], ['storage', (r) => r.item.storage, { order: PLACES_IN }], ['ownedBy', (r) => r.item.ownedBy, {}], ['condition', (r) => M.itemConditionLabel(r.item.condition), { order: M.ITEM_CONDITIONS.map((c) => c.label) }]]) {
  ask(`library.groupRowsBy.${name}`, ALL, () => M.groupRowsBy(catalogueRows(synthLists()), keyOf, o).map((g) => ({ key: g.key, label: g.label, rows: g.rows.map((r) => r.id) })));
}
const SYNTH_ACTIONS = synthActions();
for (const [suffix, makeLists, makeActions] of [['', () => clone(LISTS), () => clone(ACTIONS)], ['.synth', synthLists, () => clone(SYNTH_ACTIONS)]]) {
  const maintRow = (r) => ({ listId: r.listId, listName: r.listName, listNames: r.listNames, item: itemRef(r.item), status: r.status });
  ask(`library.maintenanceList${suffix}`, ALL, () => M.maintenanceList(makeLists(), TODAY).map(maintRow));
  ask(`library.maintenanceStatus${suffix}`, ALL, () => {
    const o = {};
    for (const r of catalogueRows(makeLists())) if (M.hasCare(r.item)) o[r.id] = M.maintenanceStatus(r.item, TODAY);
    return o;
  });
  ask(`library.careSections${suffix}`, ALL, () => M.careSections(M.maintenanceList(makeLists(), TODAY)).map((s) => ({ key: s.key, state: s.state, label: s.label, fold: s.fold, rows: s.rows.map((r) => str(r.item.id)) })));
  ask(`library.maintenanceSummary${suffix}`, ALL, () => M.maintenanceSummary(makeLists(), TODAY));
  ask(`library.maintenanceByDate${suffix}`, ALL, () => { const o = {}; for (const [d, rows] of M.maintenanceByDate(makeLists(), TODAY)) o[d] = rows.map((r) => str(r.item.id)); return o; });
  ask(`library.logMaintenance${suffix}`, ALL, () => {
    const out = {};
    for (const r of M.maintenanceList(makeLists(), TODAY)) out[str(r.item.id)] = M.logMaintenance(clone(r.item), TODAY, 'parity').maintenance;
    return out;
  });
  ask(`library.shoppingSuggestions${suffix}`, ALL, () => M.shoppingSuggestions(catalogueRows(makeLists()).map((r) => r.item), makeActions(), TODAY).map((s) => ({ item: itemRef(s.item), reason: s.reason })));
  ask(`library.shoppingReason${suffix}`, ALL, () => { const o = {}; for (const r of catalogueRows(makeLists())) { const why = M.shoppingReason(r.item, TODAY); if (why) o[r.id] = why; } return o; });
  ask(`library.openShoppingCount${suffix}`, ALL, () => M.openShoppingCount(makeActions()));
  ask(`library.compareActions${suffix}`, ALL, () => makeActions().sort(M.compareActions).map((a) => a.id));
  ask(`library.pruneSuggestions${suffix}`, ALL, () => [1, 2].map((minTrips) => M.pruneSuggestions(makeLists(), { minTrips }).map((p) => ({ listId: p.listId, item: itemRef(p.item), reason: p.reason, times: p.times }))));
}

// --- does this device hold the whole copy? ------------------------------------
{
  const inForce = () => ({ places: clone(PLACES_IN), owners: clone(OWNERS_IN), conditions: M.ITEM_CONDITIONS.map((c) => ({ ...c })), people: clone(PEOPLE), phases: M.PHASES.map((p) => ({ ...p })) });
  const referenced = () => M.referencedListValues({ lists: clone(LISTS), events: clone(EVENTS), actions: clone(ACTIONS) });
  ask('library.referencedListValues', ALL, () => {
    const r = referenced(); const o = { display: {} };
    for (const kind of M.AUDITABLE_KINDS) { o[kind] = r[kind]; o.display[kind] = r.display[kind]; }
    return o;
  });
  for (const kind of [...M.AUDITABLE_KINDS, 'presets']) ask('library.auditList', kind, () => M.auditList(kind, referenced(), inForce()[kind]));
  ask('library.auditDeviceLists', 'signedIn', () => M.auditDeviceLists({ referenced: referenced(), inForce: inForce(), signedIn: true, hasCatalogue: true }));
  ask('library.auditDeviceLists', 'signedOut', () => M.auditDeviceLists({ referenced: referenced(), inForce: inForce(), signedIn: false, hasCatalogue: true }));
  ask('library.auditDeviceLists', 'emptyLists', () => M.auditDeviceLists({ referenced: referenced(), inForce: { places: [], owners: [], conditions: [], people: [], phases: [] }, signedIn: true, hasCatalogue: true }));
}

// --- events as a set -----------------------------------------------------------
{
  const todays = distinct([TODAY, ...EVENTS.flatMap((e) => { const end = M.tripEndDate(e); return end ? [M.addDays(end, 0), M.addDays(end, 1), M.addDays(end, 30), M.addDays(end, 31)] : []; })]).filter(Boolean).sort(cmpCodeUnit);
  for (const t of todays) {
    ask('library.sortEventsForList', t, () => M.sortEventsForList(clone(EVENTS), t).map((e) => e.id));
    ask('library.tripsAwaitingReview', t, () => M.tripsAwaitingReview(clone(EVENTS), t).map((r) => ({ event: r.event.id, endedDaysAgo: r.endedDaysAgo })));
  }
  ask('library.tripsAwaitingReview', `${TODAY}/window=365`, () => M.tripsAwaitingReview(clone(EVENTS), TODAY, 365).map((r) => ({ event: r.event.id, endedDaysAgo: r.endedDaysAgo })));
  const withPlaces = () => clone(EVENTS).map((e, i) => {
    if (M.eventCoords(e)) return e;
    // quarter-degree coordinates on purpose: toFixed(1) on an exact tie is where runtimes part ways
    e.geo = M.coerceGeo({ lat: 12.25 + (i % 2) * 0.5, lon: -(12.25 + (i % 2) * 0.5), place: i % 2 ? 'Testville, XX' : '' });
    if (i % 2 === 0) e.destination = '';   // no label at all, so the pin is keyed by its rounded coordinates
    return e;
  });
  const placeShape = (p) => (p ? { key: p.key, place: p.place, lat: p.lat, lon: p.lon, events: p.events.map((e) => e.id) } : null);
  for (const [suffix, make] of [['', () => clone(EVENTS)], ['.synth', withPlaces]]) {
    ask(`library.eventsNeedingCoords${suffix}`, ALL, () => M.eventsNeedingCoords(make()).map((e) => e.id));
    ask(`library.placesVisited${suffix}`, ALL, () => M.placesVisited(make()).map(placeShape));
    ask(`library.tripPath${suffix}`, ALL, () => M.tripPath(make()));
    ask(`library.mostVisited${suffix}`, ALL, () => placeShape(M.mostVisited(M.placesVisited(make()))));
  }
  ask('library.mostVisited.doubled', ALL, () => placeShape(M.mostVisited(M.placesVisited([...withPlaces(), ...withPlaces()]))));
}

// --- backup reminders -----------------------------------------------------------
{
  const groups = () => [clone(EVENTS), clone(LISTS), clone(ACTIONS), clone(KITS)];
  ask('library.backupClock', ALL, () => ({ newest: M.newestChangeAt(...groups()), oldest: M.oldestCreatedAt(...groups()) }));
  const changedAt = M.newestChangeAt(...groups()); const firstUseAt = M.oldestCreatedAt(...groups());
  const cases = {
    exportedAt: str(B.exportedAt), never: '', 'today-13': `${M.addDays(TODAY, -13)}T08:00:00.000Z`, 'today-14': `${M.addDays(TODAY, -14)}T08:00:00.000Z`,
    'today-45': `${M.addDays(TODAY, -45)}T08:00:00.000Z`, 'date-only': M.addDays(TODAY, -20), future: `${M.addDays(TODAY, 3)}T08:00:00.000Z`,
  };
  for (const [name, lastBackupAt] of Object.entries(cases)) {
    ask('library.backupState', name, () => M.backupState({ lastBackupAt, changedAt, firstUseAt, hasData: true, now: NOW }));
  }
  ask('library.backupState', 'noData', () => M.backupState({ lastBackupAt: '', changedAt, firstUseAt, hasData: false, now: NOW }));
  ask('library.backupState', 'clock', () => M.backupState({ lastBackupAt: '', changedAt: '', firstUseAt: '', hasData: true }));
}

// === §12 The Settings lists and their shared rows ============================
{
  const GRAB_IN = (() => {
    const g = (prefs.grab && typeof prefs.grab === 'object') ? prefs.grab : {};
    const items = (g.items && typeof g.items === 'object') ? g.items : {};
    const meta = (g.meta && typeof g.meta === 'object') ? g.meta : {};
    return distinct([...Object.keys(items), ...Object.keys(meta)]).sort(cmpCodeUnit).map((gid) => ({
      id: gid, items: asArr(items[gid]), label: str(meta[gid] && meta[gid].label), icon: str(meta[gid] && meta[gid].icon), tone: str(meta[gid] && meta[gid].tone),
    }));
  })();
  const PRESETS_IN = [
    ...(nonEmptyArr(prefs.presets) ? clone(prefs.presets) : []),
    ...EVENTS.map((e, i) => ({ name: `Preset ${i + 1}`, createdAt: str(e.createdAt), config: M.presetConfigFromEvent(clone(e)) })),
    { name: '  preset 1 ', createdAt: '', config: { mode: 'quick' } },   // same name, other spelling: must be dropped
    { name: 'No config' },                                                // must be dropped
  ];
  const inputs = { conditions: CONDITIONS_IN, people: PEOPLE_IN, places: PLACES_IN, owners: OWNERS_IN, presets: PRESETS_IN, grab: GRAB_IN };
  const allRows = () => M.SHARED_KINDS.flatMap((kind) => M.sharedRowsFrom(kind, clone(inputs[kind])));
  for (const kind of M.SHARED_KINDS) {
    ask('settings.rows', kind, () => M.sharedRowsFrom(kind, clone(inputs[kind])).map(shapeRow));
    ask('settings.rowsOfKind', kind, () => M.sharedRowsOfKind(allRows().reverse(), kind).map((r) => r.id));
    ask('settings.isFactoryList', kind, () => ({ inForce: M.isFactoryList(kind, clone(inputs[kind])), factory: M.isFactoryList(kind, M.defaultListFor(kind)), defaultList: M.defaultListFor(kind) }));
  }
  ask('settings.back', 'conditions', () => M.conditionsFromRows(allRows().reverse()).map(shapeCondition));
  ask('settings.back', 'people', () => M.peopleFromRows(allRows().reverse()).map((p) => shapePerson(p)));
  ask('settings.back', 'places', () => ({ ordered: M.orderedNamesFromRows(allRows().reverse(), 'places'), az: M.namesFromRows(allRows().reverse(), 'places') }));
  ask('settings.back', 'owners', () => ({ ordered: M.orderedNamesFromRows(allRows().reverse(), 'owners'), az: M.namesFromRows(allRows().reverse(), 'owners') }));
  ask('settings.back', 'presets', () => M.presetsFromRows(allRows().reverse()));
  ask('settings.back', 'grab', () => M.grabFromRows(allRows().reverse()));
  ask('settings.ownersByUsage', ALL, () => {
    const seen = new Map(); const spelling = new Map();
    for (const l of LISTS) for (const it of l.items) {
      const key = M.normName(it.ownedBy); if (!key) continue;
      if (!seen.has(key)) { seen.set(key, new Set()); spelling.set(key, it.ownedBy.trim()); }
      seen.get(key).add(it._itemId || it.id);
    }
    const counts = new Map([...seen].map(([k2, set]) => [k2, set.size]));
    const names = OWNERS_IN.length ? OWNERS_IN.map((v) => (typeof v === 'string' ? v : str(v && v.name))) : [...spelling.values()];
    return { counts, order: M.ownersByUsage(names, counts) };
  });
  GRAB_IN.forEach((g) => {
    ask('settings.grabShare', g.id, () => {
      const code = M.encodeGrabShare({ name: g.label || g.id, icon: g.icon, tone: g.tone, items: clone(g.items) });
      return { code, decoded: M.decodeGrabShare(`Try this: https://example.invalid/#/g/${code}.`) };
    });
  });
}

// === §13 Every real string, and every id ======================================
const FIXED_STRINGS = ['', '  Mixed   CASE  ', 'Sun-glasses', 'sunglasses', 'Sun glasses', 'Glass', 'Boss', 'Socks', 'ÅÄÖ åäö', 'Tab\tand\nnewline', 'e\u0301 combining', '😀 emoji 👍🏽', 'nbsp\u00a0\u00a0gap', '\ufeffbom lead', 'nel\u0085\u0085gap', 'thin\u2009\u2009gap\u2028', 'İstanbul ǅ ß', '½ litre №5'];
const POOL = (() => {
  const s = new Set(FIXED_STRINGS);
  const add = (v) => { if (typeof v === 'string' && v) s.add(v); };
  for (const l of LISTS) { add(l.name); add(l.defaultContainer); for (const sec of l.sections) add(sec.name); for (const it of l.items) for (const f of ['name', 'swedish', 'storage', 'ownedBy', 'packer', 'kit', 'container', 'category']) add(it[f]); }
  for (const e of EVENTS) { add(e.name); add(e.destination); for (const it of e.entries) for (const f of ['name', 'swedish', 'storage', 'ownedBy', 'packer', 'kit', 'container', 'category', 'section']) add(it[f]); }
  for (const a of ACTIONS) { add(a.text); add(a.itemName); }
  for (const k of KITS) add(k.name);
  for (const t of THINGS) add(t.name);
  for (const v of [...PLACES_IN, ...OWNERS_IN]) add(typeof v === 'string' ? v : (v && v.name));
  for (const p of PEOPLE) add(p.name);
  return [...s].sort(cmpCodeUnit);
})();
for (const s of POOL) {
  ask('strings.normName', s, () => M.normName(s));
  ask('strings.dupeKey', s, () => M.dupeKey(s));
}
ask('strings.collation', 'variant', () => POOL.slice().sort((a, b) => a.localeCompare(b)));
ask('strings.collation', 'base', () => POOL.slice().sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })));
// The same comparisons one pair at a time, so a collation difference points at the
// two strings involved instead of shifting a thousand positions in the lists above.
POOL.forEach((s, i) => ask('strings.compare', s, () => {
  const sign = (n) => (n < 0 ? -1 : n > 0 ? 1 : 0);
  return [1, 37].map((step) => {
    const other = POOL[(i + step) % POOL.length];
    return { with: other, variant: sign(s.localeCompare(other)), base: sign(s.localeCompare(other, undefined, { sensitivity: 'base' })) };
  });
}));
{
  const SHORT = distinct([...FIXED_STRINGS, ...LISTS.map((l) => str(l.name)), ...LISTS.flatMap((l) => l.sections.map((s) => s.name))]).sort(cmpCodeUnit);
  for (const s of SHORT) ask('strings.share', s, () => {
    const b64 = M.toBase64Url(s); const packed = M.packShare(s);
    return { b64, back: M.fromBase64Url(b64) === s, packed, unpacked: M.unpackShare(packed) === s };
  });
  for (const label of distinct([...LISTS.map((l) => str(l.name)), ...M.PHASES.map((p) => p.label), '!!!', 'Ärlig Test 2'])) {
    // a name with no a–z / 0–9 in it earns a clock-made id: written down as a marker
    const noSlug = !/[a-z0-9]/.test(String(label).trim().toLowerCase());
    ask('strings.newPhase', label, () => {
      const p = shapePhase(M.newPhase(label, M.PHASE_IDS.slice(), { leadDays: 3 }));
      if (noSlug) p.id = '<time-id>';
      return p;
    });
    ask('strings.newCondition', label, () => {
      const c = M.newCondition(label, M.ITEM_CONDITION_IDS.slice());
      if (noSlug) c.id = '<time-id>';
      return c;
    });
  }
  const EMAILS = ['anna.berg@example.com', 'm.s@example.org', 'x@y.z', 'first_last+tag@example.com', '  spaced.name@example.com ', 'UPPER.case@example.com', 'élan.vital@example.com', '-lead@example.com', 'noatsign', 'two@@example.com', 'a b@example.com', ''];
  for (const e of [...EMAILS, ...PEOPLE_NAMES]) ask('strings.email', e, () => ({ looksLikeEmail: M.looksLikeEmail(e), ownerName: M.ownerNameFromEmail(e) }));
  const names = distinct([...PEOPLE_NAMES, 'Zed Guest', 'amy guest', 'Åsa', '', ...LISTS.flatMap((l) => l.items.flatMap((it) => [it.packer, it.ownedBy])), ...EVENTS.flatMap((e) => e.entries.flatMap((it) => [it.packer, it.ownedBy]))].filter((v) => typeof v === 'string')).sort(cmpCodeUnit);
  for (const n of names) ask('strings.personColor', n, () => ({ roster: M.personColor(n, clone(PEOPLE)), hashed: M.personColor(n, []) }));
  const qtys = distinct(['', '2', '0', '-1', '2.5', 'abc', ' 3 ', '1e2', '0x10', 'Infinity', '3 pairs', '١٢', ...LISTS.flatMap((l) => l.items.map((it) => str(it.qty))), ...EVENTS.flatMap((e) => e.entries.map((it) => str(it.qty)))]).sort(cmpCodeUnit);
  for (const q of qtys) ask('strings.qty', q, () => [M.effectiveQty({ qty: q }, 0), M.effectiveQty({ qty: q, perNight: true }, 0), M.effectiveQty({ qty: q, perNight: true }, 5)]);
}
{
  const phaseIds = distinct(['', 'no-such-phase', ...M.DEFAULT_PHASES.map((p) => p.id), ...M.PHASE_IDS, ...LISTS.flatMap((l) => l.items.map((it) => it.phase)), ...EVENTS.flatMap((e) => e.entries.map((it) => it.phase)), ...ACTIONS.map((a) => a.whenPhase)]).sort(cmpCodeUnit);
  for (const p of phaseIds) ask('ids.phase', p, () => ({ known: !!M.phase(p), label: M.phaseLabel(p), emoji: M.phaseEmoji(p), color: M.phaseColor(p), leadDays: M.phaseLeadDays(p), order: M.phaseOrder(p), fallback: shapePhase(M.phaseOrFallback(p)) }));
  const condIds = distinct(['', 'mystery', ...M.DEFAULT_ITEM_CONDITIONS.map((c) => c.id), ...M.ITEM_CONDITION_IDS, ...LISTS.flatMap((l) => l.items.map((it) => it.condition))]).sort(cmpCodeUnit);
  for (const c of condIds) ask('ids.condition', c, () => ({ known: !!M.itemCondition(c), label: M.itemConditionLabel(c), tone: M.conditionTone(c), replaces: M.conditionReplaces(c) }));
  const chargeIds = distinct(['bogus', ...M.CHARGE_TYPE_IDS, ...LISTS.flatMap((l) => l.items.map((it) => it.chargeType))]).sort(cmpCodeUnit);
  for (const c of chargeIds) ask('ids.chargeType', c, () => ({ id: M.chargeType(c).id, label: M.chargeTypeLabel(c), short: M.chargeTypeShort(c) }));
  ask('ids.labels', ALL, () => {
    const o = {};
    for (const c of [...M.CATERING.map((x) => x.id), 'bogus']) o[`catering:${c}`] = M.cateringLabel(c);
    for (const g of [...M.GROUP_IDS, '', 'bogus']) { o[`group:${g}`] = M.groupLabel(g); o[`groupHint:${g}`] = (M.group(g) || { hint: null }).hint; }
    for (const kind of M.SHARED_KINDS) o[`rowId:${kind}`] = M.sharedRowId(kind, '  Garage   SHELF ');
    for (const r of [...M.RETIRE_REASON_IDS, '', 'bogus']) o[`retire:${r}`] = M.retireReasonLabel(r);
    for (const p of [...M.ACTION_PRIORITY_IDS, '', 'bogus']) o[`priority:${p}`] = M.actionPriorityLabel(p);
    for (const kit of [{ emoji: ' 🎒 ' }, { emoji: '' }, {}]) o[`kitEmoji:${CJ(kit)}`] = M.kitEmoji(kit);
    for (const level of ['urgent', 'due', 'ok']) o[`snooze:${level}`] = M.backupSnoozeDays(level);
    return o;
  });
  for (let c = -1; c <= 100; c++) ask('ids.weatherCode', c, () => M.weatherCode(c));
}

// === §14 Fixed calculations — the same on any data ============================
ask('calc.constants', ALL, () => {
  const skip = new Set(['PHASES', 'PHASE_IDS', 'ITEM_CONDITIONS', 'ITEM_CONDITION_IDS']);
  const o = {};
  for (const [name, v] of Object.entries(M)) if (typeof v !== 'function' && !skip.has(name)) o[name] = v;
  return o;
});
ask('calc.constructors', ALL, () => {
  const mem = M.newMembership();
  return {
    newItem: shapeItem(M.newItem(), { id: () => ID }),
    newItemNamed: shapeItem(M.newItem({ name: 'Test socks', qty: '2', weight: 40, phase: 'door', perNight: true }), { id: () => ID }),
    newList: shapeList(M.newList({ name: 'Test list', sections: [{ id: '', name: ' Tools ' }, { id: '', name: '' }, { id: 'keep-me', name: 'Kept' }, { id: 'keep-me', name: 'Twin' }] }), { listId: () => ID, stamps: true, sectionId: (x) => (x === 'keep-me' ? x : ID) }),
    newEvent: shapeEvent(M.newEvent({ name: 'Test trip', nights: 3, mode: 'quick', weatherOn: ['rain', 'fog'] }), { eventId: true, stamps: true }),
    newAction: { ...shapeAction(M.newAction({ text: 'Test', priority: 'urgent', whenDate: '2026-1-1' })), id: ID, createdAt: NOWMARK, updatedAt: NOWMARK },
    newKit: { ...shapeKit(M.newKit({ name: 'Test kit', itemIds: ['a', 'b', 'a', ''] })), id: ID, createdAt: NOWMARK, updatedAt: NOWMARK },
    newPerson: shapePerson(M.newPerson({ name: '  Test  ', color: 'blue' }), true),
    newMembership: shapeMembership(mem, { mem: () => ID }),
    newSection: { id: ID, name: M.newSection('  Tools ').name },
  };
});
// Hostile input, decoded from JSON TEXT so both sides start from the same bytes. This
// is where "decoding is coercion" is proved on shapes the real backup never holds.
{
  const HOSTILE = {
    item: '{"id":"x","name":"Hostile","seasons":"Summer","weather":["rain","fog",3],"phase":7,"category":"","itemType":"task","chargeType":"usb-d","stats":{"packed":2.9,"used":-1,"unused":"3","lastReviewed":5},"weight":"12","liquid":1,"section":null,"photos":["a","",null,"b","c","d","e","f"],"maintenance":{"notes":3,"intervalDays":90.7,"lastDone":"2026-1-1","log":[{"date":"2026-02-01","note":1},{"date":"nope"},{"date":"2025-12-31","note":"older"}]},"owner":"Legacy Owner","acquired":"2026-02-3","price":-1,"condition":"  worn-out-and-then-some-more-text-to-cut-at-forty  ","retired":"yes","retiredReason":"stolen","qtyOwned":2.9,"capacityL":null,"maxKg":"7","sub":"nope"}',
    itemLegacyPhoto: '{"id":"y","name":"Legacy photo","photo":"ref-legacy","owner":"someone@example.com","maintenance":{"notes":"","link":"","intervalDays":0},"phase":"   "}',
    itemOwnedByWins: '{"id":"z","name":"Owned","ownedBy":"","owner":"Legacy Owner"}',
    membership: '{"id":"m","itemId":"i","templateId":"t","seasons":"x","weather":["cold","mist"],"container":5,"phase":"  door ","itemType":"task","qty":3,"note":null,"order":"2"}',
    action: '{"id":"a","text":5,"kind":"buy","priority":"urgent","whenPhase":"  week  ","whenDate":"2026-9-1","done":"yes","createdAt":"2026-01-01T00:00:00.000Z"}',
    kit: '{"id":"k","name":7,"emoji":"  ","itemIds":["a","a",3,"","b"]}',
    event: '{"id":"e","mode":"fast","activities":"x","nights":2.7,"laundry":"","status":"finished","weather":{"daily":[{"date":"2026-09-01","code":"61","tmax":"20.5","tmin":null,"precipProb":"x"},{"code":1}],"lat":"58.5","lon":null,"place":3},"weatherOn":["snow","sleet"],"geo":{"lat":"95","lon":0},"entries":[{"name":"In a hostile event"}]}',
    eventNoWeather: '{"id":"e2","nights":-1,"weather":{"daily":[]},"geo":{"lat":"12.5","lon":"-7","place":"Testville"}}',
    list: '{"id":"l","name":"Hostile list","group":"XX","role":"special","transport":"Boat","emoji":"  \ud83d\udce6\ud83d\udce6\ud83d\udce6  ","color":"red","defaultContainer":4,"sections":[{"id":"s1","name":" A "},{"id":"s1","name":"B"},{"id":"s2","name":"  "}],"items":[{"name":"Inside"}]}',
  };
  ask('calc.coerceHostile', 'item', () => shapeItem(dropOwner(M.coerceItem(JSON.parse(HOSTILE.item)))));
  ask('calc.coerceHostile', 'itemLegacyPhoto', () => shapeItem(dropOwner(M.coerceItem(JSON.parse(HOSTILE.itemLegacyPhoto)))));
  ask('calc.coerceHostile', 'itemOwnedByWins', () => shapeItem(dropOwner(M.coerceItem(JSON.parse(HOSTILE.itemOwnedByWins)))));
  ask('calc.coerceHostile', 'membership', () => shapeMembership(M.coerceMembership(JSON.parse(HOSTILE.membership))));
  ask('calc.coerceHostile', 'action', () => shapeAction(M.coerceAction(JSON.parse(HOSTILE.action))));
  ask('calc.coerceHostile', 'kit', () => shapeKit(M.coerceKit(JSON.parse(HOSTILE.kit))));
  ask('calc.coerceHostile', 'event', () => shapeEvent(M.coerceEvent(JSON.parse(HOSTILE.event))));
  ask('calc.coerceHostile', 'eventNoWeather', () => shapeEvent(M.coerceEvent(JSON.parse(HOSTILE.eventNoWeather))));
  ask('calc.coerceHostile', 'list', () => shapeList(M.coerceList(JSON.parse(HOSTILE.list))));
  ask('calc.coerceHostile', 'maintenance', () => M.normalizeMaintenance(JSON.parse('{"notes":"Wax it","link":7,"intervalDays":"30","lastDone":"2026-03-01","log":[{"date":"2026-03-01","note":"b"},{"date":"2026-03-01","note":"a"},null]}')));
  ask('calc.coerceHostile', 'sections', () => M.normalizeSections(JSON.parse('[{"id":"a","name":" One "},{"id":"a","name":"Twin"},{"id":"b"},{"id":"c","name":7},"text",{"id":"d","name":"Four"}]')));
  ask('calc.coerceHostile', 'sharedRow', () => shapeRow(M.coerceSharedRow(JSON.parse('{"kind":"nonsense","key":"  Some   KEY ","name":"  N  ","order":"3","data":[1,2]}'), 4)));
  ask('calc.coerceHostile', 'sharedRowNull', () => shapeRow(M.coerceSharedRow(null, 2)));
  ask('calc.coerceHostile', 'phase', () => shapePhase(M.coercePhase(JSON.parse('{"id":" x ","label":" L ","leadDays":400.6,"order":"2","color":"#12","emoji":"  ","task":1}'), 3)));
  ask('calc.coerceHostile', 'phaseLeadHalf', () => shapePhase(M.coercePhase(JSON.parse('{"id":"h","label":"Half","leadDays":-0.5,"color":"#ABCDEF12"}'), 13)));
  ask('calc.coerceHostile', 'condition', () => shapeCondition(M.coerceCondition(JSON.parse('{"id":" c ","label":" L ","tone":"loud","replace":1}'))));
  ask('calc.coerceHostile', 'person', () => shapePerson(M.coercePerson(JSON.parse('{"name":"  P ","color":"#GGG"}')), true));
}
ask('calc.countdownLabel', ALL, () => { const o = {}; for (const d of [null, -10, -3, -2, -1, 0, 1, 2, 3, 10]) o[String(d)] = M.countdownLabel(d); return o; });
ask('calc.qtyNights', ALL, () => { const o = {}; for (let n = 0; n <= 10; n++) for (const laundry of [false, true]) o[`${n}/${laundry}`] = M.qtyNights({ nights: n, laundry }); return o; });
ask('calc.backupShrinks', ALL, () => { const o = {}; for (const [p, n] of [[0, 0], [0, 5], [10, 0], [10, 4], [10, 5], [10, 6], [3, 1]]) o[`${p}>${n}`] = M.backupShrinks({ items: p }, { items: n }); return o; });
ask('calc.coerceGeo', ALL, () => {
  const cases = { valid: { lat: 58.5, lon: 16.25, place: 'Testville' }, strings: { lat: '12.5', lon: '-7' }, tooFarNorth: { lat: 91, lon: 0 }, tooFarEast: { lat: 0, lon: 180.5 }, edge: { lat: -90, lon: 180 }, notNumbers: { lat: 'x', lon: 1 }, blankStrings: { lat: '', lon: '' }, nothing: null, placeNotString: { lat: 1, lon: 2, place: 7 } };
  const o = {}; for (const [name, g] of Object.entries(cases)) o[name] = M.coerceGeo(clone(g)); return o;
});
ask('calc.photos', ALL, () => {
  const item = { photos: ['ref-1', 'data:image/png;base64,AAAA', '', 5, 'ref-2'] };
  return { isPhotoRef: ['ref-1', 'data:x', '', null].map((v) => M.isPhotoRef(v)), photoRefs: M.photoRefs(item), inlinePhotos: M.inlinePhotos(item), hasInline: M.hasInlinePhotos([item]), hasInlineNone: M.hasInlinePhotos([{ photos: ['ref-1'] }]) };
});
{
  const dates = distinct([
    TODAY, '2024-02-29', '2026-12-31', '2026-01-01', '2026-03-29', '2026-10-25', '', 'not-a-date', '2026-13-01',
    ...EVENTS.flatMap((e) => [e.startDate, e.endDate]), ...ACTIONS.map((a) => a.whenDate),
    ...LISTS.flatMap((l) => l.items.flatMap((it) => [it.acquired, it.expiry, it.warranty, it.maintenance && it.maintenance.lastDone, ...asArr(it.maintenance && it.maintenance.log).map((x) => x.date)])),
  ].filter((d) => typeof d === 'string')).sort(cmpCodeUnit);
  for (const d of dates) ask('calc.dates', d, () => ({
    addDays: Object.fromEntries([-366, -1, 0, 1, 30, 365].map((n) => [String(n), M.addDays(d, n)])),
    daysBetween: M.daysBetween(d, TODAY), daysUntil: M.daysUntil(d, TODAY), monthKey: M.monthKey(d),
    endFromNights: M.endFromNights(d, 3), nightsToToday: M.nightsBetween(d, TODAY), nightsFromToday: M.nightsBetween(TODAY, d),
  }));
  const months = distinct([M.monthKey(TODAY), '2024-02', '2026-12', '2027-01', ...EVENTS.flatMap((e) => [M.monthKey(e.startDate), M.monthKey(e.endDate)])].filter(Boolean).flatMap((m) => [M.shiftMonth(m, -1), m, M.shiftMonth(m, 1)])).sort(cmpCodeUnit);
  for (const m of months) for (const ws of [1, 0]) ask('calc.monthGrid', `${m}/${ws}`, () => { const g = M.monthGrid(m, ws); return { key: g.key, year: g.year, month: g.month, days: g.days.map((d) => `${d.iso}${d.inMonth ? '' : '*'}`) }; });
  ask('calc.monthGrid', 'invalid', () => M.monthGrid('2026-1', 1));
  for (const m of [...months, 'x', '2026-1']) ask('calc.shiftMonth', m, () => Object.fromEntries([-13, -12, -1, 0, 1, 12, 13].map((n) => [String(n), M.shiftMonth(m, n)])));
  ask('calc.rangeCellState', ALL, () => {
    const o = {};
    for (const [a, b] of [['2026-09-10', '2026-09-14'], ['2026-09-10', ''], ['2026-09-10', '2026-09-10'], ['', '2026-09-14']]) for (const d of ['2026-09-09', '2026-09-10', '2026-09-12', '2026-09-14', '2026-09-15', '']) o[`${d}|${a}|${b}`] = M.rangeCellState(d, a, b);
    return o;
  });
}
{
  // LZW + base64url on real bulk. The big one is the canonical text of every coerced
  // list: large enough to widen the codes well past 9 bits, which a name never does.
  const texts = { empty: '', one: 'a', run: 'a'.repeat(40), classic: 'TOBEORNOTTOBEORTOBEORNOT', unicode: 'Åäö – “quotes” 😀 '.repeat(20) };
  texts.lists = CJ(answers['coerce.list'] || {});
  texts.events = CJ(answers['coerce.event'] || {});
  texts.both = texts.lists + texts.events;   // big enough to FILL the 65 536-entry dictionary, the one branch nothing smaller reaches
  for (const [name, text] of Object.entries(texts)) ask('calc.lzw', name, () => {
    const raw = utf8(text); const z = M.lzwCompress(raw); const back = M.lzwDecompress(z);
    const b64 = M.bytesToBase64Url(z);
    return {
      textBytes: raw.length, textHash: fnv1a(raw), zipBytes: z.length, zipHash: fnv1a(z),
      b64Head: b64.slice(0, 64), b64Tail: b64.slice(-64), b64Length: b64.length,
      roundTrip: back.length === raw.length && fnv1a(back) === fnv1a(raw),
      b64RoundTrip: fnv1a(M.base64UrlToBytes(b64)) === fnv1a(z),
    };
  });
}

// === §15 Installing a list — LAST, because it changes the model's global state ===
{
  const keepPhases = M.PHASES.map((p) => ({ ...p }));
  const keepConditions = M.ITEM_CONDITIONS.map((c) => ({ ...c }));
  const PHASE_CASES = {
    hostile: '[{"id":"zeta","label":"Zeta","order":1},{"id":"alpha","label":"Alpha","order":1},{"id":"alpha","label":"Twin","order":0},{"id":"","label":"No id"},{"id":"nolabel"},{"id":"Beta","label":"Beta","order":1},{"id":"last","label":"Last","order":"7","leadDays":-5,"task":true},{"id":"first","label":"First","order":-2}]',
    empty: '[]',
    notAList: '{"id":"x","label":"X"}',
  };
  for (const [name, json] of Object.entries(PHASE_CASES)) {
    ask('calc.setPhases', name, () => {
      const out = M.setPhases(JSON.parse(json)).map(shapePhase);
      return { phases: out, ids: M.PHASE_IDS.slice(), customised: M.phasesCustomised(), defaultPhaseId: M.defaultPhaseId(), orderOfUnknown: M.phaseOrder('nowhere') };
    });
  }
  M.setPhases(keepPhases);
  const CONDITION_CASES = {
    hostile: '[{"id":"ok","label":"Fine","tone":"warn"},{"id":"ok","label":"Twin"},{"id":"","label":"No id"},{"id":"gone","label":"Gone","tone":"danger","replace":"yes"},{"label":"No id either"}]',
    empty: '[]',
  };
  for (const [name, json] of Object.entries(CONDITION_CASES)) {
    ask('calc.setItemConditions', name, () => {
      const out = M.setItemConditions(JSON.parse(json)).map(shapeCondition);
      return { conditions: out, ids: M.ITEM_CONDITION_IDS.slice(), replaces: M.conditionReplaces('gone'), reason: M.shoppingReason({ condition: 'gone' }, TODAY) };
    });
  }
  M.setItemConditions(keepConditions);
}

// ---------------------------------------------------------------------------
// 8. The document
// ---------------------------------------------------------------------------
const questionKeys = Object.keys(answers).sort(cmpCodeUnit);
let answerCount = 0;
for (const q of questionKeys) answerCount += Object.keys(answers[q]).length;
let errors = 0;
for (const q of questionKeys) for (const v of Object.values(answers[q])) if (v && typeof v === 'object' && '$error' in v) errors += 1;
const info = {
  generator: 'js', contract: 1, today: TODAY, now: NOW,
  locale: new Intl.Collator().resolvedOptions().locale,
  node: process.version, icu: process.versions.icu, unicode: process.versions.unicode,
  model: path.relative(HERE, modelPath),
  counts: {
    lists: LISTS.length, items: LISTS.reduce((n, l) => n + asArr(l.items).length, 0), distinctItems: ITEM_ORDER.size,
    events: EVENTS.length, entries: EVENTS.reduce((n, e) => n + asArr(e.entries).length, 0),
    actions: ACTIONS.length, kits: KITS.length, things: THINGS.length, phases: RAW.phases.length, strings: POOL.length,
  },
  questions: questionKeys.length, answers: answerCount, errors,
  unknownKeys: Object.fromEntries(Object.entries(unknownKeys).map(([k, s]) => [k, [...s].sort(cmpCodeUnit)])),
};
process.stdout.write(`${CJ({ _info: info, answers })}\n`);
console.error(`parity: ${questionKeys.length} questions, ${answerCount} answers, ${errors} errored, today ${TODAY}, collation ${info.locale}`);
