# Riftwalker

A 3rd-person 3D **mobile action-adventure** built in **Godot 4.6.3** and exported to the web
(`nothreads`, Compatibility / WebGL2 renderer). Forge a hero on the start screen, then walk the rifts
through four hand-built worlds, carving through animated foes with juicy melee combat.

> Play the live build: see the preview link in the pull request.

## The journey

1. **Greenmoor** — an open medieval/fantasy meadow at golden hour under a real photographic HDR sky.
   Roaming, animated **KayKit skeletons** patrol the ruins.
2. **Helios Station** — a sci-fi orbital bay of modular metal cargo modules under an alien-planet sky,
   lit by emissive accent strips. Alien monsters and drones swarm in.
3. **The Foundry** — a gritty **PSX-retro** industrial zone: low render scale, nearest-filter grime,
   thick desaturated fog. Vermin scuttle through the rust.
4. **Last Light** — a realistic survival outpost at night (barrels, crates, a flickering campfire)
   under a starry HDR sky. Bats, skeletons and rats close in. Survive, and the final rift takes you home.

Clear every foe in an area to open its rift, then step through to the next world. Reach the end for a
victory clear-time (your best time is saved locally).

## Features

- **Hero customization** — pick a class (Knight / Barbarian / Rogue / Mage — each a distinct rigged
  model with class-tuned stats and attack) and an accent colour, previewed live as a rotating 3D hero.
- **Juicy melee combat** — aim-snap so a stationary tap never whiffs, hit-flash, spark + ring impact
  bursts, floating damage, knockback and screen shake on every connect.
- **Committed art per world** — real `.glb` models, HDR/LDR skyboxes, textured ground shaders, an
  inverted-hull ink outline + toon ramp on the hero, golden-hour / sci-fi / PSX / night lighting moods.
- **Animated enemies with real AI** — chase, attack, stagger and die, including flyers (wasps, bats).
- **Mobile-first controls** — floating left joystick to move, drag the right side to look, on-screen
  ATK / DASH buttons, safe-area-aware HUD. Full keyboard/mouse fallback (WASD, J = attack, Space = dash,
  Shift = run, mouse-drag = look).
- **Original soundtrack + SFX** — five looping music loops (a menu theme plus one per world, each
  scored to its mood) crossfaded on every world swap, and reactive sound effects for swings, hits,
  hurts, dashes, enemy deaths, rift open/enter, UI and victory. All procedurally synthesised, CC0.

## Run / build it yourself

Requires **Godot 4.6.3** (stable).

```bash
./fetch_assets.sh      # downloads the CC0/CC-BY art + audio into models/, skies/, textures/, audio/
# then open the project in Godot 4.6.3 and press Play, or export to Web:
#   godot --headless --import
#   godot --headless --export-release "Web" out/index.html
```

The art and audio are **not committed** to keep the repo lean; `fetch_assets.sh` pulls the exact set
used. The deployed web build bundles everything, so the preview link is fully self-contained.

## Project layout

```
project.godot          Compatibility renderer + dual touch/keyboard input map
export_presets.cfg     Web preset (nothreads, mobile head-include, viewport-fit=cover)
scenes/Main.tscn       script-driven root (game.gd)
scripts/
  game.gd              state machine: title -> customize -> 4 worlds -> victory, fades, respawn
  start_screen.gd      outfit customization with a live SubViewport hero preview
  world.gd             generic world builder (env/sky/fog/lights/ground/props/enemies/portal)
  world_defs.gd        hero classes, tint swatches, world titles
  player.gd            hero: camera-relative movement, run/dodge, melee combat, health, animation
  enemy.gd             chase/attack AI; KayKit skeleton retarget OR self-rigged quaternius creatures
  camera_rig.gd        SpringArm3D follow camera with drag-look + shake
  hud.gd               touch joystick + look + buttons, health, objective, banner, portal compass
  portal.gd            rift Area3D with swirling FX + activation gate (layer-matched trigger)
  assets.gd            model loading, shared KayKit anim library + skeleton graft, styling, colliders
  fx.gd                spark bursts, hit-flash, ring impact, floating damage
  audio.gd             "Audio" autoload: crossfaded per-world music + round-robin SFX pool
shaders/               outline, fresnel rim, ground, PSX ground, brightness-correct HDRI sky
audio/                 5 music loops + 10 SFX (.ogg, fetched via fetch_assets.sh)
```

## Credits

All art is CC0 except where noted — see [CREDITS.md](CREDITS.md). The PSX industrial environment is
**CC-BY-4.0 by godgoldfear** and is credited in-repo per its licence.

No backend: Riftwalker is fully single-player; the only persisted value is your best clear time in
`localStorage`.
