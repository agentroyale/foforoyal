class_name WeaponSfxManager
extends Node
## Weapon sound effects manager. Autoload (WeaponSfx).
## Pool of AudioStreamPlayers with round-robin, random variation per category.
## Full Gravity Sound Gun SFX pack: 170 WAVs across 10 categories.

const POOL_SIZE := 12
const VOLUME_VARIATION := 1.5
const PITCH_MIN := 0.95
const PITCH_MAX := 1.05

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_sounds["gunshot"] = _load_group("res://assets/audio/weapons/gunshot_%d.wav", 20)
	_sounds["auto"] = _load_group("res://assets/audio/weapons/auto_%d.wav", 20)
	_sounds["burst"] = _load_group("res://assets/audio/weapons/burst_%d.wav", 20)
	_sounds["silenced"] = _load_group("res://assets/audio/weapons/silenced_%d.wav", 10)
	_sounds["shotgun"] = _load_group("res://assets/audio/weapons/shotgun_%d.wav", 20)
	_sounds["sniper"] = _load_group("res://assets/audio/weapons/sniper_%d.wav", 20)
	_sounds["reload"] = _load_group("res://assets/audio/weapons/reload_%d.wav", 30)
	_sounds["shell"] = _load_group("res://assets/audio/weapons/shell_%d.wav", 10)
	_sounds["ricochet"] = _load_group("res://assets/audio/weapons/ricochet_%d.wav", 10)
	_sounds["equip"] = _load_group("res://assets/audio/weapons/equip_%d.wav", 10)


# --- Public API ---

func play_gunshot() -> void:
	_play_random("gunshot", 0.0)

func play_auto() -> void:
	_play_random("auto", 0.0)

func play_burst() -> void:
	_play_random("burst", 0.0)

func play_silenced() -> void:
	_play_random("silenced", -2.0)

func play_shotgun() -> void:
	_play_random("shotgun", 2.0)

func play_sniper() -> void:
	_play_random("sniper", 1.0)

func play_reload() -> void:
	_play_random("reload", 0.0)

func play_shell_drop() -> void:
	_play_random("shell", -6.0)

func play_ricochet() -> void:
	_play_random("ricochet", -3.0)

func play_equip() -> void:
	_play_random("equip", 0.0)


# --- Internals ---

func _play_random(category: String, base_volume_db: float) -> void:
	var group: Array = _sounds.get(category, [])
	if group.is_empty():
		return

	var idx := _pick_non_repeat(category, group.size())
	var stream: AudioStream = group[idx]

	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE

	player.stream = stream
	player.volume_db = base_volume_db + randf_range(-VOLUME_VARIATION, VOLUME_VARIATION)
	player.pitch_scale = randf_range(PITCH_MIN, PITCH_MAX)
	player.play()


func _pick_non_repeat(category: String, count: int) -> int:
	if count <= 1:
		return 0
	var last: int = _last_played.get(category, -1)
	var idx := randi() % count
	if idx == last:
		idx = (idx + 1) % count
	_last_played[category] = idx
	return idx


func _load_group(path_pattern: String, count: int) -> Array:
	var arr: Array = []
	for i in range(1, count + 1):
		var path := path_pattern % i
		var stream := load(path) as AudioStream
		if stream:
			arr.append(stream)
	return arr
