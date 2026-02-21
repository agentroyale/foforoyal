extends Node
## Procedural footstep audio. Autoload (FootstepSfx), sem class_name.
## Pool de 6 AudioStreamPlayers round-robin. Gera noise+sine footstep sounds.

const POOL_SIZE := 6
const MIX_RATE := 22050
const PITCH_MIN := 0.92
const PITCH_MAX := 1.08

const WALK_INTERVAL := 0.5
const RUN_INTERVAL := 0.32
const CROUCH_INTERVAL := 0.7

const WALK_DB := -12.0
const RUN_DB := -6.0
const CROUCH_DB := -18.0
const LAND_DB := -4.0

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _walk_streams: Array[AudioStreamWAV] = []
var _run_streams: Array[AudioStreamWAV] = []
var _crouch_streams: Array[AudioStreamWAV] = []
var _land_streams: Array[AudioStreamWAV] = []
var _last_walk: int = -1
var _last_run: int = -1
var _last_crouch: int = -1
var _last_land: int = -1


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	for i in 3:
		_walk_streams.append(_generate_step(0.08, 80.0 + i * 10.0, 42 + i * 7))
	for i in 3:
		_run_streams.append(_generate_step(0.06, 100.0 + i * 15.0, 100 + i * 11))
	for i in 2:
		_crouch_streams.append(_generate_step(0.1, 60.0 + i * 8.0, 200 + i * 13))
	for i in 2:
		_land_streams.append(_generate_land(0.15, 50.0 + i * 10.0, 300 + i * 17))


func play_walk() -> void:
	_last_walk = _play(_walk_streams, _last_walk, WALK_DB)


func play_run() -> void:
	_last_run = _play(_run_streams, _last_run, RUN_DB)


func play_crouch() -> void:
	_last_crouch = _play(_crouch_streams, _last_crouch, CROUCH_DB)


func play_land(fall_speed: float) -> void:
	var db := LAND_DB + clampf((fall_speed - 5.0) * 0.5, 0.0, 6.0)
	_last_land = _play(_land_streams, _last_land, db)


func _play(streams: Array, last: int, base_db: float) -> int:
	if streams.is_empty():
		return -1
	var idx := randi() % streams.size()
	if idx == last and streams.size() > 1:
		idx = (idx + 1) % streams.size()
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = streams[idx]
	player.volume_db = base_db
	player.pitch_scale = randf_range(PITCH_MIN, PITCH_MAX)
	player.play()
	return idx


func _generate_step(duration: float, freq: float, seed_val: int) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) * (1.0 - t / duration)
		var noise := rng.randf_range(-1.0, 1.0) * 0.5
		var sine := sin(TAU * freq * t) * 0.5
		var sample := (noise + sine) * env
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


func _generate_land(duration: float, freq: float, seed_val: int) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) * (1.0 - t / duration)
		var noise := rng.randf_range(-1.0, 1.0) * 0.4
		var sine := sin(TAU * freq * t) * 0.6
		var sub_bass := sin(TAU * 30.0 * t) * 0.3 * env
		var sample := (noise + sine + sub_bass) * env
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
