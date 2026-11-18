# AI Tank recovery

Source: [l4d2_ai_tank_recovery.sp](../addons/sourcemod/scripting/l4d2_ai_tank_recovery.sp).
Requires Left 4 DHooks and L4D2. Loaded by
`cfg/cfgogl/kether_versus_t1/shared_plugins.cfg` from
`addons/sourcemod/plugins/optional/kether/l4d2_ai_tank_recovery.smx`.

## Detection

The plugin samples living, non-ghost, non-incapacitated AI Tanks once per second.
A Tank must stay within 160 units of its observation anchor for 15 seconds while
every living survivor is at least the configured isolation distance away. The
source specifies a 600-unit default, but currently retains a 700-unit minimum
bound; see Configuration before testing the intended 600-unit setting.
Leaving the radius, leaving the
ground or changing to human control restarts observation. Incapacitated survivors
count toward the distance and visibility checks.

Every five seconds, progress is checked against a separate fixed goal for every
living survivor. Goals are captured at the start of the camp observation, so a
target switch can be recognized without knowing the Tank AI's internal target.
New or respawned survivors receive their own baseline without resetting dwell;
dead or disconnected survivors stop contributing. User IDs prevent slot reuse
from inheriting another survivor's measurements.

Reducing straight-line distance by at least 64 units beyond a survivor's retained
best distance restarts dwell. Reducing nav travel distance by at least 64 units
beyond its retained best also restarts dwell, with two additional requirements:
the Tank must have displaced at least 32 units from its reference position, and
that reference position must still have a route at least 64 units longer than
the current position when both are queried under the current nav conditions.

Progress restarts the dwell clock without moving the camp anchor or discarding
any survivor's best distances. Returning to previously credited ground cannot
earn the same improvement repeatedly. All survivor records are updated in the
same sample, preventing one movement from earning delayed credit across several
survivors. Records are rebuilt when the Tank leaves the camp area or observation
is otherwise cancelled.

Missing routes provide no route-progress credit. A first valid route establishes
a baseline without resetting dwell, and later availability flips preserve that
baseline and the dwell clock. A survivor moving toward a stationary Tank does
not count as Tank progress. Survivor proximity still cancels observation.

Taking or dealing damage does not reset dwell. Rock throws do not reset dwell
either; a recent throw can defer a ready recovery for three seconds, capped at
five seconds after dwell expires even if throws continue. A stationary Tank can
therefore recover while being shot, burning or repeatedly throwing rocks.

This detects local wandering as well as standing still. It is a conservative
heuristic, not proof that the original route is broken. Frustration is logged on
recovery but does not trigger or accelerate it. No original-position nav route is
required, allowing recovery from disconnected portions of the mesh. The fixed
goals and progress thresholds remain heuristics: very slow progress or a route
toward a survivor who has moved substantially can still be misclassified.

## Destination checks

Living survivors are searched in order of increasing distance from the Tank.
Up to 48 positions on three rings around each survivor are tested, stopping at
the first valid candidate. A failure around the nearest survivor therefore falls
back to the next survivor. The defaults require 300–600 units from the survivor
being searched around and at least 300 units from every other living survivor.
Ground projection must also preserve the maximum
distance. Visibility rays at three heights must be blocked from every living
survivor's eyes, regardless of viewing direction.

Candidates require the Tank's current collision hull to fit, solid world support
under the center and four corners, and nearly level ground. Water, slime,
out-of-world positions, nearby `trigger_hurt` volumes and inferno flames are
rejected. Destination nav areas must not be blocked for infected or flagged as
crouch, jump, cliff, playerclip, outside-world, checkpoint, player start, rescue
vehicle or rescue closet. The nav travel distance from destination to survivor
must be valid and at most 1200 units.

These are geometric and nav checks, not a guarantee of safety on a malformed
custom map. In particular, nav travel distance is not a Tank-specific movement
simulation; a graph route can still contain an obstacle the Tank cannot pass.
Scripted hazards that do not use the checked entity types are not identified.
Visibility samples do not test every point on the Tank model.

No valid candidate means no teleport, with another bounded search five seconds
later. A successful teleport clears velocity, preserves health and starts a
60-second cooldown. Each Tank life permits two recoveries, with the counter and
cooldown carried across control replacements. Map changes, round starts and new
spawns reset state. Recovery and initial failed searches are written to the
SourceMod log.

## Configuration

On first load, SourceMod generates `cfg/sourcemod/l4d2_ai_tank_recovery.cfg`.

- `l4d2_ai_tank_recovery_enable`: `1`.
- `l4d2_ai_tank_recovery_dwell`: `15` seconds; minimum `15`.
- `l4d2_ai_tank_recovery_radius`: `160` units; range `32–400`.
- `l4d2_ai_tank_recovery_isolation`: source default `600` units; current minimum
  bound `700`. The bound conflicts with the intended default, so check the live
  value rather than assuming a 600-unit threshold is active.
- `l4d2_ai_tank_recovery_min_distance`: `300` units; range `300–600`.
- `l4d2_ai_tank_recovery_max_distance`: `600` units; range `300–700`.
- `l4d2_ai_tank_recovery_cooldown`: `60` seconds; minimum `30`.
- `l4d2_ai_tank_recovery_limit`: `2`; range `0–10`, with `0` disabling recovery.

Keep maximum distance greater than minimum distance. Inverted bounds fail closed.
The `kether_versus_t1` mode sets `tank_stuck_time_suicide` to `20` seconds in
`cfg/cfgogl/kether_versus_t1/shared_cvars.cfg`. The plugin itself does not change
that cvar or prevent engine deaths. Default recovery dwell is now 15 seconds,
but continuous rock throws can defer a ready search until 20 seconds after
observation starts, plus timer sampling latency. This leaves no guaranteed margin
against a 20-second suicide timer; the engine and plugin also start timing under
different conditions. A rejected destination requires another five seconds
before the next search. If the engine kills the Tank first, recovery cannot occur.

