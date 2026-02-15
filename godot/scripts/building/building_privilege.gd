class_name BuildingPrivilege
extends RefCounted
## Queries all Tool Cupboards to determine building privilege at a position.
## Static utility — no instance needed.

enum PrivilegeStatus {
	NO_TC,         ## No TC covers this position — free building
	AUTHORIZED,    ## Player is authorized in at least one covering TC
	UNAUTHORIZED,  ## TC covers this position but player is NOT authorized
}


static func check_privilege(tree: SceneTree, world_position: Vector3, player_id: int) -> PrivilegeStatus:
	var tcs := tree.get_nodes_in_group("tool_cupboards")
	var inside_any_tc := false

	for node in tcs:
		var tc := node as ToolCupboard
		if not tc:
			continue
		if tc.is_position_in_range(world_position):
			inside_any_tc = true
			if tc.is_authorized(player_id):
				return PrivilegeStatus.AUTHORIZED

	if inside_any_tc:
		return PrivilegeStatus.UNAUTHORIZED
	return PrivilegeStatus.NO_TC


static func can_build(tree: SceneTree, world_position: Vector3, player_id: int) -> bool:
	var status := check_privilege(tree, world_position, player_id)
	return status != PrivilegeStatus.UNAUTHORIZED


static func get_covering_tcs(tree: SceneTree, world_position: Vector3) -> Array[ToolCupboard]:
	var result: Array[ToolCupboard] = []
	var tcs := tree.get_nodes_in_group("tool_cupboards")
	for node in tcs:
		var tc := node as ToolCupboard
		if tc and tc.is_position_in_range(world_position):
			result.append(tc)
	return result
