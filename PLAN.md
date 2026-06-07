# Riftwalker — build plan

A 3rd-person 3D mobile action-adventure built in **Godot 4.6.3**, exported to the web
(`nothreads` / Compatibility renderer). The hero customizes their outfit on a start screen,
then journeys through four portal-linked worlds with juicy melee combat.

## Goal
- Start screen: pick a hero class (Knight / Barbarian / Rogue / Mage) + an accent tint, preview a
  rotating 3D hero, then "Begin Journey".
- Four compact, mobile-friendly worlds connected by portals, each a *committed* look:
  1. **Greenmoor** — medieval/fantasy outdoor at golden hour under a real photographic HDR sky;
     animated KayKit skeletons.
  2. **Helios Station** — sci-fi space station under an alien-planet sky; animated alien monsters.
  3. **The Foundry** — gritty PSX-retro industrial zone: moody, low-res, foggy, animated vermin.
  4. **Last Light** — realistic survival outpost at night (barrels, crates, campfire) under a starry
     HDR sky; animated night creatures, then the final portal home -> victory.
- Juicy melee combat in every world (aim-snap, hit-flash, spark + ring bursts, screen shake, knockback).
- On-screen touch controls (left joystick + drag-look + ATK/DASH) AND keyboard/mouse.

## Backend
None — single-player; best clear time persists in `localStorage`. No Supabase.

## Verification approach
- Headless GDScript logic tests across all four worlds: hero facing (no +Z moonwalk), melee real HP
  delta + spark/flash, enemy chase (distance shrinks) + enemy attack drops player HP, animation clip
  resolution (KayKit graft + quaternius creatures incl. flyers), collider presence, portal activation.
- Browser smoke verify (godot-verify harness): boot, clean console, multi-frame screenshots; critique
  each world's frame vs its committed art style.
- Export `nothreads` Web build, deploy `out/` to R2 preview.

## Out of scope
- Multiplayer, accounts, talking NPCs, inventory/loot economy, save slots, authoritative server.
