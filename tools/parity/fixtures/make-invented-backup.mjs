#!/usr/bin/env node
// make-invented-backup.mjs — writes invented-backup.json: a backup file in which
// EVERYTHING IS INVENTED, shaped to be as awkward as a backup can get.
//
//   node tools/parity/fixtures/make-invented-backup.mjs > tools/parity/fixtures/invented-backup.json
//   tools/parity/run.sh tools/parity/fixtures/invented-backup.json
//
// The owner's real backup is tidy: no kits, no things, no presets, one grab list, every
// field of the right type. This one is what the parity questions never otherwise see —
// numbers where text belongs, text where numbers belong, an item shared by three lists
// with three different containers, names that differ only in case or spacing, emoji cut
// in half by a length limit, dates that are not dates, a customised phase list with
// ties, legacy `owner` fields, and the sync addon's two reserved keys on every row.
// It is public on purpose: nothing in it is anybody's data.
//
// WHAT IS DELIBERATELY NOT IN IT — shapes a typed model cannot hold, so the two halves
// could never agree on them (each is covered where it CAN be compared, in
// calc.coerceHostile, through the contract's string rule):
//   • a NUMBER in a free-text field the model never touches (`qty: 1`, `note: 7`, a
//     numeric `createdAt`) — JS carries the number through to the Excel rows and the
//     trip bundle; a Swift `String` field holds its text;
//   • a sub-item that is not a string (`{ name }`, a name taken apart) on a STORED item —
//     JS keeps the object, `sub: [String]` cannot;
//   • an item that lacks keys `newItem` always writes (`note`, `qty`…): the app has never
//     stored one, and "absent" is not a state a typed field has;
//   • two names that differ only in Unicode NORMALISATION (`é` as one code point and as
//     `e` + U+0301): JS `===` and `Map` tell them apart, Swift's `String ==` does not —
//     see H17 in QUESTIONS.md;
//   • a list section or an action with NO id: Setup would mint one, and an id minted in
//     Setup is written down raw (D3 covers ids minted inside a question only).

const ADDR = 'someone@example.com';
const stamp = (d, h = 8) => `2026-0${1 + (d % 9)}-1${d % 10}T0${h % 10}:00:00.000Z`;
const reserved = { owner: ADDR, realmId: ADDR };
let n = 0;
// every item starts from the full key set `newItem` writes — the app has never stored less
const BLANK = {"name":"","swedish":"","qty":"","category":"Comfort & misc","container":"Carry-on / hand luggage","phase":"week","itemType":"item","charging":false,"chargeType":"","shortList":false,"seasons":[],"contexts":[],"transports":[],"catering":[],"weather":[],"sub":[],"note":"","weight":0,"liquid":false,"restricted":false,"perNight":false,"consumable":false,"section":"","kit":"","packer":"","storage":"","photos":[],"thumb":"","maintenance":null,"color":"","size":"","manufacturer":"","model":"","ownedBy":"","acquired":"","price":0,"currency":"","purchaseLink":"","expiry":"","condition":"","retired":false,"retiredReason":"","serial":"","qtyOwned":0,"warranty":"","capacityL":0,"maxKg":0,"stats":{"packed":0,"used":0,"unused":0,"skipped":0,"lastReviewed":""}};
const item = (name, more = {}) => ({ id: `it-${++n}`, ...structuredClone(BLANK), name, category: 'Clothing', container: 'Checked luggage', ...more, ...reserved });

