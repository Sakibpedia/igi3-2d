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

## Cycle 3 (after deeper playthroughs and screenshots)

Another full pass found and fixed:

| Severity | Issue | Fix |
|---|---|---|
| High | All 15 missions used the same 9-objective template | Three early and three late recipes now give 7–9 objectives with different type mixes per mission |
| Medium | Completing `infiltrate` could drop the hero inside a neighbouring building in the dense OSM city | Ring scan around the door plus road-point fallback finds a truly walkable exit |
| Medium | Interior state had no visual representation | `MarkerLayer` now draws a room with floor bands, stair marker and green exit door |
| Low | Credit was only in the README | `© S M Nazmuz Sakib • OSM contributors (ODbL)` now appears in the menu and the in-game HUD |

A parse error introduced by the exit-search patch (`var p :=` inferred from a
Variant) was caught immediately by the deep test and corrected with explicit
`Vector2` typing.

## Cycle 4 (final polish pass)

| Severity | Issue | Fix |
|---|---|---|
| Medium | Every mission used the same shops/gates/buildings as objective targets | Target selection is offset by mission index, so each operation sends the hero to different streets |
| Low | Driving had no visual feedback | A vehicle rectangle is drawn under the hero while driving |
| Low | Mission start only showed the title | Start notice now shows title, objective count and the first three objectives |

After this pass, all headless suites, all 15 deep playthroughs, the exported
Windows build and GitHub Actions are green. Further work would be feature work
(bespoke per-mission maps, full interior navigation, voiced Bengali audio,
Android export), not bug-fixing.

## Honest limitations (still open)

- **Mission variety:** missions now differ in objective recipes, but they still
  share one generated map layout and reuse the same target points. Bespoke
  per-mission map layouts would be the next large upgrade.
- **Interiors are abstract:** entering a building teleports the hero to an
  interior/roof state; there is no full multi-floor navigation mesh like the 3D game.
- **AI is lightweight:** hitscan shooting, simple chase/wander and alert flags;
  no cover system, pathfinding around buildings or squad tactics beyond shared alerts.
- **Audio:** procedural tones only — no recorded Bengali voice bank (the 3D game has one).
- **Platforms:** Windows export only; Android is not configured in this repo.
- **Map licence:** OSM data is ODbL — any redistribution must keep attribution.

These are reasonable next upgrades if the 2D project is to reach parity with the
3D campaign.
