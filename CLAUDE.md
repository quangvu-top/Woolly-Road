# CLAUDE.md — notes for Claude Code (and anyone) working on Woolly Road

Read [AGENTS.md](AGENTS.md) (Horus SDK rules) and [README.md](README.md) (layout, build) first. This file adds what
was learned while building the game, so work can go on from any computer.

## Working with the user

- Reply in **Vietnamese**. The user designs from reference videos/screenshots of "Parking Loop" (cars) and the Figma
  "Bus Dash" kit; the game re-themes that to a farm (sheep, dirt road, wooden pens, stone kerbs).
- Never invent app ids, ad unit ids or the privacy URL: they come from Horus / the studio (`horus-game.json`).
- The Horus **build key** is set once per computer with `node horus-sdk/horus-build.mjs --key <key>` (stored outside
  the repo). Never print it, write it to a file in the repo, or commit it.
- Do not edit `addons/horus_sdk/` or `horus-sdk/` (the build tool replaces them on SDK updates).
- `node horus-sdk/horus-build.mjs --play` (Google Play upload) only when the user asks for it in that message.
- Before saying a change is done: run both test suites, run the screen capture, **look at the PNGs**, export the
  .pck and run the Horus dry-run. Say plainly what was not checked (real phone).

## Tools on a new computer

- **Godot 4.7.2 exactly** (Horus rejects .pck files from other versions). This machine used the portable build in
  `%LOCALAPPDATA%\Programs\Godot\` (`Godot_v4.7.2-stable_win64.exe` + `_console.exe` for headless runs);
  `OpenInGodot.cmd` / `Play.cmd` expect it there. Opening the project the first time rebuilds `.godot/`.
- **Node.js** (for `horus-sdk/horus-build.mjs`), **Git**.
- Windows PowerShell for `tools/*.ps1` (no ffmpeg needed).

## Commands (run from the project root; `G` = the Godot console exe)

```
G --headless --path . -s res://tests/run_tests.gd        # rules, solver, all 50 levels solvable + difficulty curve
G --headless --path . res://tests/autoplay.tscn          # real-time game: sample levels won by hints and played
                                                         # exactly like the puzzle model, no sheep overlap, rapid taps,
                                                         # full road, tutorial, cheats (real taps), every UX edge
G --path . --resolution 640x1387 res://tests/autoplay.tscn -- --capture build/flow_shots   # every screen as PNG
G --headless --path . --export-pack Android build/game.pck
node horus-sdk/horus-build.mjs --dry-run                 # checks the .pck, sends nothing
G --headless --path . -s res://tests/gen_levels.gd       # regenerate levels 2-50 (prints Levels.ALL lines)
```

- Windowed capture must use `--resolution 640x1387` (a 886x1920 window gets clamped to the screen height).
- `tools/cmp.ps1`, `tools/crop.ps1`: Figma vs game comparison (see README). Figma frames are exported at 1x
  (886x1920); measure the visible art, Figma node boxes are often padded.
- `tools/video_frames.ps1`: frames from a reference .mp4 (then put them on a contact sheet and read them).
- Horus docs sit behind Cloudflare Access (horusvn): read them in a browser where the user is signed in.

## How the game works (non-obvious parts)

- **UI** is laid out in Figma pixels: viewport 886x1920, stretch `canvas_items`/`expand`. HUD chain:
  `HudKit` (builders, popup stack, Android back) → `HudMeta` → `Hud`.
- **Layout** (`game.gd` `_place_queue` / `_frame_play`): camera pitch 64°, a 2-lane loop is ~70% of the screen width;
  the first 3 queue rows end at the booster tray, the rest of each column runs under it; the gap between loop and
  queue is computed from the screen so the loop + pen sit in the middle of the space above the queue. The queue's dirt
  strip joins the loop. Pen sheep face down, queue sheep face up.
- **Road**: `cap_now()` slots (5, +1 per "+1 Road" booster) spread evenly round the loop and turning together
  (`_ring`). Sheep keep their order on the road (never pass, never overlap); after any join the slots are shared out
  again in road order (`_assign_ordered`) and sheep only speed up / slow down to reach theirs.
- **Sending** (like the reference): every tap sends a sheep at once (`send`); while running it picks its pace to reach
  the road in a gap (`_steer_joiners`), commits before it can touch traffic (sheep behind then give way), otherwise
  eases to a stop just short of the road. Sheep from the same column run nose to tail. Road full: no message, the
  sheep shakes its head, the sign jolts, the stone kerbs pulse red (`_update_kerbs`), the sign text turns red.
- **Parking order = the puzzle model** (`_next_parker`): the oldest sheep on the road that has a pen parks first, in
  `Puzzle.pick_lane`'s pen; a clearing pen counts as empty. This keeps the real game identical to `Puzzle.settle`, so
  levels stay solvable and hints right. autoplay checks it ("plays out exactly like the puzzle model").
- **Levels** (`scripts/core/levels.gd`): level 1 = tutorial; 2-50 are hard levels from `tests/gen_levels.gd`
  (win chance under random taps 9.6% → 0.6%, never easier than the level before, hint search ≤ 2500 states).
- **Tutorial** (level 1, reference style): dim screen with a spotlight on one queue sheep + hand → after it parks the
  game waits on "Sheep go into the pen…" → the pushed-out sheep waits at the pen exit on "Pushed-out sheep join the
  road" → free play. Shader `assets/shaders/spotlight.gdshader`, `Hud.coach()`.
- **Testers' cheats**: tap the "Version" line 10 times (≤ 3 s apart) in Settings or Pause — it shows no reaction until
  the 10th tap — then type 0312 on the in-game keypad: Win level, add coins. It is in release builds too.
- **Lose screen** has HOME next to RETRY (with no hearts RETRY only opens Refill Lives).

## Gotchas

- GDScript lambdas capture locals by value: use an Array (or Dictionary) for state a lambda must change.
- Warnings are errors for some type issues: give a type when the value is Variant (e.g. `var step: float = ...`).
- Editing big files with sed/awk once duplicated `game.gd`; prefer exact Edit-style replacements and check
  `grep -c "^class_name" scripts/game/game.gd` is 1 afterwards.
- Compatibility renderer looks brighter than Unity: sun 0.55, ambient 0.32, metallic_specular 0.15.
- `horus-sdk/` needs its `.gdignore` (its sample addon copies would clash with `addons/horus_sdk`).
