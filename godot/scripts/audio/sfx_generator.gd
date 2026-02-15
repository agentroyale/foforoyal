extends Node
## Procedural SFX generator for building actions.
## Autoload singleton — generates AudioStreamWAV at runtime (no .wav files).

const POOL_SIZE := 8
const MIX_RATE := 22050
const TIER_NAMES := ["twig", "wood", "stone", "metal", "armored"]

var _sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0


func _ready() -> void:
	_create_pool()
	_generate_all_sounds()


func _create_pool() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


func _generate_all_sounds() -> void:
	# 5x place sounds (one per tier)
	for i in range(5):
		_sounds["place_%s" % TIER_NAMES[i]] = _gen_place(i)

	# 4x upgrade sounds (wood, stone, metal, armored — no twig upgrade)
	for i in range(1, 5):
		_sounds["upgrade_%s" % TIER_NAMES[i]] = _gen_upgrade(i)

	# 5x destroy sounds
	for i in range(5):
		_sounds["destroy_%s" % TIER_NAMES[i]] = _gen_destroy(i)

	# Utility sounds
	_sounds["snap"] = _gen_snap()
	_sounds["invalid"] = _gen_invalid()
	_sounds["cascade"] = _gen_cascade()


# ─── Public API ───

func play_place(tier: int, pos: Vector3) -> void:
	tier = clampi(tier, 0, 4)
	_play("place_%s" % TIER_NAMES[tier])


func play_upgrade(tier: int, pos: Vector3) -> void:
	tier = clampi(tier, 1, 4)
	_play("upgrade_%s" % TIER_NAMES[tier])


func play_destroy(tier: int, pos: Vector3) -> void:
	tier = clampi(tier, 0, 4)
	_play("destroy_%s" % TIER_NAMES[tier])


func play_snap(_pos: Vector3) -> void:
	_play("snap")


func play_invalid(_pos: Vector3) -> void:
	_play("invalid")


func play_cascade(count: int) -> void:
	_play("cascade")


func _play(sound_name: String) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = _sounds[sound_name]
	player.play()


# ─── Sound Generation ───

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)

	stream.data = data
	return stream


func _gen_place(tier: int) -> AudioStreamWAV:
	# Short thud — lower pitch for heavier tiers
	var duration := 0.15
	var freq := 200.0 - tier * 30.0
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := (1.0 - t / duration)
		envelope *= envelope
		samples[i] = sin(TAU * freq * t) * envelope * 0.6
	return _make_stream(samples)


func _gen_upgrade(tier: int) -> AudioStreamWAV:
	# Rising tone — higher for better tiers
	var duration := 0.25
	var base_freq := 300.0 + tier * 100.0
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var freq := base_freq + t * 400.0
		var envelope := 1.0 - t / duration
		samples[i] = sin(TAU * freq * t) * envelope * 0.5
	return _make_stream(samples)


func _gen_destroy(tier: int) -> AudioStreamWAV:
	# Noise burst + low rumble — longer for heavier tiers
	var duration := 0.3 + tier * 0.05
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + tier
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := (1.0 - t / duration)
		envelope *= envelope
		var noise := rng.randf_range(-1.0, 1.0)
		var rumble := sin(TAU * (60.0 + tier * 10.0) * t)
		samples[i] = (noise * 0.4 + rumble * 0.3) * envelope
	return _make_stream(samples)


func _gen_snap() -> AudioStreamWAV:
	# Short click
	var duration := 0.05
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := 1.0 - t / duration
		samples[i] = sin(TAU * 800.0 * t) * envelope * 0.4
	return _make_stream(samples)


func _gen_invalid() -> AudioStreamWAV:
	# Two-tone descending buzz
	var duration := 0.2
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var freq := 400.0 - t * 600.0
		var envelope := 1.0 - t / duration
		samples[i] = sin(TAU * freq * t) * envelope * 0.5
	return _make_stream(samples)


func _gen_cascade() -> AudioStreamWAV:
	# Long rumbling collapse
	var duration := 0.6
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := (1.0 - t / duration)
		var noise := rng.randf_range(-1.0, 1.0)
		var rumble := sin(TAU * 50.0 * t) + sin(TAU * 80.0 * t) * 0.5
		samples[i] = (noise * 0.3 + rumble * 0.3) * envelope
	return _make_stream(samples)
