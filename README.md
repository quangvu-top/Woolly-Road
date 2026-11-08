# Woolly Road — Godot 4.7 + Horus SDK

Farm colour-sort puzzle: tap a sheep in the queue to send it onto the one-way dirt road; it walks into the pen whose
top sheep has its colour (or an empty pen). A full pen pushes its bottom sheep back out; four of a colour clears the
pen. You lose when the road is full and no sheep can find a pen.

Engine: **Godot 4.7.2** (Horus' app runs exactly this version), renderer Compatibility, portrait.
Working notes (commands, how the road/levels/tutorial/cheats work, setting up another computer): [CLAUDE.md](CLAUDE.md).
Publishing: **Horus SDK 0.30.2** (`addons/horus_sdk`, autoload `Horus`); Horus builds and signs the Android app from
`build/game.pck`. Rules for AI agents: [AGENTS.md](AGENTS.md) (copy of `horus-sdk/godot/AGENTS.md`).

## Run

Open the folder in Godot 4.7.2 and press Play. In the editor the SDK simulates the app: fake ads (the reward button
opens after 3 s), test purchases, Remote Config defaults.

## Layout

- `scripts/core/puzzle.gd` — rules, solver (`analyze`, `best_move` for Hint), seeded level generator
- `scripts/core/levels.gd` — 50 levels: 1 = tutorial, 2-50 hard levels from `tests/gen_levels.gd` (win chance under random taps 9.6% → 0.6%)
- `scripts/game/game.gd` — real-time game: road traffic, pens, push-out, clears, win/lose, boosters, tutorial,
  camera fit; rewarded ads (`extra_road`, `double_reward`, `free_booster`) and the `level_end` interstitial paced by
  `Horus.monetize.inter_due`
- UI, laid out in Figma pixels from the Bus Dash kit (viewport = Figma frame 886x1920, stretch canvas_items/expand
  fits every phone shape). Screens and how they connect: `docs/UX_FLOW.md` (diagram `docs/ux_flow.png`,
  Figma vs game `docs/figma_vs_game.png`):
  - `scripts/game/hud.gd` — Home, gameplay HUD, Pause, Settings, Levels, Keep playing?, boosters, Win, Lose + the API
  - `scripts/game/hud_meta.gd` — Loading, scene curtain, Daily Gift, Profile/Change name, Language, Privacy Policy,
    Refill Lives / Full of Heart, Starter Pack, No Ads, Shop, New booster unlocked, lose-a-heart confirms, Ads break, Rate us
  - `scripts/game/hud_kit.gd` — builders (images, 9-slice, labels, buttons, popups) and the popup stack / Android back
- `scripts/game/meta.gd` — lives (5, one back every `life_minutes`), booster unlock levels, Daily Gift cycle, nickname rules
- `scripts/game/i18n.gd` — English / Tiếng Việt (Vietnamese uses the system bold font: Lilita One has no Vietnamese letters)
- `scripts/game/sheep.gd`, `road_layout.gd`, `art.gd` — placeholder sheep + motion, board geometry, primitives
- `scripts/main.gd` — boot: `Horus.save_store`, `Horus.start`, cloud save, pending purchases, pause/back, `Horus.ready()`;
  meta flow: hearts before a level, refill (`refill_life` ad / coins), Daily Gift (`Horus.liveops` calendar), profile,
  language, `free_coins` ad, `Horus.review()` from Rate us
- `assets/ui` — PNGs exported from Figma; `assets/fonts` — Lilita One (OFL)
- `horus-sdk/` — the SDK package (has a `.gdignore` so Godot does not load its sample copies of the addon)

## Tests

```
godot --headless --path . -s res://tests/run_tests.gd          # rules/solver, values match the three.js and Unity ports
godot --headless --path . res://tests/autoplay.tscn             # sample levels, road traffic, purchases, ads, save + every UX flow edge
godot --path . --resolution 640x1387 res://tests/autoplay.tscn -- --capture build/flow_shots   # every screen (S01..S29)
```

Checking the UI against Figma: export the frames at 1x (886x1920) into a folder named `S01.png`, `S02.png`…, then
`tools/cmp.ps1 -figma <folder>` writes `build/cmp/Sxx.png` (Figma | game | 50/50 overlay | difference) and prints the
brightness of both, and `tools/crop.ps1 -id S12 -y 300 -h 700 -figma <folder>` puts one region side by side with a
grid labelled in Figma pixels. `docs/figma_vs_game.png` is the overview.

## Build the app

1. Godot: Project > Export > Android > **Export PCK/ZIP…** → `build/game.pck`
   (or `godot --headless --path . --export-pack Android build/game.pck`).
2. Double-click `horus-sdk\HorusBuild.cmd` (or `node horus-sdk/horus-build.mjs`). The build key comes from Horus.

## Still needed before a store build

- `horus-game.json`: `appId` from Horus, `privacyUrl`, the AppLovin MAX / Adjust ids under `sdk` / `android.sdk`,
  `google-services.json` — studio-provided, never invented.
- `scripts/game/hud_meta.gd`: `PRIVACY_URL` (same link as `privacyUrl`).
- Audio, real sheep model and farm art, farm-themed booster icons, a Vietnamese-capable game font,
  Winstreak and Daily Mission (in Figma, not built yet).
