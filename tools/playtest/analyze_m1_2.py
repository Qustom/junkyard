# RG2 — M1.2 telemetry analysis helper (feeds design/M1_2_Tasks/G4_findings_M1.2.md).
# Reads the cumulative JSONL playtest log, partitions runs by build SHA + run_config,
# and prints cohort counts, per-config distributions, and per-fix event evidence.
# Run from repo root:  python3 tools/playtest/analyze_m1_2.py
import json, statistics
from collections import Counter, defaultdict

PATH='playtest_data/M1.2/run_log_2026-06-19.jsonl'

runs={}   # run_id -> dict
events_by_run=defaultdict(list)
for line in open(PATH):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    rid=o['run_id']; t=o['type']; d=o.get('data',{})
    events_by_run[rid].append(o)
    if t=='run_started':
        runs.setdefault(rid,{})
        runs[rid].update(build=d['build'], cfg=d.get('run_config'), started=True, ts=o['ts'])
    elif t=='run_ended':
        runs.setdefault(rid,{})
        runs[rid].update(ended=True, cause=d.get('cause'), dur=d.get('duration_s'),
                         banked=d.get('banked_total'), lost=d.get('lost_total'), max_depth=d.get('max_depth'))

def all_off(cfg):
    if cfg is None: return False
    return not any(cfg.get(f'{r}_enabled') for r in ('r1','r2','r3','r4')) and not cfg.get('lvl_enabled', False)

def lvl_default(cfg):
    # M1.0 control: lvl knob absent OR lvl_enabled false
    if cfg is None: return True
    return not cfg.get('lvl_enabled', False)

# ---- cohort assignment ----
def cohort(r):
    b=r.get('build','?')
    cfg=r.get('cfg')
    if b=='m1-20260619-ba745e1': return 'M1.2'
    if b in ('m1-20260619-852b6e2','m1-20260618-852b6e2'): return 'M1.1'
    return 'other'

# M1.0 control = all_off AND lvl default, regardless of build (the permanent control)
for rid,r in runs.items():
    r['cohort']=cohort(r)
    if r['cohort']=='M1.1' and all_off(r.get('cfg')) and lvl_default(r.get('cfg')):
        r['is_m10_control']=True
    else:
        r['is_m10_control']=False

# ---- counts per build, abandoned rate ----
print('=== COHORT / BUILD COUNTS ===')
bc=Counter(); started=Counter(); ended=Counter()
for rid,r in runs.items():
    bc[r.get('build','?')]+=1
    if r.get('started'): started[r.get('build','?')]+=1
    if r.get('ended'): ended[r.get('build','?')]+=1
for b in sorted(bc):
    s=started[b]; e=ended[b]
    ab = (s-e)/s*100 if s else 0
    print(f'  {b}: total_runs={bc[b]} started={s} ended={e} abandoned={s-e} ({ab:.0f}%)')

print()
print('=== M1.0 CONTROL subset (all-off + lvl default, any build) ===')
m10=[r for r in runs.values() if r['is_m10_control']]
print(f'  n={len(m10)}')

import statistics as st
def med(xs):
    xs=[x for x in xs if x is not None]
    return st.median(xs) if xs else None
def fmt(x): return f'{x:.1f}' if isinstance(x,float) else str(x)

# ---- M1.2 config sweep: group by meaningful knobs ----
def cfg_signature(cfg):
    if cfg is None: return 'NO_CFG'
    parts=[]
    parts.append(f"lvl={'on' if cfg.get('lvl_enabled') else 'off'}")
    parts.append(f"sz={cfg.get('lvl_size_mult')}")
    parts.append(f"rc={cfg.get('lvl_room_count')}")
    for r in ('r1','r2','r3','r4'):
        if cfg.get(f'{r}_enabled'): parts.append(r.upper())
    return ' '.join(parts)

