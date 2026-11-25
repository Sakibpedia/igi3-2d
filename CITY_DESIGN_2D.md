# 2D design notes — Sontek Kajla top-down

## Map

`assets/maps/kajla.json` contains 6,481 OSM building polygons and 341 roads in
metres, centred on Kajla, Dhaka. `City2D.gd` selects the 1,500 footprints closest
to the centre, converts them to pixels at 3.2 px/m, and draws them once as
coloured polygons with floor bands and a gold street door. Roads are drawn as
thick polylines using the OSM road width.

Collision is not 1500 `StaticBody2D` nodes: a 220 px spatial grid maps each cell
to the building rectangles that touch it, so `is_blocked()` and `clamp_move()`
only test a handful of polygons per actor. This keeps 400+ actors affordable.

## Actors and teams

One `Actor2D` script covers every role with a team string:

| Team | Members | Behaviour |
|---|---|---|
| hero | 1 | Player-controlled, hitscan shooting, scope and thermal |
| enemy | 8–23 + commanders | Chase and shoot when alerted or close |
| neutral | 165 | Passive until attacked; retaliate as a group; air force calls 2 bombs |
| gang | 18 | Attack everyone, civilians included |
| civilian | 200 | Wander road points; death costs 200 points and raises alarm |

## Objectives

Game.gd generates 7–10 objectives per mission from the same type vocabulary as
the 3D game. `Mission2D` completes them through `on_objective_action()`,
proximity checks (`reach`, `extract`, `infiltrate`), a 25 s hold (`survive`), a
BCS MCQ panel (`bcs_gate`) and kills (`eliminate`). The last objective is always
extraction.

## Economy

Kills drop money, shops sell ammo/medkits/bandages/+25 HP upgrades, and all
currency lives in `user://igi3_2d.cfg` with medals, unlocks and ranks.

## Visuals

All sprites, the menu background and the README images are generated locally by
`tools/make_visuals.py` with Pillow from the project's own map and fonts. No paid
image generation or network access is needed to rebuild them.