// --- phases: customised, with a tie on `order`, a missing label, odd lead days ---------
const phases = [
  { id: 'prep', label: 'Get ready', hint: 'Reservations', emoji: '🗓', color: '#7c5cd6', task: true, leadDays: 30, order: 0 },
  { id: 'week', label: 'A week before', hint: '', emoji: '', color: 'purple', task: false, leadDays: 7.5, order: 1 },
  { id: 'Day', label: 'One sleep before', leadDays: '1', order: 1 },
  { id: 'day2', label: 'Also one sleep before', leadDays: -3, order: 1 },
  { id: 'nolabel', label: '   ', order: 2 },
  { id: 'door', label: 'At the door  ', emoji: '🚪🚪🚪', color: '#ABCDEF', task: 0, leadDays: 0, order: '3' },
  { id: 'extra phase with a very long id that goes past forty characters', label: 'Long id', order: 9 },
];

// --- lists -------------------------------------------------------------------------------
const shared = (id, more) => item('Head torch', { id, category: 'Electronics', charging: true, chargeType: 'usb-c', weight: 86, storage: 'Garage', ownedBy: 'Alex', ...more });
const base = {
  id: 'l-base', name: 'Always', role: 'base', group: '', emoji: '🧳', color: '#22c55e', defaultContainer: 'Checked luggage',
  sections: [{ id: 's-wash', name: 'Rinse pouch' }, { id: 's-docs', name: ' Papers ' }, { id: 's-wash', name: 'Twin id' }, { id: 's-blank', name: '' }],
  createdAt: stamp(1), updatedAt: stamp(2), ...reserved,
  items: [
    item('Bristle stick', { section: 's-wash', container: 'Toiletry bag', phase: 'Day', qty: '1', category: 'Toiletries', consumable: true, expiry: '2026-09-25' }),
    item('Mint paste', { section: 's-wash', container: 'Toiletry bag', liquid: true, consumable: true, expiry: '2026-08-01', weight: 95.5, qty: '1' }),
    item('Glare balm', { section: 's-wash', liquid: 'yes', weather: ['hot', 'sunny', 3], consumable: true, expiry: '2026-13-45', weight: '120' }),
    item('Travel booklet', { section: 's-docs', container: 'Carry-on / hand luggage', phase: 'door', category: 'Documents & money', itemType: 'reminder', transports: ['Plane'], warranty: '2031-05-01' }),
    item('Footlets', { qty: '2', perNight: true, weight: 40, stats: { packed: 5, used: 5, unused: 0, skipped: 0, lastReviewed: stamp(3) } }),
    item('  Footlets ', { qty: '3 pairs', perNight: true, weight: 40, ownedBy: 'alex' }),
    item('footlets', { qty: '0.5', perNight: 1, note: 'seven' }),
    item('Drizzle hull', { weather: ['rain', 'wind'], category: 'Adventure clothing', weight: 410, stats: { packed: 4, used: 0, unused: 4, skipped: 1, lastReviewed: '' }, condition: 'worn' }),
    item('Puffy layer', { weather: ['cold', 'snow'], seasons: ['Winter'], weight: 380, condition: 'retire', maintenance: { notes: 'Wash with down soap', link: 'https://example.invalid/care', intervalDays: 365, lastDone: '2025-09-20', log: [{ date: '2025-09-20', note: 'washed' }, { date: '2024-09-01', note: '' }, { date: 'soon' }] } }),
    item('Lens box 📷 unit', { category: 'Electronics', charging: true, chargeType: 'usb-d', price: 8999.5, currency: 'SEK', serial: 'INV-0001', acquired: '2024-02-29', photos: ['ph-1', 'data:image/png;base64,AAAA', '', null, 'ph-2', 'ph-3', 'ph-4', 'ph-5'], thumb: 'data:image/jpeg;base64,BBBB', kit: 'Lens box kit', packer: 'Alex', storage: 'Hall closet', sub: ['Battery', 'Sling band', '', ' Lid '] }),
    item('Threeleg perch', { kit: 'Lens box kit', packer: 'Blake', storage: 'hall closet', weight: 1250, maintenance: { notes: '', link: '', intervalDays: 30, lastDone: '' } }),
    item('Café mug', { category: 'Food & drink', catering: ['self'], storage: 'Kitchen\u00a0cupboard', ownedBy: 'Blake\u00a0B', owner: 'Legacy Name' }),
    item('Cafe mug', { category: 'Food & drink', catering: ['self', 'mixed'], owner: 'legacy@example.com', ownedBy: null }),
    item('Ärtsoppa', { category: 'Food & drink', catering: ['self'], contexts: ['Outdoor'], swedish: 'Ärtsoppa', phase: '   ' }),
    item('Öglebult', { category: '', phase: 7, photo: 'ph-legacy', retired: true, retiredReason: 'lost' }),
    item('Zip ties', { phase: 'no-such-phase', retired: 'yes', retiredReason: 'stolen', qtyOwned: 12.9, capacityL: -1, maxKg: 'x' }),
    item('', { note: 'a blank name' }),
    item('   ', { note: 'only spaces' }),
    shared('it-both', { container: 'Carry-on / hand luggage', phase: 'Day' }),
  ],
};
const car = {
  id: 'l-car', name: 'By car', role: 'transport', transport: 'Car', defaultContainer: 'RV storage box', createdAt: stamp(2), updatedAt: stamp(4), ...reserved, sections: [],
  items: [item('Warning triangle', { category: 'Comfort & misc' }), item('Ice scraper', { seasons: ['Winter'] }), shared('it-both', { container: '', phase: 'door', note: 'in the dash bin' })],
};
const plane = {
  id: 'l-plane', name: 'By plane', role: 'transport', transport: 'Plane', createdAt: stamp(2), updatedAt: stamp(2), ...reserved,
  items: [item('Nape cushion', { container: 'Carry-on / hand luggage' }), item('Charge brick', { restricted: true, charging: true, chargeType: 'usb-c', weight: 350, container: 'Carry-on / hand luggage' })],
};
const containers = {
  id: 'l-bags', name: 'Containers', role: 'container', createdAt: stamp(1), updatedAt: stamp(1), ...reserved,
  items: [item('Blue duffel', { maxKg: 12, capacityL: 60 }), item('Day pack', { maxKg: 6.5 }), item('  Checked luggage ', { maxKg: 20 }), item('Tiny pouch', { maxKg: 0 })],
};
const hiking = {
  id: 'l-hike', name: 'Ridge walking', group: 'GA', role: '', emoji: '🥾', defaultContainer: 'Hiking backpack', createdAt: stamp(3), updatedAt: stamp(5), ...reserved,
  sections: [{ id: 'h-1', name: 'Rinse pouch' }, { id: 'h-2', name: 'On the ridge' }],
  items: [
    item('Stompers', { category: 'Footwear', section: 'h-2', container: 'Hiking backpack', _ovContainer: '', _tplContainer: 'Hiking backpack', _defContainer: 'Hiking backpack', weight: 1300 }),
    item('Path nibbles', { category: 'Food & drink', section: 'h-2', consumable: true, catering: ['self'], perNight: true, qty: '1', expiry: '2026-10-05' }),
    item('Heel patches', { category: 'Pharmacy / meds', section: 'h-1', contexts: ['Outdoor', 'Race'] }),
    item('Drizzle hull', { weather: ['rain'], category: 'Adventure clothing', weight: 410, container: 'Hiking backpack' }),
    shared('it-both', { container: 'Hiking backpack', _ovContainer: 'Hiking backpack', section: 'h-2' }),
    item('Shin wraps', { seasons: ['Winter'], contexts: ['Outdoor'], transports: ['Car', 'RV'], section: 'no-such-section' }),
  ],
};
const wet = (id, name, items) => ({ id, name, group: 'WET', role: '', createdAt: stamp(4), updatedAt: stamp(4), ...reserved, items });
const swim = wet('l-swim', 'Swim', [item('Eye cups', { contexts: ['Indoor'] }), item('Rubber skin', { contexts: ['Outdoor'], seasons: ['Summer'], weight: 1500 }), item('Drying cloth')]);
const run = wet('l-run', 'run', [item('Race belt', { contexts: ['Race'] }), item('Drying cloth', { container: 'Triathlon bag' }), item('Gels', { consumable: true, contexts: ['Race'], qty: '4' })]);
const bike = wet('l-bike', 'Bike', [item('Skull lid', { weight: 270 }), item('Multitool', { kit: 'Mending kit' }), item('Extra hose', { kit: 'Mending kit', qty: '2' })]);
const yoga = wet('l-yoga', 'Åshtanga', [item('Mat')]);
const abc = wet('l-abc', 'abc', [item('Chalk')]);
const oe = { id: 'l-oe', name: 'Winter bath ❄️', group: 'OE', role: 'special', transport: 'Boat', color: 'blue', emoji: '  ❄️❄️  ', createdAt: '', updatedAt: null, ...reserved, items: [item('Bath robe'), item('Warm flask', { liquid: true, weather: ['cold'] })] };
const empty = { id: 'l-empty', name: 'Nothing here yet', group: 'OE', createdAt: stamp(6), updatedAt: stamp(6), ...reserved, items: [] };
// A name that is cut at 60 units THROUGH an emoji, and more items than a share code carries.
const long = {
  id: 'l-long', name: `${'A very long template name that fills the field to the brim'.padEnd(59, 'x')}😀 and on`, group: 'GA', createdAt: stamp(7), updatedAt: stamp(7), ...reserved,
  sections: [{ id: 'g-1', name: `Section ${'n'.repeat(70)}` }],
  items: Array.from({ length: 405 }, (_, i) => item(`Peg ${String(i).padStart(3, '0')}`, { section: i % 2 ? 'g-1' : '', qty: i % 7 === 0 ? String(i) : '', weight: i % 5, ownedBy: i % 50 === 0 ? ADDR : (i % 50 === 1 ? 'Casey <casey@example.org>' : '') })),
};
const loose = { id: 'l-loose', name: 'Odds', role: 'loose', createdAt: stamp(1), updatedAt: stamp(8), ...reserved, items: [item('Brolly dome', { weather: ['rain'] })] };
const lists = [base, car, plane, containers, hiking, swim, run, bike, yoga, abc, oe, empty, long, loose];