print()
print('=== M1.2 (ba745e1) CONFIG SWEEP ===')
m12=[r for r in runs.values() if r['cohort']=='M1.2']
groups=defaultdict(list)
for r in m12: groups[cfg_signature(r.get('cfg'))].append(r)
for sig,rs in sorted(groups.items(), key=lambda kv:-len(kv[1])):
    causes=Counter(r.get('cause') for r in rs if r.get('ended'))
    durs=[r.get('dur') for r in rs if r.get('ended')]
    depths=[r.get('max_depth') for r in rs if r.get('ended')]
    nzero=sum(1 for d in durs if d==0)
    print(f'  [{len(rs)}] {sig}')
    print(f'       cause={dict(causes)} median_dur={fmt(med(durs))}s depth(med/max)={fmt(med(depths))}/{max([d for d in depths if d is not None],default=None)} dur=0 count={nzero}')

# Show full knob detail for the M1.2 configs (size_mult, room_count, hallway-ish)
print()
print('=== M1.2 distinct (lvl_size_mult, lvl_room_count, oppositions) detail ===')
seen=set()
for r in m12:
    cfg=r.get('cfg')
    key=(cfg.get('lvl_enabled'),cfg.get('lvl_size_mult'),cfg.get('lvl_room_count'),
         cfg.get('r1_enabled'),cfg.get('r2_enabled'),cfg.get('r3_enabled'),cfg.get('r4_enabled'))
    if key in seen: continue
    seen.add(key)
    print('  ',key)

print()
print('=== AGGREGATE side-by-side: M1.0 control / M1.1 / M1.2 ===')
def summarize(label, rs):
    ended=[r for r in rs if r.get('ended')]
    causes=Counter(r.get('cause') for r in ended)
    durs=[r.get('dur') for r in ended]
    nz=[d for d in durs if d not in (None,0)]
    depths=[r.get('max_depth') for r in ended if r.get('max_depth') is not None]
    zeros=sum(1 for d in durs if d==0)
    print(f'{label}: n_ended={len(ended)}')
    print(f'   cause: {dict(causes)}')
    print(f'   dur median(all)={fmt(med(durs))}s  median(nonzero)={fmt(med(nz))}s  dur=0 count={zeros}/{len(durs)}')
    print(f'   depth median={fmt(med(depths))} max={max(depths,default=None)}')

m10=[r for r in runs.values() if r['is_m10_control']]
m11=[r for r in runs.values() if r['cohort']=='M1.1']
m12=[r for r in runs.values() if r['cohort']=='M1.2']
summarize('M1.0 control (all-off+lvl default)', m10)
summarize('M1.1 (852b6e2, all configs)', m11)
summarize('M1.2 (ba745e1, all configs)', m12)

# ---- PER-FIX evidence: events per cohort ----
print()
print('=== PER-FIX EVENT COUNTS by cohort ===')
# map each event to its run cohort
def run_cohort_of(rid):
    r=runs.get(rid,{})
    if r.get('is_m10_control'): return 'M1.0ctrl'
    return r.get('cohort','other')

evt_cohort=defaultdict(Counter)
for rid,evs in events_by_run.items():
    c=run_cohort_of(rid)
    for o in evs:
        evt_cohort[o['type']][c]+=1
interesting=['hazard_awoke','hazard_caught','return_cost_incurred','exposure_crossed','exposure_penalty','nav_branch_taken','nav_lost_proxy','junk_lost']
hdr=f"{'event':<22}{'M1.0ctrl':>10}{'M1.1':>8}{'M1.2':>8}"
print(hdr); print('-'*len(hdr))
for e in interesting:
    c=evt_cohort[e]
    print(f"{e:<22}{c['M1.0ctrl']:>10}{c['M1.1']:>8}{c['M1.2']:>8}")

# hazard_caught -> death linkage in M1.2
print()
print('=== I2: hazard_caught -> death linkage (M1.2) ===')
for r in m12:
    rid=[k for k,v in runs.items() if v is r][0]
