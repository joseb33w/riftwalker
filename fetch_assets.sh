#!/usr/bin/env bash
# Fetch the CC0 / CC-BY art used by Riftwalker into res:// folders.
# Run once after cloning, then open the project in Godot 4.6.3.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
A="https://preview.myapping.com/godot-assets"
T="https://preview.myapping.com/godot-textures"
AUD="https://preview.myapping.com/riftwalker-audio"
mkdir -p "$ROOT/models" "$ROOT/skies" "$ROOT/textures" "$ROOT/audio"

dl() { # url dest
	if [ -f "$2" ]; then return; fi
	curl -sfL "$1" -o "$2" || { echo "FAILED $1"; return 1; }
	echo "  $(basename "$2")"
}

echo "Characters + enemies..."
for m in kk_Knight kk_Barbarian kk_Rogue kk_Mage; do dl "$A/characters/$m.glb" "$ROOT/models/$m.glb"; done
for m in skeleton_warrior skeleton_minion skeleton_rogue q_monster_slime q_enemy_spider q_enemy_rat q_monster_skeleton q_monster_bat q_enemy_wasp; do
	dl "$A/enemies/$m.glb" "$ROOT/models/$m.glb"; done

echo "Props..."
for m in building_blacksmith_blue building_tower_B_blue building_well_blue building_market_blue; do dl "$A/props/kk_hex/$m.glb" "$ROOT/models/$m.glb"; done
for m in basemodule_A cargo_A containers_B containers_D cargodepot_A lander_base; do dl "$A/props/kk_space/$m.glb" "$ROOT/models/$m.glb"; done
for m in ms_campfire ms_control_box ms_cabinet_basic ms_cable_reel ms_brick_pile; do dl "$A/props/vostok_realistic/$m.glb" "$ROOT/models/$m.glb"; done
for m in Barrel_A Barrel_C Box_B; do dl "$A/props/kk_prototype/$m.glb" "$ROOT/models/$m.glb"; done
dl "$A/props/q_platfbx/Crate.glb" "$ROOT/models/Crate.glb"
dl "$A/props/psx_industrial/industrialhorror_ps_like.glb" "$ROOT/models/industrialhorror_ps_like.glb"

echo "Nature (Kenney)..."
for m in tree_blocks tree_blocks_dark tree_blocks_fall tree_cone tree_cone_dark plant_bushLarge plant_bushDetailed rock_largeA rock_largeC stone_largeB grass_large; do
	dl "$A/nature/$m.glb" "$ROOT/models/$m.glb"; done

echo "Ground textures..."
for t in grass metal_panel stone_floor dirt_ground; do dl "$T/$t.png" "$ROOT/textures/$t.png"; done

echo "Skies..."
dl "$A/skies/ph_belfast_sunset_puresky.hdr" "$ROOT/skies/w1_golden.hdr"
dl "$A/skies/sb_planet_2.png"               "$ROOT/skies/w2_planet.png"
dl "$A/skies/sb_cloudy_2.png"               "$ROOT/skies/w3_cloudy.png"
dl "$A/skies/acg_nightskyhdri003.exr"       "$ROOT/skies/w4_night.exr"

echo "Audio (procedural music + sfx)..."
for s in music_menu music_w0 music_w1 music_w2 music_w3 \
         sfx_swing sfx_hit sfx_enemy_death sfx_hurt sfx_dodge \
         sfx_portal_open sfx_portal_enter sfx_ui sfx_begin sfx_victory; do
	dl "$AUD/$s.ogg" "$ROOT/audio/$s.ogg"
done

echo "Done. Open the project in Godot 4.6.3 (it will import on first launch)."
