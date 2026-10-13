class_name LumorixCityVisualDetailSystem
extends Node3D

var city_world: Node3D
var road_network: Node3D
var game_state: Node
var visual_root: Node3D

var detail_nodes: Array[Node3D] = []
var lamp_positions: Array[Vector3] = []
var bin_positions: Array[Vector3] = []

var detail_materials := {}

func initialize(world: Node3D, roads: Node3D, state: Node) -> void:
	city_world = world
	road_network = roads
	game_state = state

	visual_root = Node3D.new()
	visual_root.name = "CityVisualDetails"
	add_child(visual_root)

	_build_materials()
	_build_road_details()
	_build_city_props()
	_build_building_details()
	_build_coastal_details()

	print("LUMORIX VISUAL DETAIL: FAZ 2 aktif.")
	print("LUMORIX VISUAL DETAIL: ", detail_nodes.size(), " detay objesi oluşturuldu.")

func _build_materials() -> void:
	detail_materials["road_line"] = _material(Color("#e8df9b"))
	detail_materials["white"] = _material(Color("#e5e8ea"))
	detail_materials["metal"] = _material(Color("#30363b"), 0.65, 0.35)
	detail_materials["lamp"] = _material(Color("#252a2f"), 0.35, 0.45)
	detail_materials["glass"] = _material(Color("#7db4cf"), 0.15, 0.2)
	detail_materials["sidewalk"] = _material(Color("#a9aaa7"), 0.0, 0.92)
	detail_materials["bin"] = _material(Color("#394b43"), 0.0, 0.82)
	detail_materials["tree"] = _material(Color("#397544"), 0.0, 0.95)
	detail_materials["trunk"] = _material(Color("#68472f"), 0.0, 1.0)

