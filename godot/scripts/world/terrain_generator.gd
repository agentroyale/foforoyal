class_name TerrainGenerator
extends RefCounted
## Generates terrain heightmaps and meshes from noise data.
## All static methods — no scene tree needed.

const VERTEX_SPACING := 16.0  # 256m chunk / 16 quads = 16m per quad
const VERTICES_PER_SIDE := 17  # 16 quads + 1 edge vertex
const HEIGHT_SCALE := 60.0  # max terrain height in meters


static func generate_heightmap(noise: FastNoiseLite, chunk_x: int, chunk_z: int, chunk_size: int) -> PackedFloat32Array:
	## Generates a 17x17 heightmap for one chunk. Values are world-space Y heights.
	var map := PackedFloat32Array()
	map.resize(VERTICES_PER_SIDE * VERTICES_PER_SIDE)
	var spacing := float(chunk_size) / (VERTICES_PER_SIDE - 1)
	var origin_x := chunk_x * chunk_size
	var origin_z := chunk_z * chunk_size
	for z in VERTICES_PER_SIDE:
		for x in VERTICES_PER_SIDE:
			var world_x := origin_x + x * spacing
			var world_z := origin_z + z * spacing
			# noise returns -1..1, remap to 0..HEIGHT_SCALE
			var n := noise.get_noise_2d(world_x, world_z)
			map[z * VERTICES_PER_SIDE + x] = (n + 1.0) * 0.5 * HEIGHT_SCALE
	return map


static func get_height_from_map(heightmap: PackedFloat32Array, local_x: float, local_z: float, chunk_size: int) -> float:
	## Interpolates height at a fractional local position (0..chunk_size).
	var spacing := float(chunk_size) / (VERTICES_PER_SIDE - 1)
	var fx := clampf(local_x / spacing, 0.0, VERTICES_PER_SIDE - 1.0)
	var fz := clampf(local_z / spacing, 0.0, VERTICES_PER_SIDE - 1.0)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	# Clamp to valid indices
	var ix1 := mini(ix + 1, VERTICES_PER_SIDE - 1)
	var iz1 := mini(iz + 1, VERTICES_PER_SIDE - 1)
	# Bilinear interpolation
	var h00 := heightmap[iz * VERTICES_PER_SIDE + ix]
	var h10 := heightmap[iz * VERTICES_PER_SIDE + ix1]
	var h01 := heightmap[iz1 * VERTICES_PER_SIDE + ix]
	var h11 := heightmap[iz1 * VERTICES_PER_SIDE + ix1]
	var h0 := lerpf(h00, h10, tx)
	var h1 := lerpf(h01, h11, tx)
	return lerpf(h0, h1, tz)


static func build_terrain_mesh(heightmap: PackedFloat32Array, chunk_origin: Vector3, lod: int, biome_colors: PackedColorArray) -> ArrayMesh:
	## Builds an ArrayMesh from heightmap data. LOD 0=full, 1=half, 2=quarter.
	## biome_colors: parallel to heightmap, one Color per vertex for biome tinting.
	var step := 1 << lod  # 1, 2, or 4
	var verts_side := (VERTICES_PER_SIDE - 1) / step + 1  # 17, 9, or 5

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Generate vertices
	for z in verts_side:
		for x in verts_side:
			var hx := x * step
			var hz := z * step
			var idx := hz * VERTICES_PER_SIDE + hx
			var pos := Vector3(hx * VERTEX_SPACING, heightmap[idx], hz * VERTEX_SPACING)
			vertices.append(pos)
			if biome_colors.size() > idx:
				colors.append(biome_colors[idx])
			else:
				colors.append(Color(0.35, 0.45, 0.25))  # default grassland

	# Generate normals from cross products
	normals.resize(vertices.size())
	for i in normals.size():
		normals[i] = Vector3.UP
	for z in verts_side:
		for x in verts_side:
			var vi := z * verts_side + x
			var left := vertices[vi - 1] if x > 0 else vertices[vi]
			var right := vertices[vi + 1] if x < verts_side - 1 else vertices[vi]
			var down := vertices[(z - 1) * verts_side + x] if z > 0 else vertices[vi]
			var up := vertices[(z + 1) * verts_side + x] if z < verts_side - 1 else vertices[vi]
			var dx := right - left
			var dz := up - down
			normals[vi] = dz.cross(dx).normalized()

	# Generate triangle indices
	for z in verts_side - 1:
		for x in verts_side - 1:
			var tl := z * verts_side + x
			var tr := tl + 1
			var bl := (z + 1) * verts_side + x
			var br := bl + 1
			# Two triangles per quad (CCW winding for upward-facing normals)
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)
			indices.append(bl)
			indices.append(tr)
			indices.append(br)

	# Build mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_collision_shape(heightmap: PackedFloat32Array, chunk_size: int, lod: int) -> HeightMapShape3D:
	## Builds a HeightMapShape3D for physics from heightmap data.
	var step := 1 << lod
	var side := (VERTICES_PER_SIDE - 1) / step + 1

	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for z in side:
		for x in side:
			var hx := x * step
			var hz := z * step
			heights[z * side + x] = heightmap[hz * VERTICES_PER_SIDE + hx]

	var shape := HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = heights
	return shape
