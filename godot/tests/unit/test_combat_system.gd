extends GutTest
## Phase 6: Combat System unit tests.


# ─── Helpers ───

func _make_weapon(
	damage: float = 10.0,
	weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.MELEE,
	fire_rate: float = 0.5,
	max_range: float = 0.0,
	falloff_start: float = 0.0,
	magazine_size: int = 0,
	reload_time: float = 0.0
) -> WeaponData:
	var w := WeaponData.new()
	w.item_name = "TestWeapon"
	w.max_stack_size = 1
	w.category = ItemData.Category.WEAPON
	w.weapon_type = weapon_type
	w.base_damage = damage
	w.fire_rate = fire_rate
	w.max_range = max_range
	w.falloff_start = falloff_start
	w.magazine_size = magazine_size
	w.reload_time = reload_time
	return w


func _make_recoil_pattern(offsets: Array[Vector2] = [], recovery: float = 5.0) -> RecoilPattern:
	var rp := RecoilPattern.new()
	rp.offsets = offsets
	rp.recovery_speed = recovery
	return rp


func _make_armor(
	melee: float = 0.0,
	bullet: float = 0.0,
	explosive: float = 0.0
) -> ArmorData:
	var a := ArmorData.new()
	a.item_name = "TestArmor"
	a.max_stack_size = 1
	a.category = ItemData.Category.MISC
	a.protection_melee = melee
	a.protection_bullet = bullet
	a.protection_explosive = explosive
	return a


func _make_health_system(hp: float = 100.0) -> HealthSystem:
	var hs := HealthSystem.new()
	hs.max_hp = hp
	add_child_autofree(hs)
	hs.current_hp = hp
	hs._spawn_protection = 0.0  # Disable for tests
	return hs


func _make_player_with_weapon_ctrl() -> CharacterBody3D:
	var player := CharacterBody3D.new()
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	player.add_child(pivot)
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	var wc := WeaponController.new()
	wc.name = "WeaponController"
	player.add_child(wc)
	add_child_autofree(player)
	return player


# ─── Test 1: Headshot Double Damage ───

func test_headshot_double_damage() -> void:
	var base_damage := 25.0
	var head_mult := HitzoneSystem.get_multiplier(HitzoneSystem.Hitzone.HEAD)
	var chest_mult := HitzoneSystem.get_multiplier(HitzoneSystem.Hitzone.CHEST)
	var limbs_mult := HitzoneSystem.get_multiplier(HitzoneSystem.Hitzone.LIMBS)

	var head_damage := DamageCalculator.calculate_damage(base_damage, head_mult)
	var chest_damage := DamageCalculator.calculate_damage(base_damage, chest_mult)
	var limbs_damage := DamageCalculator.calculate_damage(base_damage, limbs_mult)

	assert_eq(head_mult, 2.0, "Head multiplier = 2.0")
	assert_eq(chest_mult, 1.0, "Chest multiplier = 1.0")
	assert_eq(limbs_mult, 0.5, "Limbs multiplier = 0.5")
	assert_eq(head_damage, 50.0, "Headshot = 50 (25*2.0)")
	assert_eq(chest_damage, 25.0, "Chest shot = 25 (25*1.0)")
	assert_eq(limbs_damage, 12.5, "Limbs shot = 12.5 (25*0.5)")
	assert_eq(head_damage, chest_damage * 2.0, "Head = 2x chest")


# ─── Test 2: Armor Reduces Damage ───

func test_armor_reduces_damage() -> void:
	var armor := _make_armor(0.25, 0.5, 0.1)

	var melee_prot := armor.get_protection(HealthSystem.DamageType.MELEE)
	assert_almost_eq(melee_prot, 0.25, 0.001, "Melee protection = 0.25")
	var melee_dmg := DamageCalculator.calculate_damage(40.0, 1.0, melee_prot)
	assert_almost_eq(melee_dmg, 30.0, 0.01, "40 melee * (1-0.25) = 30")

	var bullet_prot := armor.get_protection(HealthSystem.DamageType.BULLET)
	assert_almost_eq(bullet_prot, 0.5, 0.001, "Bullet protection = 0.5")
	var bullet_dmg := DamageCalculator.calculate_damage(40.0, 1.0, bullet_prot)
	assert_almost_eq(bullet_dmg, 20.0, 0.01, "40 bullet * (1-0.5) = 20")

	var fall_prot := armor.get_protection(HealthSystem.DamageType.FALL)
	assert_almost_eq(fall_prot, 0.0, 0.001, "Fall protection = 0.0")
	var fall_dmg := DamageCalculator.calculate_damage(40.0, 1.0, fall_prot)
	assert_almost_eq(fall_dmg, 40.0, 0.01, "Fall damage unaffected by armor")


# ─── Test 3: Distance Falloff ───

func test_distance_falloff() -> void:
	var base := 50.0
	var max_range := 100.0
	var falloff_start := 40.0

	var close := DamageCalculator.calculate_damage(base, 1.0, 0.0, 20.0, max_range, falloff_start)
	assert_almost_eq(close, 50.0, 0.01, "20m: full damage")

	var at_start := DamageCalculator.calculate_damage(base, 1.0, 0.0, 40.0, max_range, falloff_start)
	assert_almost_eq(at_start, 50.0, 0.01, "40m (falloff_start): full damage")

	var mid := DamageCalculator.calculate_damage(base, 1.0, 0.0, 70.0, max_range, falloff_start)
	assert_almost_eq(mid, 25.0, 0.01, "70m (midpoint): half damage")

	var far := DamageCalculator.calculate_damage(base, 1.0, 0.0, 100.0, max_range, falloff_start)
	assert_almost_eq(far, 0.0, 0.01, "100m (max_range): zero")

	var beyond := DamageCalculator.calculate_damage(base, 1.0, 0.0, 150.0, max_range, falloff_start)
	assert_almost_eq(beyond, 0.0, 0.01, "150m (beyond): zero")

	var melee := DamageCalculator.calculate_damage(base, 1.0, 0.0, 999.0, 0.0, 0.0)
	assert_almost_eq(melee, 50.0, 0.01, "Melee (range=0): full damage always")


