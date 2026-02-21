extends Node
## Combat audio feedback. Autoload (CombatSfx), sem class_name.
## Procedural hit confirms, damage taken, kill ding, heartbeat.

const POOL_SIZE := 4
const MIX_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _hit_body: AudioStreamWAV
var _hit_headshot: AudioStreamWAV
var _damage_taken: AudioStreamWAV
var _kill_confirm: AudioStreamWAV
var _heartbeat: AudioStreamWAV


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_hit_body = _gen_hit_body()
	_hit_headshot = _gen_hit_headshot()
	_damage_taken = _gen_damage_taken()
	_kill_confirm = _gen_kill_confirm()
	_heartbeat = _gen_heartbeat()


func play_hit_body() -> void:
	_play_stream(_hit_body, -3.0)


func play_hit_headshot() -> void:
	_play_stream(_hit_headshot, -2.0)


func play_damage_taken() -> void:
	_play_stream(_damage_taken, -4.0)


func play_kill_confirm() -> void:
	_play_stream(_kill_confirm, -2.0)


func play_heartbeat() -> void:
	_play_stream(_heartbeat, -6.0)


func _play_stream(stream: AudioStreamWAV, db: float) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = db
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func _gen_hit_body() -> AudioStreamWAV:
	## Noise + 100Hz sine, fast cubic decay 0.12s.
	var duration := 0.12
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) ** 3
		var noise := sin(t * 7919.0) * 0.5
		var sine := sin(TAU * 100.0 * t) * 0.5
		var s16 := int(clampf((noise + sine) * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _make_wav(data)


func _gen_hit_headshot() -> AudioStreamWAV:
	## Hit body + 800Hz ping overlay.
	var duration := 0.15
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) ** 3
		var noise := sin(t * 7919.0) * 0.4
		var sine := sin(TAU * 100.0 * t) * 0.3
		var ping := sin(TAU * 800.0 * t) * 0.4 * ((1.0 - t / duration) ** 2)
		var s16 := int(clampf((noise + sine + ping) * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _make_wav(data)


func _gen_damage_taken() -> AudioStreamWAV:
	## Noise + 60Hz sine, more bass.
	var duration := 0.15
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) ** 2
		var noise := sin(t * 5347.0) * 0.4
		var sine := sin(TAU * 60.0 * t) * 0.6
		var s16 := int(clampf((noise + sine) * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _make_wav(data)


func _gen_kill_confirm() -> AudioStreamWAV:
	## Ascending ding 600Hz -> 900Hz, 0.2s.
	var duration := 0.2
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / duration) ** 2
		var freq := 600.0 + 300.0 * (t / duration)
		var s16 := int(clampf(sin(TAU * freq * t) * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _make_wav(data)


func _gen_heartbeat() -> AudioStreamWAV:
	## Lub-dub (45Hz + 55Hz, 0.6s cycle).
	var duration := 0.6
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / MIX_RATE
		var amp := 0.0
		if t < 0.12:
			amp = sin(PI * t / 0.12)
		elif t >= 0.2 and t < 0.32:
			amp = sin(PI * (t - 0.2) / 0.12) * 0.7
		var sine := sin(TAU * 45.0 * t) * 0.6 + sin(TAU * 55.0 * t) * 0.4
		var s16 := int(clampf(sine * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _make_wav(data)


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