// --- events ------------------------------------------------------------------------------
const entry = (src, list, more = {}) => ({ ...src, id: `en-${++n}`, sourceListId: list.id, sourceItemId: src.id, ...more });
const forecast = (start) => ({ place: 'Testville, XX', lat: '12.25', lon: -12.75, fetchedAt: stamp(5), daily: [
  { date: start, code: 61, tmax: 12.5, tmin: 4.5, precipProb: 80, wind: 10 }, { date: '2026-09-27', code: '73', tmax: -0.5, tmin: '-2.5', precipProb: 'x', wind: 36 },
  { code: 1, tmax: 30 }, { date: '2026-09-28', code: 1, tmax: 27.5, tmin: null, precipProb: 49.5, wind: 34.9 }] });
const events = [
  { id: 'ev-soon', name: 'Hut weekend', mode: 'trip', activities: ['l-hike', 'l-swim', 'l-gone'], transport: 'Car', season: 'Winter', contexts: ['Outdoor'], weatherOn: ['rain', 'fog'], catering: 'self',
    startDate: '2026-09-26', endDate: '2026-09-29', nights: 3, laundry: false, destination: 'Testville, XX', weather: forecast('2026-09-26'), geo: { lat: 12.25, lon: -12.75, place: 'Testville, XX' },
    status: 'active', reviewedAt: '', generatedAt: stamp(5), createdAt: stamp(5), updatedAt: stamp(6), ...reserved,
    entries: [
      entry(base.items[0], base, { checked: true, section: 'Rinse pouch' }), entry(base.items[4], base, { checked: true, used: true }), entry(base.items[5], base, { skipped: true }),
      entry(base.items[6], base, {}), entry(base.items[7], base, { checked: false, packer: 'Blake' }), entry(base.items[9], base, { checked: true, used: false, _edited: true }),
      entry(base.items[10], base, { packer: 'alex' }), entry(hiking.items[0], hiking, { checked: true, container: 'Blue duffel', section: 'On the ridge' }),
      entry(hiking.items[1], hiking, { section: 'On the ridge' }), entry(hiking.items[4], hiking, { section: 'On the ridge' }), entry(car.items[0], car, {}),
      { id: 'en-custom', name: 'Board game', custom: true, qty: '1', container: 'Blue duffel', phase: 'door', category: 'Comfort & misc', weight: 900, packer: 'Guest Person', ...reserved },
      { id: '', name: 'Line with no id', custom: true, phase: 'week', container: '' },
    ] },
  { id: 'ev-past', name: 'City break', mode: 'quick', activities: ['l-oe'], transport: 'Plane', season: 'Summer', contexts: [], weatherOn: [], catering: 'eatout',
    startDate: '2026-08-28', endDate: '2026-09-01', nights: 9, laundry: true, destination: 'Sampleton', weather: null, geo: null, status: 'active', reviewedAt: '',
    generatedAt: stamp(1), createdAt: stamp(1), updatedAt: stamp(1), ...reserved,
    entries: [entry(plane.items[1], plane, { checked: true, used: true }), entry(plane.items[0], plane, { checked: true, used: false }), entry(oe.items[1], oe, { checked: false }), entry(base.items[3], base, { checked: true })] },
  { id: 'ev-done', name: 'Last winter', mode: 'trip', activities: ['l-hike'], transport: 'RV', season: 'Winter', catering: 'mixed', startDate: '2026-01-10', endDate: '', nights: 6, laundry: true,
    destination: '', geo: { lat: '58.75', lon: '16.25' }, status: 'done', reviewedAt: stamp(2), createdAt: stamp(0), updatedAt: stamp(2), ...reserved, entries: [entry(hiking.items[0], hiking, { checked: true, used: true })] },
  { id: 'ev-draft', name: '', mode: 'weird', activities: 'l-hike', transport: 'Bus', season: '', catering: '', startDate: '2026-02-30', endDate: '2026-02-28', nights: -2, laundry: 'no', status: 'open', weather: { daily: [] }, geo: { lat: 95, lon: 0 }, createdAt: '', ...reserved, entries: [] },
  { id: 'ev-today', name: 'Ends today', mode: 'trip', activities: ['l-bike', 'l-run'], transport: 'Car', season: 'Summer', contexts: ['Race'], catering: 'mixed', startDate: '2026-09-19', endDate: '2026-09-21', nights: 2,
    destination: 'Sampleton', geo: { lat: 58.75, lon: 16.25, place: '' }, status: 'active', createdAt: stamp(7), updatedAt: stamp(8), ...reserved,
    entries: [entry(bike.items[0], bike, { checked: true }), entry(bike.items[1], bike, { checked: true }), entry(bike.items[2], bike, {}), entry(run.items[2], run, { checked: true })] },
];

