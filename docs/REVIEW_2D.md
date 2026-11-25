# Neutral review and upgrade log — IGI 3 2D

Reviewed 2026-11-26 after the first release. I re-read every gameplay script and
ran a deeper playthrough-style test rather than relying only on counter-style
smoke tests. Findings are listed with their fixes.

## Issues found and fixed

| # | Severity | Issue | Fix |
|---:|---|---|---|
| 1 | High | `Esc` aborted the mission instead of pausing | Added real pause state; `Esc` toggles pause and closes panels first |
| 2 | High | Neutral forces never retaliated against the hero: `hero_attacked_flag` was declared but never set | `shoot()` now sets it whenever the hero hits an actor; `_nearest_attacker()` can target the hero |
| 3 | High | Pressing `E` on an objective that sits at a shop opened the trade panel instead of advancing the mission | Objective interaction now has priority over shops |
| 4 | Medium | "Drivable vehicles" were invisible — any road point acted as a vehicle | `City2D` now creates 9 visible car/CNG/rickshaw/pickup objects; `interact()` uses the nearest real vehicle |
| 5 | Medium | Scope only changed range/damage, with no visual feedback | `Camera2D.zoom` switches to 1.35× with the scope |
| 6 | Medium | Mission completion saved `10/9` objectives (`obj_index + 1`) | Now saves the true completed count |
| 7 | Medium | Hero could spawn inside an OSM building if the extraction point overlapped one | Spawn falls back to the first unblocked road point |
| 8 | Low | Menu used lock/star emoji that the Bengali font may not contain | Replaced with ASCII markers `[LOCKED]`, `[GOLD]`, `[NEW]` |
| 9 | Low | HUD notice timer decremented by a fixed `0.016` per frame | `HUD.tick(delta)` uses real delta |
| 10 | Low | Parachute flag existed in mission data but was unused | M06/M12 now get a short HALO drop-in tween and notice |
| 11 | Medium | Original mission test only incremented objective counters, so it could pass even if interaction/shooting/AI were broken | Added `PlayTest.tscn` + `play_test.gd`: real shoot, shop purchase, airstrike call, spawn walkability, and every objective through gameplay hooks |

## Verification after the fixes

- `powershell tools/test/run_all.ps1 -Deep` → `[PLAY2D] ALL 15 MISSIONS PASS`.
  Every mission now checks: city built, 9 vehicles, walkable spawn, hero
  aggression flag, air force airstrike, shop purchase/healing, all 9 objectives
  completed through real hooks, and extraction reached.
- City and save suites still PASS.
- Menu boots cleanly; exported Windows build launches.

## Honest limitations (not fixed in this pass)

- **Mission variety:** all 15 missions use the same objective template
  (7–10 objectives from the same type pool). Titles, reward, zone, alarm limit
  and parachute flag differ, but there are no bespoke map layouts per mission.
- **Interiors are abstract:** entering a building teleports the hero to an
  interior/roof state; there is no full multi-floor navigation mesh like the 3D game.
- **AI is lightweight:** hitscan shooting, simple chase/wander and alert flags;
  no cover system, pathfinding around buildings or squad tactics beyond shared alerts.
- **Audio:** procedural tones only — no recorded Bengali voice bank (the 3D game has one).
- **Platforms:** Windows export only; Android is not configured in this repo.
- **Map licence:** OSM data is ODbL — any redistribution must keep attribution.

These are reasonable next upgrades if the 2D project is to reach parity with the
3D campaign.
