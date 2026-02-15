extends GutTest
## Tests for procedural SFX generator.

const SFXScript = preload("res://scripts/audio/sfx_generator.gd")

var sfx: Node = null


func before_each() -> void:
	sfx = SFXScript.new()
	add_child_autofree(sfx)
	# _ready is called automatically by add_child


# ─── Test 1: All Sounds Generated ───

func test_all_sounds_generated() -> void:
	var expected_keys := [
		"place_twig", "place_wood", "place_stone", "place_metal", "place_armored",
		"upgrade_wood", "upgrade_stone", "upgrade_metal", "upgrade_armored",
		"destroy_twig", "destroy_wood", "destroy_stone", "destroy_metal", "destroy_armored",
		"snap", "invalid", "cascade",
	]
	assert_eq(sfx._sounds.size(), 17, "Should have 17 pre-generated sounds")
	for key in expected_keys:
		assert_true(sfx._sounds.has(key), "Missing sound: %s" % key)


# ─── Test 2: Stream Format ───

func test_stream_format() -> void:
	for key in sfx._sounds:
		var stream: AudioStreamWAV = sfx._sounds[key]
		assert_is(stream, AudioStreamWAV, "Sound '%s' should be AudioStreamWAV" % key)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS,
			"Sound '%s' should be FORMAT_16_BITS" % key)
		assert_eq(stream.mix_rate, 22050,
			"Sound '%s' mix_rate should be 22050" % key)


# ─── Test 3: Play Methods No Crash ───

func test_play_methods_no_crash() -> void:
	var pos := Vector3.ZERO
	sfx.play_place(0, pos)
	sfx.play_place(4, pos)
	sfx.play_upgrade(1, pos)
	sfx.play_upgrade(4, pos)
	sfx.play_destroy(0, pos)
	sfx.play_destroy(4, pos)
	sfx.play_snap(pos)
	sfx.play_invalid(pos)
	sfx.play_cascade(3)
	pass_test("All play methods called without crash")


# ─── Test 4: Pool Cycling ───

func test_pool_cycling() -> void:
	var pos := Vector3.ZERO
	var pool_size: int = sfx.POOL_SIZE
	# Play more than POOL_SIZE sounds — should wrap without crash
	for i in range(pool_size + 3):
		sfx.play_place(0, pos)
	assert_eq(sfx._pool_index, (pool_size + 3) % pool_size,
		"Pool index should wrap around correctly")
	pass_test("Pool cycling works without crash")
