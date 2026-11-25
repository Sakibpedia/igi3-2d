# Verification report — IGI 3 2D (2026-11-26)

Environment: Godot **4.3 stable**, Windows, headless. All commands exited 0.

## City

`godot --headless --path . res://tools/test/CityTest.tscn`

```
[CITY2D] buildings=1500 roads=341 shops=30 gates=15 points=556
[CITY2D] PASS
```

## Save / campaign data

`godot --headless --path . res://tools/test/SaveTest.tscn`

```
[SAVE2D] PASS - 15 missions, wallet, medal, unlock, save/reload, rank
```

## All 15 missions

`powershell tools/test/run_all.ps1 -Godot "<Godot 4.3 console exe>"`

| Mission | Result | Objectives | Actors | Buildings |
|---:|---|---:|---:|---:|
| M01 | PASS | 9 | 393 | 1,500 |
| M02 | PASS | 9 | 394 | 1,500 |
| M03 | PASS | 9 | 395 | 1,500 |
| M04 | PASS | 9 | 396 | 1,500 |
| M05 | PASS | 9 | 397 | 1,500 |
| M06 | PASS | 9 | 398 | 1,500 |
| M07 | PASS | 9 | 399 | 1,500 |
| M08 | PASS | 9 | 400 | 1,500 |
| M09 | PASS | 9 | 401 | 1,500 |
| M10 | PASS | 9 | 402 | 1,500 |
| M11 | PASS | 9 | 403 | 1,500 |
| M12 | PASS | 9 | 404 | 1,500 |
| M13 | PASS | 9 | 405 | 1,500 |
| M14 | PASS | 9 | 406 | 1,500 |
| M15 | PASS | 9 | 407 | 1,500 |

`[IGI2D] ALL 15 MISSIONS PASS`

## Deep playthrough test (v1.1)

`powershell tools/test/run_all.ps1 -Deep` uses `PlayTest.tscn`, which exercises
real gameplay hooks instead of only counters: shooting (including hero
aggression registration), an air-force airstrike call, a shop purchase and heal,
walkable spawn, 9 visible vehicles, and all 9 objectives per mission through
interaction/proximity/kill hooks.

`[PLAY2D] ALL 15 MISSIONS PASS` — M01 through M15, 393–407 actors each.
See [REVIEW_2D.md](REVIEW_2D.md) for the 11 issues found and fixed.

## Menu, export and launch

- Main menu headless smoke: exit 0, zero script/parse errors, custom Bengali font loads.
- `godot --headless --path . --export-release "Windows Desktop"` → `IGI3_2D.exe` (87 MB).
- The exported executable launched on Windows and stayed running for 10 s before being stopped deliberately — no startup crash.
- GitHub Actions run [45694509506](https://github.com/Sakibpedia/igi3-2d/actions/runs/45694509506) completed successfully in 55 s (import, tests, export, artifact).