# ─── Test 4: Recoil Pattern Application ───

func test_recoil_pattern_application() -> void:
	var pattern := _make_recoil_pattern(
		[Vector2(0.5, 1.0), Vector2(-0.3, 1.5), Vector2(0.2, 2.0)] as Array[Vector2],
		10.0
	)

	assert_eq(pattern.get_offset(0), Vector2(0.5, 1.0), "Shot 0")
	assert_eq(pattern.get_offset(1), Vector2(-0.3, 1.5), "Shot 1")
	assert_eq(pattern.get_offset(2), Vector2(0.2, 2.0), "Shot 2")

	# Wrapping
	assert_eq(pattern.get_offset(3), Vector2(0.5, 1.0), "Shot 3 wraps to 0")
	assert_eq(pattern.get_offset(4), Vector2(-0.3, 1.5), "Shot 4 wraps to 1")

	# Empty
	var empty := _make_recoil_pattern([] as Array[Vector2])
	assert_eq(empty.get_offset(0), Vector2.ZERO, "Empty -> ZERO")
	assert_eq(empty.get_offset(5), Vector2.ZERO, "Empty always ZERO")


# ─── Test 5: Recoil Recovery ───

func test_recoil_recovery() -> void:
	var pattern := _make_recoil_pattern(
		[Vector2(0.0, 10.0)] as Array[Vector2],
		20.0
	)

	var player := _make_player_with_weapon_ctrl()
	var inv := player.get_node("PlayerInventory") as PlayerInventory
	var wc := player.get_node("WeaponController") as WeaponController

	var weapon := _make_weapon(10.0, WeaponData.WeaponType.SMG, 0.1, 100.0, 50.0, 30, 2.0)
	weapon.recoil_pattern = pattern
	inv.hotbar.add_item(weapon, 1)
	wc.equip_weapon(weapon)

	# Fire once
	wc._fire(weapon)
	var recoil := wc.get_accumulated_recoil()
	assert_almost_eq(recoil.y, 10.0, 0.01, "10 degrees recoil after fire")

	# Recover 0.25s (20 deg/s * 0.25 = 5 deg)
	wc._update_recoil_recovery(0.25)
	recoil = wc.get_accumulated_recoil()
	assert_almost_eq(recoil.y, 5.0, 0.5, "~5 degrees remaining")

	# Full recovery
	wc._update_recoil_recovery(1.0)
	recoil = wc.get_accumulated_recoil()
	assert_almost_eq(recoil.length(), 0.0, 0.1, "Recoil ~0 after full recovery")


# ─── Test 6: Health Cannot Go Negative ───

func test_health_cannot_go_negative() -> void:
	var hs := _make_health_system(100.0)

	hs.take_damage(150.0)
	assert_almost_eq(hs.current_hp, 0.0, 0.01, "HP = 0.0, not -50")
	assert_true(hs.current_hp >= 0.0, "HP never negative")

	# Damage after death ignored
	hs.take_damage(50.0)
	assert_almost_eq(hs.current_hp, 0.0, 0.01, "HP stays 0 after death")


# ─── Test 7: Death On Zero HP ───

func test_death_on_zero_hp() -> void:
	var hs := _make_health_system(100.0)
	var counter := [0]  # Array as mutable reference for lambda
	hs.died.connect(func(): counter[0] += 1)

	assert_false(hs.is_dead, "Alive at start")

	hs.take_damage(50.0)
	assert_false(hs.is_dead, "Alive at 50 HP")
	assert_eq(counter[0], 0, "No death signal")

	hs.take_damage(50.0)
	assert_true(hs.is_dead, "Dead at 0 HP")
	assert_eq(counter[0], 1, "Died signal emitted once")

	# Respawn
	hs.respawn()
	assert_false(hs.is_dead, "Alive after respawn")
	assert_almost_eq(hs.current_hp, 100.0, 0.01, "Full HP after respawn")


# ─── Test 8: Fall Damage Threshold ───

func test_fall_damage_threshold() -> void:
	var player := PlayerController.new()
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	col.shape = capsule
	player.add_child(col)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	player.add_child(pivot)
	add_child_autofree(player)

	# Below threshold
	var no_dmg := player.calculate_fall_damage(5.0)
	assert_almost_eq(no_dmg, 0.0, 0.01, "5 m/s: no damage")

	# At threshold
	var at_threshold := player.calculate_fall_damage(8.0)
	assert_almost_eq(at_threshold, 0.0, 0.01, "8 m/s: no damage (threshold)")

	# Above threshold
	var above := player.calculate_fall_damage(12.0)
	assert_almost_eq(above, 40.0, 0.01, "12 m/s: (12-8)*10 = 40")

	# Lethal
	var lethal := player.calculate_fall_damage(18.0)
	assert_almost_eq(lethal, 100.0, 0.01, "18 m/s: (18-8)*10 = 100")
