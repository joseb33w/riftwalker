# Goal
Fix three mobile-Safari defects reported on a landscape phone, without rebuilding the game:
1. Letterboxed / squished — renders in a centred box with black side-bars; start-screen
   title overlaps the class name.
2. On-screen controls (joystick, ATK/DASH) and the HP/objective HUD are off-screen / clipped.
3. Picking a colour swatch doesn't visibly recolor the hero and doesn't carry into gameplay.

# Files to touch
- `project.godot` — drop the fixed `window/handheld/orientation` (orientation lock letterboxes non-16:9 phones).
- `export_presets.cfg` — head CSS: canvas fills via `position:fixed;inset:0;width/height:100%` (more reliable than `100vw/100vh` on iOS Safari).
- `scripts/game.gd` — force `content_scale_mode=CANVAS_ITEMS` + `content_scale_aspect=EXPAND` at runtime (project setting alone isn't applied on the first web frame).
- `scripts/hud.gd` — lay joystick/ATK/DASH/HP/objective against the LIVE expanded viewport (`get_visible_rect().size`), re-fit on resize + after the first web frames; keep safe-area insets.
- `scripts/start_screen.gd` — rebuild the start UI from Containers (Margin → VBox: title pinned top, controls pinned bottom, expanding gap) so nothing overlaps/clips at any aspect; size to the live viewport.
- `scripts/assets.gd` — add `recolor_body()`: sets `albedo_color = tint` full-strength on every armour/cloth mesh of the shared-atlas KayKit hero (skips bare-skin head), preserving the toon+outline pass.
- `scripts/player.gd` — recolor the spawned gameplay hero via the same `recolor_body()` so the choice persists.

# Verification approach
- Static pre-import scan (Variant-inference / shadowed members), then `--import` + `--export-release Web` (nothreads).
- Smoke-verify with the vetted headless verifier (engine boots, canvas, clean console, frames).
- MOBILE-LAYOUT gate: drive the verifier at tall-portrait (~400x860) AND wide-landscape (~860x400); assert the canvas fills (no black side-bars), the UI root == visible rect, and ATK/DASH/joystick/HP sit inside the rect with no overlap.
- RECOLOR gate: headless scene — recolor a hero, assert a body mesh's override `albedo_color == tint`; confirm the player build path uses the same recolor (persistence).

# Out of scope
- New gameplay, worlds, enemies, models, or art changes beyond the recolor.
- Audio, real-device GPU/touch feel, networking (single-player game).
