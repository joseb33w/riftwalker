extends Node

# Global audio manager (autoload "Audio"). Holds the looping per-world music
# (crossfaded on world swap) and a round-robin SFX pool, so playback survives
# the World node being freed and rebuilt between areas. The WebAudio context is
# suspended until the first user gesture; the title tap-to-begin supplies it, so
# music started at/after that point becomes audible immediately.

const MUSIC := {
	"menu": "res://audio/music_menu.ogg",
	"w0": "res://audio/music_w0.ogg",
	"w1": "res://audio/music_w1.ogg",
	"w2": "res://audio/music_w2.ogg",
	"w3": "res://audio/music_w3.ogg",
}

const SFX := {
	"swing": "res://audio/sfx_swing.ogg",
	"hit": "res://audio/sfx_hit.ogg",
	"enemy_death": "res://audio/sfx_enemy_death.ogg",
	"hurt": "res://audio/sfx_hurt.ogg",
	"dodge": "res://audio/sfx_dodge.ogg",
	"portal_open": "res://audio/sfx_portal_open.ogg",
	"portal_enter": "res://audio/sfx_portal_enter.ogg",
	"ui": "res://audio/sfx_ui.ogg",
	"begin": "res://audio/sfx_begin.ogg",
	"victory": "res://audio/sfx_victory.ogg",
}

const MUSIC_DB := -11.0
const QUIET_DB := -45.0
const SFX_DB := -4.0
const POOL := 10

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_key := ""
var _music_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_music()
	_music_b = _make_music()
	_active_music = _music_a
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_sfx_players.append(p)
	for k: String in SFX:
		_sfx_cache[k] = _load_stream(SFX[k], false)

func _make_music() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = QUIET_DB
	add_child(p)
	return p

func _load_stream(path: String, loop: bool) -> AudioStream:
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	return s

# Crossfade to a music key. No-op if that track is already the active one.
func play_music(key: String, fade: float = 0.8) -> void:
	if not MUSIC.has(key):
		return
	if key == _current_key and _active_music.playing:
		return
	_current_key = key
	var nxt := _music_b if _active_music == _music_a else _music_a
	var prev := _active_music
	nxt.stream = _load_stream(MUSIC[key], true)
	nxt.volume_db = QUIET_DB
	nxt.play()
	_active_music = nxt
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(nxt, "volume_db", MUSIC_DB, fade)
	if prev != nxt and prev.playing:
		_music_tween.tween_property(prev, "volume_db", QUIET_DB, fade)
		_music_tween.chain().tween_callback(prev.stop)

func stop_music(fade: float = 0.6) -> void:
	_current_key = ""
	if not _active_music.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var p := _active_music
	_music_tween = create_tween()
	_music_tween.tween_property(p, "volume_db", QUIET_DB, fade)
	_music_tween.tween_callback(p.stop)

# Fire a one-shot sound effect from the round-robin pool, with slight pitch jitter.
func sfx(key: String, pitch_var: float = 0.06, vol_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx_cache.get(key, null)
	if stream == null:
		if not SFX.has(key):
			return
		stream = _load_stream(SFX[key], false)
		_sfx_cache[key] = stream
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = SFX_DB + vol_db
	p.play()
