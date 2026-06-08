# Goal
Two fixes reported by the player:
1. **Rift transition is dead** — when a rift activates and you walk into it, nothing
   happens; you can't pass through to the next world.
2. **No audio** — add sound effects and looping background music.

# Root cause (rift)
The rift trigger is an `Area3D` (`portal.gd`) with `collision_mask = 1`, but the player
`CharacterBody3D` is spawned on `collision_layer = 2` (`world.gd` `_spawn_player`). An Area3D
only reports a body whose layer is in the Area's mask — `2 & 1 == 0` — so `body_entered`
never fired for the player and `entered`/`portal_reached` was never emitted.

# Files to touch
- `scripts/portal.gd` — set `collision_mask = 2` to match the player's layer; add an
  `_physics_process` overlap poll + fire-once guard so the rift also triggers when the player
  is already standing on it the moment it opens (no fresh enter event); play the rift-open sfx.
- `scripts/audio.gd` (new) — `Audio` autoload: per-world looping music with crossfade + a
  round-robin SFX pool that survives World rebuilds.
- `project.godot` — register the `Audio` autoload.
- `scripts/{game,world,player,enemy,start_screen}.gd` — fire music/SFX on the real events
  (world music per area, swing/hit/hurt/dodge, enemy death, rift open, rift enter, UI, victory).
- `fetch_assets.sh` + `.gitignore` — fetch the 15 generated `.ogg` files from R2 like the
  other art (repo stays lean; the game already depends on this origin for every model/sky).
- `export_presets.cfg` — also exclude `tools_*.tscn` from the web pack.

# Verification approach
- Static pre-import scan (Variant-inference / shadowed members) then `--import` + `--export-release Web`.
- Headless logic verifier (`tools_verify.tscn`): drives the player INTO an active rift and asserts
  `portal_reached` fires; asserts the poll path (rift opening under a standing player); asserts
  clearing enemies opens the rift; asserts the portal mask intersects the player layer; asserts a
  closed rift does NOT transition. Audio contract: all 5 music + 10 sfx streams load, music plays.
- Browser smoke verifier (engine boots, canvas, clean console, frames render).

# Out of scope
- New worlds/enemies/gameplay or art changes. Real-device audio playback, GPU/touch feel
  (can't be exercised headless — see the PR "what I couldn't verify").