// --- actions, kits, things ---------------------------------------------------------------
const actions = [
  { id: 'a-1', text: 'Buy new stompers', kind: 'shopping', itemId: hiking.items[0].id, itemName: 'Stompers', priority: 'high', whenPhase: '', whenDate: '2026-09-24', done: false, doneAt: '', createdAt: stamp(1), updatedAt: stamp(1), ...reserved },
  { id: 'a-2', text: 'Renew travel booklet', kind: 'todo', priority: 'normal', whenPhase: 'prep', whenDate: '', done: false, createdAt: stamp(2), updatedAt: stamp(3), ...reserved },
  { id: 'a-3', text: 'Book the hut', kind: 'todo', priority: 'urgent', whenPhase: 'no-such-phase', done: true, doneAt: stamp(4), createdAt: stamp(1), updatedAt: stamp(4), phase: 'door', ...reserved },
  { id: 'a-4', text: 'Mint paste', kind: 'shopping', itemId: base.items[1].id, itemName: 'Mint paste', priority: 'normal', whenDate: '2026-9-1', done: 'yes', ...reserved },
  { id: 'a-5', text: 'Hardly a task', kind: 'buy', whenPhase: '  Day  ' },
  { id: 'a-6', text: 'book the hut', kind: 'todo', priority: 'high', whenDate: '2026-09-24', done: false, createdAt: stamp(3), updatedAt: stamp(3) },
];
const kits = [
  { id: 'k-1', name: 'Lens box kit', emoji: ' 📷 ', note: 'Unit, glass, perch', itemIds: [base.items[9].id, base.items[10].id, base.items[9].id, '', 3], createdAt: stamp(1), updatedAt: stamp(2), ...reserved },
  { id: 'k-2', name: 7, emoji: '', itemIds: 'nope', createdAt: stamp(3) },
];
const things = [
  item('Reserve ground pins', { storage: 'Garage', ownedBy: 'Alex', weight: 15, qtyOwned: 12 }),
  item('footlets', { storage: 'Bedroom wardrobe' }),
  item('Old kettle', { retired: true, retiredReason: 'broken', condition: 'mystery', maintenance: { notes: 'Descale', intervalDays: 90, lastDone: '2026-03-01', log: [] } }),
  'not an item',
];

