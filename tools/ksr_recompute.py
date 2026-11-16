#!/usr/bin/env python3
"""Rebuild KSR ratings from round_stats using the model of kether_skill_rating.sp v2.1.

round_stats keeps every raw component of every round, so the whole history can be
replayed through the current weights instead of being thrown away. Mirrors the
plugin: raw round score -> z-score (absolute blended with carry) -> EMA.

Run this whenever a model default changes. The plugin updates ratings round by
round, so rounds already played keep whatever settings scored them until the
history is replayed - which is how a stale cfg silently ran the wrong model for
days.

Pre-v2 rows carry known defects and are compensated: dmg_witch held common damage,
special_rescues duplicated special_clears, shove_si duplicated
special_shove_saves, and witch_crowns counted any witch kill. scoring_version is
never rewritten, so running this twice gives the same answer.

Scoring version 3 (plugin 2.1) rebuilt the infected side around damage: the pin,
spit, focus and tank-support assists and every tank point carried no stable
signal about the player, so they are weighted 0 and damage carries the score.
Keep W_SURV / W_INF and SCORING_VERSION in step with the plugin defaults.

The baselines are written together with the scoring version they belong to; the
plugin refuses baselines from another version and falls back to its seed values.

    python tools/ksr_recompute.py <db>            # dry run
    python tools/ksr_recompute.py <db> --apply    # write (a .bak copy is made first)

Stop the server (or unload the plugin) before --apply on a live database: the
plugin keeps ratings of connected players in memory and would write them back.
"""
import sqlite3, statistics as st, math, shutil, time, sys, os

if len(sys.argv) < 2 or sys.argv[1].startswith('--'):
    sys.exit('usage: ksr_recompute.py <database.sq3> [--apply]')
DB = sys.argv[1]
if not os.path.exists(DB):
    sys.exit('no such database: ' + DB)
APPLY = '--apply' in sys.argv

SCORING_VERSION = 3

W_SURV = {'dmg_survivor':0.0073,'dmg_tank':0.018,'dmg_witch_real':0.010,'common_damage':0.0,
 'common_kills':0.190,'special_clears':18.0,'special_rescues':6.0,'self_clears':45.0,'skeets':65.0,
 'skeets_melee':85.0,'deadstops':40.0,'boomer_pops':20.0,'boomer_pops_splash':-25.0,'revives':20.0,
 'medkit_gives':25.0,'jockey_blocks':4.0,'tank_play_actions':3.0,'ff_dealt':-3.0,
 'headshot_si':1.5,'survival_time':0.0,'flow_percent':0.0,'shove_si':4.0,'witch_crowns':45.0,
 'witch_kills':6.0,'rock_skeets':40.0,'chain_clear_boom':20.0,'safe_saves':8.0,'zero_ff_bonus':15.0,
 'alarm_triggers':-35.0,'charger_levels':35.0,'tongue_cuts':25.0,'special_shove_saves':10.0,
 'rock_eaten_penalty':-25.0}
W_INF = {'dmg_infected':0.62,'boomer_vomit_hits':25.0,'boomer_vomit_casts':-25.0,'pin_dps_assist':0.0,
 'pin_assists':0.0,'big_hit_assist_score':11.0,'spit_ticks_pinned':0.0,'spit_ticks_incap':0.0,
 'tank_boom_assists':0.0,'witch_assists':0.0,'spit_setup_assists':6.0,'boom_kill_assists':20.0,
 'charger_multi':0.0,'spit_multi_hits':0.0,'shared_focus':0.0,'boom_focus':0.0,'stagger_setup':0.0,
 'chain_control':40.0,'tank_support':0.0,'tank_hold_time':0.0,'tank_kills':0.0,'tank_passes':0.0,
 'tank_wipe_bonus':0.0,'revive_interrupts':0.0,'death_charges':60.0,'hunter_pounce_dmg':0.5,
 'jockey_high_pounces':20.0}

EMA_MIN, SHRINK, SCALE, CARRY = 0.004, 80.0, 1200.0, 0.5
BASE_EMA, ZC, KSR_BASE = 0.003, 3.0, 1000.0

def raw(row, team, legacy):
    g = lambda k: float(row.get(k) or 0)
    s = 0.0
    if team == 3:
        for k, w in W_INF.items(): s += g(k)*w
        return s
    for k, w in W_SURV.items():
        if k in ('dmg_witch_real','common_damage','witch_kills'): continue
        if legacy and k in ('special_rescues','special_shove_saves'): continue
        if legacy and k == 'witch_crowns':
            s += g(k)*W_SURV['witch_kills']; continue
        s += g(k)*w
    if legacy: s += g('dmg_witch')*W_SURV['common_damage']
    else:
        s += g('dmg_witch')*W_SURV['dmg_witch_real']
        s += g('common_damage')*W_SURV['common_damage']
        s += g('witch_kills')*W_SURV['witch_kills']
    return s

con = sqlite3.connect(DB); con.row_factory = sqlite3.Row
con.text_factory = lambda b: b.decode('utf-8','replace')
rows = [dict(r) for r in con.execute('SELECT * FROM round_stats ORDER BY map_name,round_index,ts,id')]
for r in rows:
    r.setdefault('scoring_version',1)
    for cl in ('common_damage','witch_kills','death_charges','hunter_pounce_dmg','jockey_high_pounces'):
        r.setdefault(cl,0)
g, cur = [], None
for r in rows:
    k = (r['map_name'], r['round_index'])
    if cur and cur['k'] == k and r['ts']-cur['t0'] <= 60: cur['rows'].append(r)
    else: cur = {'k':k,'t0':r['ts'],'rows':[r]}; g.append(cur)