Check the active values after loading the mode:

```text
sm_cvar l4d2_ai_tank_recovery_dwell
sm_cvar l4d2_ai_tank_recovery_isolation
sm_cvar tank_stuck_time_suicide
```

## Build check

Run from `addons/sourcemod/scripting`:

```sh
./sourcemod/spcomp64 -E -i include l4d2_ai_tank_recovery.sp -o ../plugins/optional/kether/l4d2_ai_tank_recovery.smx
```

`-E` treats compiler warnings as errors. Compilation does not exercise engine
traces, entity properties, callbacks or navigation SDK calls.

## In-game regression checklist

Use a private test server with Left 4 DHooks, the normal Tank-control plugins and
this plugin loaded. Check SourceMod logs for native/property errors throughout.
These scenarios require live validation; they are not automated unit tests.

1. Confine an AI Tank with small oscillating movement, place all survivors beyond
   the live isolation distance, and provide a hidden, clear destination on
   connected survivor-side nav. Expect no recovery before 15 seconds, then one logged recovery with
   unchanged health and valid survivor separation.
2. Repeat on disconnected Tank-side nav. A missing original route must not veto
   a valid survivor-side destination. Remove survivor-side nav instead: expect
   no teleport and a rate-limited failure log.
3. Move the Tank outside its 160-unit anchor radius just before expiry. Expect a
   fresh full observation period. Then keep it inside that radius while reducing
   straight-line distance to any fixed survivor goal by 64 units: expect a fresh
   dwell period at the next five-second progress sample, with the original camp
   anchor retained. Repeat on a winding route
   that reduces nav travel distance by 64 units with at least 32 units of Tank
   displacement, even while straight-line distance increases. Expect the same.
4. Bring a living survivor, including an incapacitated bot, within the live
   isolation distance.
   Expect no recovery. Move them away: expect a fresh full observation period.
5. Repeatedly damage an isolated, confined Tank, including continuous fire.
   Expect recovery after dwell despite the damage. Repeat with rock throws and
   long-range survivor hits: observation must continue, and continuous throwing
   must not postpone the first search beyond 20 seconds with default dwell,
   allowing for timer sampling latency. Use a suicide timer longer than this
   when testing recovery independently of engine death timing.
   Close-range survivor combat still prevents recovery through proximity.
6. Take human control immediately before expiry. Expect no teleport. Pass back
   to AI: expect a new observation period and preserved recovery counter and
   cooldown. Repeat with forced Tank replacement and player disconnection.
7. Test candidate areas against a low ceiling, props, players, steep ground,
   ledges, water, slime, moving platforms, checkpoints, rescue closets, nav
   blockers, rotated hurt triggers and fire spread far from an inferno's origin.
   Expect rejection, not placement in those areas.
8. Make every candidate visible to at least one survivor. Expect no recovery.
   Provide concealed candidates: inspect all survivor views and verify clearance,
   separation and the Tank's ability to pursue after recovery.
9. Re-confine a recovered Tank. Expect no second recovery during its 60-second
   cooldown and no third recovery during that life. Verify the limit and cooldown
   survive Tank passes. Spawn a new Tank: expect a fresh allowance.
10. Disable recovery, set the limit to zero, or invert destination distance
    bounds. Expect no teleport. Re-enable, restart a round, change maps, reload
    the plugin and test a reused client slot; stale dwell must not trigger an
    immediate teleport. Pause before expiry: paused wall time must not advance
    the game-time dwell period.
11. Hold the Tank stationary while survivors move toward it but remain beyond
    the live isolation distance. Expect no pursuit-progress reset. Kill or disconnect a survivor:
    expect its progress record to stop contributing without resetting dwell or
    the other survivors' records. Join or respawn a survivor: expect a new record
    without resetting dwell. Repeat with a reused survivor client slot.
12. Oscillate the Tank by less than 32 units across a nav boundary that changes
    reported route distance by more than 64 units. Expect no route-progress reset
    even if route availability changes. Hold the Tank stationary and alternate
    valid and missing route results for longer than dwell: expect no progress
    credit and normal recovery eligibility. Repeat after the Tank has displaced
    32 units, with a blocker shortening both reference and current routes by the
    same amount: expect no route credit from that topology change alone.
13. Make every candidate around the closest survivor invalid, while providing a
    valid candidate around a farther survivor. Expect recovery near the farther
    survivor with the same separation, visibility, hazard and route checks.
    Make all survivors' candidates invalid: expect no teleport, one failure log
    per observation, and another search after five seconds. Repeat while throws
    defer the first attempt: the first failure must still be logged.
14. Place two living survivors beyond isolation distance. Have the Tank make
    64 units of improvement toward the second survivor while the first remains
    alive and does not get closer. Expect a dwell reset for the second survivor.
    Alternate pursuit between the two: each must retain its own best distances.
15. Credit a 64-unit improvement, return the Tank to its earlier position and
    repeat the same excursion, staying inside the original camp radius. Expect
    no new credit on subsequent excursions. Repeat with nav-route improvement,
    and with one excursion improving distances to several survivors: all records
    must update on the first sample, without deferred resets for the same move.
    A further 64-unit improvement beyond a retained best must still restart dwell.

For unit coverage in a future engine-mocking harness, exercise the actual
observation and cooldown state transitions with a fake game clock, especially
radius/dwell/progress boundaries, bounded throw deferral, survivor-only movement,
per-survivor target changes, nav availability flips, blocker-only route changes,
repeated backtracking, nearest-survivor fallback, control transfers and slot reuse.