// --- prefs -------------------------------------------------------------------------------
const prefs = {
  theme: 'dark',
  conditions: [{ id: 'new', label: 'New', tone: '' }, { id: 'worn', label: 'Well used', tone: 'warn' }, { id: 'retire', label: 'Replace it', tone: 'danger', replace: true }, { id: 'worn', label: 'Twin' }, { id: '', label: 'No id' }, { id: 'loved', label: 'Loved', tone: 'loud', replace: 'yes' }],
  people: [{ id: 'p-1', name: 'Alex', color: '#3b82f6' }, { name: ' Blake ', color: 'green' }, { id: 'p-3', name: 'alex', color: '#ef4444' }, { id: 'p-4', name: '' }, 'Casey'],
  storageLocations: ['Garage', 'Hall closet', 'hall closet', '  Kitchen cupboard ', '', { name: 'Loft' }, 'Bedroom wardrobe', 'Ängsbod'],
  owners: ['Blake B', 'Alex', 'alex', ' Casey '],
  presets: [
    { id: 'pr-1', name: 'Weekend by car', createdAt: stamp(1), config: { mode: 'trip', activities: ['l-hike'], transport: 'Car', season: 'Summer', contexts: [], catering: 'self', weatherOn: ['rain'], laundry: false } },
    { name: 'weekend  BY car', createdAt: stamp(2), config: { mode: 'quick' } },
    { name: 'Odd', config: { mode: 'weird', activities: 'x', transport: 'Bus', weatherOn: ['fog'], laundry: 1 } },
    { name: '', config: {} }, 'junk',
  ],
  grab: {
    items: { bike: ['Skull lid', 'Clogs', '', 'Skull lid', 5, `A grab item with a long name that passes sixty units ${'x'.repeat(10)}😀`], 'run-out': ['Keys', 'Handset 📱'], empty: [] },
    meta: { bike: { label: 'Bike ride 🚴‍♀️ out', icon: 'bike', tone: 'blue' }, 'run-out': { label: '', icon: '', tone: '' }, ghost: { label: 'Only a label' } },
  },
};

const backup = { app: 'ams-packing-list', version: 2, exportedAt: '2026-09-10T09:30:00.000Z', lists, events, actions, kits, phases, things, photos: [], prefs };
process.stdout.write(`${JSON.stringify(backup, null, 1)}\n`);
