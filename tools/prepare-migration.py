#!/usr/bin/env python3
"""Turn a web-app backup into the clean file the new app imports.

    python3 tools/prepare-migration.py <backup.json> [--skip-trips private/skip-trips.txt]

Writes private/migration-<date>.json (git-ignored — his data never enters this
public repository) and prints what it kept and what it left behind.

Two rules, both his decisions of 2026-09-21:

1. ONE copy of each template. Since 31 August 2026 every template has existed
   twice: the one he actually uses, and a frozen copy made in a single minute
   (most likely a fresh install seeding the starter lists, then syncing them into
   his account). The copies share no items. Of two templates with the same name,
   keep the ORIGINAL — the one created first (an id starts with its creation
   time) — and leave the later duplicate.

   🪤 NOT "the one edited most recently". Items carry no edit time, and many of
   his live templates were last edited BEFORE 31 August — so the frozen copy's
   creation looked like the latest edit, and the first version of this script
   kept the wrong copy of every template. The totals (545 rows kept, where the
   live copy has 538) are what gave it away. The choice is cross-checked below
   against review history and against which copy his trips were built from.

2. Leave the test trips behind. Trip names to skip, one per line, come from a
   file in private/ — trip names are his data, so they are not written here.
   Trip lines are self-contained: a trip keeps every line and tick even when the
   template it was built from is the one left behind.
"""
import json, sys, os, datetime, collections

def when(v):
    try: return datetime.datetime.fromisoformat(str(v).replace('Z', '+00:00')).timestamp()
    except Exception: return 0.0

def last_edit(t):
    stamps = [when(t.get('updatedAt'))] + [when(i.get('updatedAt')) for i in t.get('items') or []]
    return max(stamps)

def born(t):
    try: return int(str(t['id']).split('-')[0], 36)
    except Exception: return float('inf')

def trip_lines(t, events):
    return sum(1 for e in events for x in e.get('entries') or [] if x.get('sourceListId') == t['id'])

def history(t):
    return sum(1 for i in t.get('items') or [] if (i.get('stats') or {}).get('packed') or (i.get('stats') or {}).get('lastReviewed'))

def main():
    if len(sys.argv) < 2: sys.exit(__doc__)
    src = sys.argv[1]
    skip_file = sys.argv[sys.argv.index('--skip-trips') + 1] if '--skip-trips' in sys.argv else None
    d = json.load(open(src, encoding='utf-8'))
    assert d.get('app') == 'ams-packing-list', 'not an AMS Packing backup'

    groups = collections.defaultdict(list)
    for t in d['lists']: groups[t.get('name')].append(t)
    kept, left = [], []
    for name, ts in groups.items():
        ts.sort(key=born)                   # the original first
        kept.append(ts[0]); left.extend(ts[1:])
    # Cross-check: the copy kept should be the one he has reviewed and built trips
    # from. If those point the other way, say so loudly rather than guess.
    kh, lh = sum(history(t) for t in kept), sum(history(t) for t in left)
    kt, lt = sum(trip_lines(t, d['events']) for t in kept), sum(trip_lines(t, d['events']) for t in left)
    print(f"check       kept copies: {kh} items with review history, {kt} trip lines built from them")
    print(f"            left copies: {lh} items with review history, {lt} trip lines built from them")
    if lh > kh or lt > kt:
        print("⚠️  WARNING  the copies left behind look MORE used than the ones kept — stop and look before importing")
    order = {t['id']: i for i, t in enumerate(d['lists'])}
    kept.sort(key=lambda t: order[t['id']])

    skip = set()
    if skip_file and os.path.exists(skip_file):
        skip = {l.strip() for l in open(skip_file, encoding='utf-8') if l.strip()}
    trips = [e for e in d['events'] if e.get('name') not in skip]
    dropped_trips = [e for e in d['events'] if e.get('name') in skip]

    out = dict(d)
    out['lists'] = kept
    out['events'] = trips
    out['migration'] = {
        'from': os.path.basename(src), 'exportedAt': d.get('exportedAt'),
        'preparedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
        'templatesKept': len(kept), 'templatesLeftBehind': len(left),
        'tripsKept': len(trips), 'tripsLeftBehind': len(dropped_trips),
    }
    os.makedirs('private', exist_ok=True)
    dest = f"private/migration-{(d.get('exportedAt') or '')[:10] or 'undated'}.json"
    json.dump(out, open(dest, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    rows = lambda ls: sum(len(t.get('items') or []) for t in ls)
    print(f"source      {src}\n            exported {d.get('exportedAt')}")
    print(f"templates   kept {len(kept)} ({rows(kept)} rows)   left behind {len(left)} ({rows(left)} rows)")
    for t in left:
        k = next(x for x in kept if x.get('name') == t.get('name'))
        print(f"   '{t.get('name')}': kept the original made {datetime.datetime.fromtimestamp(born(k)/1000):%Y-%m-%d %H:%M} "
              f"({len(k.get('items') or [])} items), left the copy made {datetime.datetime.fromtimestamp(born(t)/1000):%Y-%m-%d %H:%M} ({len(t.get('items') or [])} items)")
    print(f"trips       kept {len(trips)}   left behind {len(dropped_trips)}")
    print(f"wrote       {dest}")

if __name__ == '__main__':
    main()
