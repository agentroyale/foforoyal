extends Node3D
## Debug script for test_arena: gives player starter weapons on ready.

const WEAPONS: Array[String] = [
	"res://resources/weapons/rock_weapon.tres",
	"res://resources/weapons/revolver.tres",
	"res://resources/weapons/thompson.tres",
	"res://resources/weapons/hunting_bow.tres",
]


func _ready() -> void:
	# Wait a frame so Player and PlayerInventory are ready
	await get_tree().process_frame
	var player := get_node_or_null("Player")
	if not player:
		return
	var inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return

	for path in WEAPONS:
		var weapon: WeaponData = load(path)
		inv.hotbar.add_item(weapon, 1)

	# Equip first weapon
	var wc := player.get_node_or_null("WeaponController") as WeaponController
	var first := inv.get_active_item()
	if wc and first is WeaponData:
		wc.equip_weapon(first as WeaponData)

	# Connect slot changes to equip
	inv.active_slot_changed.connect(func(_slot: int) -> void:
		var item := inv.get_active_item()
		if item is WeaponData:
			wc.equip_weapon(item as WeaponData)
	)