func _material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _box(size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	visual_root.add_child(node)
	detail_nodes.append(node)
	return node

func _cylinder(radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = position
	node.material_override = material
	visual_root.add_child(node)
	detail_nodes.append(node)
	return node

func _build_road_details() -> void:
	# Ana yatay koridorlar
	_add_horizontal_road_details(0.0, 140.0, 3.2)
	_add_horizontal_road_details(32.0, 140.0, 6.2)
	_add_horizontal_road_details(64.0, 140.0, 9.0)

	# Ana dikey koridorlar
	_add_vertical_road_details(-64.0, 140.0, 3.2)
	_add_vertical_road_details(64.0, 140.0, 6.2)
	_add_vertical_road_details(-96.0, 140.0, 8.8)
	_add_vertical_road_details(96.0, 140.0, 11.4)

func _add_horizontal_road_details(z: float, half_length: float, road_width: float) -> void:
	var sidewalk_width := 1.15
	var side_z := road_width * 0.5 + sidewalk_width * 0.5

	_box(
		Vector3(half_length * 2.0, 0.10, sidewalk_width),
		Vector3(0, 0.11, z - side_z),
		detail_materials["sidewalk"]
	)

	_box(
		Vector3(half_length * 2.0, 0.10, sidewalk_width),
		Vector3(0, 0.11, z + side_z),
		detail_materials["sidewalk"]
	)

	# Kesikli orta çizgi
	var step := 12.0
	var x := -half_length + 6.0
	while x < half_length:
		_box(
			Vector3(5.0, 0.025, 0.12),
			Vector3(x, 0.15, z),
			detail_materials["road_line"]
		)
		x += step

	# Sokak lambaları
	var lx := -half_length + 10.0
	while lx < half_length:
		_add_street_lamp(Vector3(lx, 0.0, z - side_z - 0.55))
		lx += 22.0

	# Çöp kutuları
	var bx := -half_length + 18.0
	while bx < half_length:
		_add_bin(Vector3(bx, 0.0, z + side_z + 0.35))
		bx += 36.0

func _add_vertical_road_details(x: float, half_length: float, road_width: float) -> void:
	var sidewalk_width := 1.15
	var side_x := road_width * 0.5 + sidewalk_width * 0.5

	_box(
		Vector3(sidewalk_width, 0.10, half_length * 2.0),
		Vector3(x - side_x, 0.11, 0),
		detail_materials["sidewalk"]
	)

	_box(
		Vector3(sidewalk_width, 0.10, half_length * 2.0),
		Vector3(x + side_x, 0.11, 0),
		detail_materials["sidewalk"]
	)

	var step := 12.0
	var z := -half_length + 6.0
	while z < half_length:
		_box(
			Vector3(0.12, 0.025, 5.0),
			Vector3(x, 0.15, z),
			detail_materials["road_line"]
		)
		z += step

	var lz := -half_length + 10.0
	while lz < half_length:
		_add_street_lamp(Vector3(x - side_x - 0.55, 0.0, lz))
		lz += 22.0

	var bz := -half_length + 18.0
	while bz < half_length:
		_add_bin(Vector3(x + side_x + 0.35, 0.0, bz))
		bz += 36.0

func _add_street_lamp(pos: Vector3) -> void:
	var pole := _cylinder(0.08, 3.2, pos + Vector3(0, 1.6, 0), detail_materials["lamp"])
	var arm := _box(Vector3(0.65, 0.08, 0.08), pos + Vector3(0.28, 3.05, 0), detail_materials["lamp"])
	var head := _box(Vector3(0.24, 0.12, 0.22), pos + Vector3(0.58, 3.0, 0), detail_materials["white"])

	pole.name = "StreetLampPole"
	arm.name = "StreetLampArm"
	head.name = "StreetLampHead"

	lamp_positions.append(pos)

func _add_bin(pos: Vector3) -> void:
	var body := _box(Vector3(0.55, 0.75, 0.55), pos + Vector3(0, 0.38, 0), detail_materials["bin"])
	var lid := _box(Vector3(0.62, 0.08, 0.62), pos + Vector3(0, 0.79, 0), detail_materials["metal"])

	body.name = "WasteBin"
	lid.name = "WasteBinLid"
	bin_positions.append(pos)

func _build_city_props() -> void:
	# Şehir genelinde kontrollü yeşil doku.
	var tree_points := [
		Vector3(-28, 0, 18),
		Vector3(-20, 0, 22),
		Vector3(-12, 0, 26),
		Vector3(18, 0, 20),
		Vector3(26, 0, 25),
		Vector3(34, 0, 18),
		Vector3(-30, 0, -18),
		Vector3(-22, 0, -24),
		Vector3(22, 0, -20),
		Vector3(30, 0, -26),
		Vector3(42, 0, 12),
		Vector3(42, 0, -12)
	]

	for pos in tree_points:
		_add_tree(pos)

func _add_tree(pos: Vector3) -> void:
	_cylinder(0.16, 1.8, pos + Vector3(0, 0.9, 0), detail_materials["trunk"])

	var crown := _cylinder(
		1.0,
		1.5,
		pos + Vector3(0, 2.25, 0),
		detail_materials["tree"]
	)
	crown.name = "CityTree"

func _build_building_details() -> void:
	if game_state == null:
		return

	var buildings = game_state.buildings if "buildings" in game_state else []
	if not (buildings is Array):
		return

	for building in buildings:
		if not (building is Dictionary):
			continue

		var pos_value = building["position"] if building.has("position") else null
		if not (pos_value is Vector3):
			continue

		var kind := str(building["type"]) if building.has("type") else ""
		var pos: Vector3 = pos_value

		_add_facade_details(pos, kind)

func _add_facade_details(pos: Vector3, kind: String) -> void:
	var width := 4.0
	var height := 5.0

	match kind:
		"residential":
			width = 4.0
			height = 5.5
		"commercial":
			width = 5.0
			height = 6.0
		"hospital":
			width = 5.5
			height = 6.0
		"school":
			width = 5.0
			height = 4.5
		"police", "fire":
			width = 4.5
			height = 4.5
		"factory":
			width = 5.5
			height = 4.5
		_:
			width = 4.0
			height = 4.0

	# Ön cephe cam/pencere şeridi.
	var windows := _box(
		Vector3(width, 0.55, 0.08),
		pos + Vector3(0, height, -2.1),
		detail_materials["glass"]
	)
	windows.name = "FacadeWindows"

	# Giriş platformu.
	var entrance := _box(
		Vector3(min(width * 0.65, 3.5), 0.12, 1.0),
		pos + Vector3(0, 0.08, -2.5),
		detail_materials["sidewalk"]
	)
	entrance.name = "BuildingEntrance"

func _build_coastal_details() -> void:
	# Sahil tarafında yürüyüş/bisiklet aksına görsel zenginlik.
	for x in range(-60, 61, 15):
		var pos := Vector3(float(x), 0.0, -142.0)
		_add_tree(pos)

		_add_bench(Vector3(float(x) + 4.0, 0.0, -140.5))

func _add_bench(pos: Vector3) -> void:
	_box(
		Vector3(1.8, 0.12, 0.45),
		pos + Vector3(0, 0.75, 0),
		detail_materials["metal"]
	)

	_box(
		Vector3(1.6, 0.55, 0.10),
		pos + Vector3(0, 0.38, 0.18),
		detail_materials["metal"]
	)

	_box(
		Vector3(0.10, 0.7, 0.10),
		pos + Vector3(-0.65, 0.35, 0),
		detail_materials["metal"]
	)

	_box(
		Vector3(0.10, 0.7, 0.10),
		pos + Vector3(0.65, 0.35, 0),
		detail_materials["metal"]
	)

func get_visual_detail_status() -> Dictionary:
	return {
		"detail_objects": detail_nodes.size(),
		"street_lamps": lamp_positions.size(),
		"waste_bins": bin_positions.size(),
		"city_visual_phase": 2
	}
