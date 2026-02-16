class_name ItemUseSystem
extends Node
## Handles consumable item usage: hold to use, progress bar, heal on complete.
## Cancels if player takes damage during use.

signal use_started(item: ItemData)
signal use_progress(progress: float)
signal use_completed(item: ItemData)
signal use_cancelled()

var _using: bool = false
var _use_timer: float = 0.0
var _use_duration: float = 0.0
var _current_item: ItemData = null


func _ready() -> void:
	var hs := get_parent().get_node_or_null("HealthSystem") as HealthSystem
	if hs:
		hs.damage_taken.connect(_on_damage_taken)


func _process(delta: float) -> void:
	if not _using:
		return
	_use_timer += delta
	var progress := clampf(_use_timer / _use_duration, 0.0, 1.0)
	use_progress.emit(progress)
	if _use_timer >= _use_duration:
		_complete_use()


func try_use() -> bool:
	## Called by PlayerGathering when LMB pressed and active item is consumable.
	## Returns true if use started (consuming the input).
	if _using:
		return true  # Already using, consume input

	var inv := get_parent().get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return false

	var item := inv.get_active_item()
	if not item or not item.is_consumable:
		return false

	# Don't use if HP is full (for heal items)
	if item.heal_amount > 0.0:
		var hs := get_parent().get_node_or_null("HealthSystem") as HealthSystem
		if hs and hs.current_hp >= hs.max_hp:
			return false

	_current_item = item
	_use_duration = item.use_time
	_use_timer = 0.0
	_using = true
	use_started.emit(item)
	return true


func cancel() -> void:
	if not _using:
		return
	_using = false
	_current_item = null
	_use_timer = 0.0
	use_cancelled.emit()


func is_using() -> bool:
	return _using


func _complete_use() -> void:
	var item := _current_item
	_using = false
	_current_item = null
	_use_timer = 0.0

	if not item:
		return

	var inv := get_parent().get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv or not inv.has_item(item, 1):
		use_cancelled.emit()
		return

	# Apply effects
	if item.heal_amount > 0.0:
		var hs := get_parent().get_node_or_null("HealthSystem") as HealthSystem
		if hs:
			hs.heal(item.heal_amount)

	# Consume 1 from inventory
	inv.remove_item(item, 1)
	use_completed.emit(item)


func _on_damage_taken(_amount: float, _damage_type: int) -> void:
	if _using:
		cancel()
