class_name ChunkStreamer
extends RefCounted
## Interest management: determines which entities should be visible to each peer.
## Server-only. Uses distance-based filtering.

const STREAM_RADIUS := 256.0
const UPDATE_INTERVAL := 0.5


static func should_be_visible(player_pos: Vector3, entity_pos: Vector3, radius: float = STREAM_RADIUS) -> bool:
	return player_pos.distance_to(entity_pos) <= radius


static func get_visible_entities(
	player_pos: Vector3,
	entities: Array,
	radius: float = STREAM_RADIUS
) -> Array:
	## Returns entities within radius of the player position.
	var visible: Array = []
	for entity in entities:
		if entity is Node3D:
			if player_pos.distance_to((entity as Node3D).global_position) <= radius:
				visible.append(entity)
	return visible