g.sort(key=lambda x: x['t0'])
rounds = [x for x in g if sum(1 for r in x['rows'] if r['team']==2)>=3 and sum(1 for r in x['rows'] if r['team']==3)>=3]

seed = {2: [], 3: []}
for x in rounds[:60]:
    for r in x['rows']:
        if r['team'] in (2, 3):
            seed[r['team']].append(raw(r, r['team'], (r['scoring_version'] or 1) < 2))
base = {t: [st.mean(seed[t]), max(st.pstdev(seed[t]), 1.0)] for t in (2, 3)}

rating, nr = {}, {}
side_r, side_n = {}, {}
zrow = {}
for x in rounds:
    mem = [r for r in x['rows'] if r['team'] in (2, 3)]
    tot = {2: 0.0, 3: 0.0}; cnt = {2: 0, 3: 0}; sc = []
    for r in mem:
        v = raw(r, r['team'], (r['scoring_version'] or 1) < 2)
        sc.append((r, r['team'], v)); tot[r['team']] += v; cnt[r['team']] += 1
    for r, t, v in sc:
        sid = r['steamid']
        mean, sd = base[t]; sd = max(sd, 1.0)
        tm = tot[t]/cnt[t] if cnt[t] else v
        z = max(-ZC, min(ZC, (1-CARRY)*((v-mean)/sd) + CARRY*((v-tm)/sd)))
        k = max(1.0/(nr.get(sid, 0)+1), EMA_MIN)
        rating[sid] = rating.get(sid, 0.0) + k*(z - rating.get(sid, 0.0))
        nr[sid] = nr.get(sid, 0)+1
        zrow[r['id']] = z
        key = (sid, t)
        ks = max(1.0/(side_n.get(key, 0)+1), EMA_MIN)
        side_r[key] = side_r.get(key, 0.0) + ks*(z - side_r.get(key, 0.0))
        side_n[key] = side_n.get(key, 0)+1
    for r, t, v in sc:
        mean, sd = base[t]; d = v-mean
        base[t] = [mean+BASE_EMA*d, math.sqrt(max(sd*sd+BASE_EMA*(d*d-sd*sd), 1.0))]

ksr = lambda s: KSR_BASE + SCALE*rating[s]*(nr[s]/(nr[s]+SHRINK))
P = {r['steamid']: dict(r) for r in con.execute('select * from players')}
NM = {s: (p['name'] or '?') for s, p in P.items()}
old = lambda s: KSR_BASE + SCALE*(P[s].get('rating') or 0.0)*((P[s].get('rating_rounds') or 0)/((P[s].get('rating_rounds') or 0)+SHRINK)) if s in P and (P[s].get('rating_rounds') or 0) > 0 else None
ranked = sorted((s for s in rating if nr[s] >= 20), key=ksr, reverse=True)
vals = [ksr(s) for s in ranked]
print('%d rund, %d graczy z >=20 rundami' % (len(rounds), len(ranked)))
print('KSR: %.0f - %.0f  sd %.0f' % (min(vals), max(vals), st.pstdev(vals)))
print('baseline: ocalali srednia %.1f sd %.1f | zarazeni srednia %.1f sd %.1f\n' % (base[2][0], base[2][1], base[3][0], base[3][1]))
for i, s in enumerate(ranked[:10], 1):
    o = old(s)
    print('%3d. %-24s KSR %6.0f  %4d rund%s' % (i, NM.get(s, '?')[:24], ksr(s), nr[s], ('   (w bazie %.0f, %+.0f)' % (o, ksr(s)-o)) if o is not None else ''))
moves = sorted(((ksr(s)-old(s), s) for s in ranked if old(s) is not None), key=lambda v: abs(v[0]), reverse=True)
if moves:
    print('\nnajwieksze zmiany wzgledem bazy:')
    for d, s in moves[:10]:
        print('     %-24s %6.0f -> %6.0f  (%+.0f)' % (NM.get(s, '?')[:24], old(s), ksr(s), d))
A = '76561198153940657'
if A in rating:
    print('\nalbinos: KSR %.0f  (%d rund)' % (ksr(A), nr[A]))

if not APPLY:
    print('\nsucho - nic nie zapisano. dodaj --apply')
    sys.exit()

con.close()
shutil.copy2(DB, '%s.bak-%s' % (DB, time.strftime('%Y%m%d-%H%M%S')))
w = sqlite3.connect(DB)
w.execute('UPDATE players SET rating=0.0, rating_rounds=0, rating_surv=0.0, '
          'rating_surv_rounds=0, rating_inf=0.0, rating_inf_rounds=0')
w.executemany('UPDATE players SET rating=?, rating_rounds=?, rating_surv=?, '
              'rating_surv_rounds=?, rating_inf=?, rating_inf_rounds=? WHERE steamid=?',
              [(rating[s], nr[s], side_r.get((s, 2), 0.0), side_n.get((s, 2), 0),
                side_r.get((s, 3), 0.0), side_n.get((s, 3), 0), s) for s in rating])
w.executemany('UPDATE round_stats SET rating_z=? WHERE id=?',
              [(z, i) for i, z in zrow.items()])
w.executemany('INSERT OR REPLACE INTO baselines (team,mean,sd,samples) VALUES (?,?,?,?)',
              [(t, base[t][0], base[t][1], len(rounds)) for t in (2, 3)])
w.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '')")
w.execute("INSERT OR REPLACE INTO meta (key, value) VALUES ('baseline_scoring_version', ?)", (str(SCORING_VERSION),))
w.commit()
print('\nzapisano: %d graczy, %d z-score rund' % (len(rating), len(zrow)))
