class_name InputJitterBuffer
extends RefCounted
## Server-side jitter buffer for player inputs.
## Holds inputs for a fixed delay before consumption, absorbing network jitter.
## Inputs are sorted by sequence and deduplicated.
##
## Flow: RPC arrives -> push(seq, input) -> each tick: tick() returns input
## The buffer delay ensures smooth, steady-rate consumption even under jitter.

const BUFFER_CAPACITY := 32
const BUFFER_DELAY_TICKS := 4  # ~67ms at 60Hz — absorbs typical jitter

var _entries: Array = []  # [{seq: int, input: Dictionary, tick: int}]
var _current_tick: int = 0
var _last_consumed: Dictionary = {}
var _last_consumed_seq: int = -1
var _started: bool = false
var _start_countdown: int = BUFFER_DELAY_TICKS


func push(seq: int, input: Dictionary) -> void:
	## Add an input to the buffer. Discards old and duplicate sequences.
	# Discard already-consumed sequences
	if seq <= _last_consumed_seq:
		return

	# Duplicate check
	for e in _entries:
		if e["seq"] == seq:
			return

	_entries.append({"seq": seq, "input": input, "tick": _current_tick})
	_entries.sort_custom(_sort_by_seq)

	# Trim overflow (keep newest)
	while _entries.size() > BUFFER_CAPACITY:
		_entries.pop_front()

	if not _started:
		_started = true
		_start_countdown = BUFFER_DELAY_TICKS


func tick() -> Dictionary:
	## Called every physics tick (60Hz). Returns the input to simulate.
	## Inputs are held for BUFFER_DELAY_TICKS before becoming consumable.
	_current_tick += 1

	if not _started:
		return _last_consumed

	# Wait for initial buffer fill
	if _start_countdown > 0:
		_start_countdown -= 1
		return _last_consumed

	# Find oldest entry that has been buffered long enough
	while _entries.size() > 0:
		var entry: Dictionary = _entries[0]
		var age: int = _current_tick - (entry["tick"] as int)
		if age >= BUFFER_DELAY_TICKS:
			_entries.remove_at(0)
			_last_consumed = entry["input"]
			_last_consumed_seq = entry["seq"] as int
			return _last_consumed
		break  # Not ready yet

	# Nothing ready, repeat last input
	return _last_consumed


func get_last_consumed_seq() -> int:
	return _last_consumed_seq


func get_buffer_size() -> int:
	return _entries.size()


func get_buffered_ticks() -> int:
	## How many ticks of input are currently buffered (waiting to be consumed).
	return _entries.size()


func is_starving() -> bool:
	## Returns true if the buffer has no inputs ready and is repeating.
	return _started and _entries.size() == 0


static func _sort_by_seq(a: Dictionary, b: Dictionary) -> bool:
	return (a["seq"] as int) < (b["seq"] as int)
