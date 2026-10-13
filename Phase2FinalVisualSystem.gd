class_name LumorixPhase2FinalVisualSystem
extends Node3D

var visual_root: Node3D
var world_root: Node3D
var road_system: Node3D
var game_state
var detail_nodes_created := 0
var max_detail_nodes := 1100

var mat_road
var mat_sidewalk
var mat_marking
var mat_lamp
var mat_bin
var mat_window
var mat_vehicle
var mat_tree
var mat_green
var mat_water
var mat_bridge
var mat_signal

func initialize(p_world_root: Node3D, p_road_system: Node3D, p_game_state) -> void:
    world_root = p_world_root
    road_system = p_road_system
    game_state = p_game_state

    visual_root = Node3D.new()
    visual_root.name = "Phase2FinalVisualDetails"
    add_child(visual_root)

    _create_materials()
    _build_road_details()
    _build_building_details()
    _build_environment_details()
    _build_transport_details()
    _build_special_location_details()
    _build_coast_details()

func _create_materials() -> void:
    mat_road = _mat(Color(0.055, 0.060, 0.070))
    mat_sidewalk = _mat(Color(0.34, 0.36, 0.38))
    mat_marking = _mat(Color(0.92, 0.88, 0.60))
    mat_lamp = _mat(Color(0.18, 0.20, 0.22))
    mat_bin = _mat(Color(0.12, 0.25, 0.16))
    mat_window = _mat(Color(0.22, 0.45, 0.58))
    mat_vehicle = _mat(Color(0.25, 0.28, 0.32))
    mat_tree = _mat(Color(0.16, 0.34, 0.15))
    mat_green = _mat(Color(0.25, 0.48, 0.20))
    mat_water = _mat(Color(0.10, 0.32, 0.48))
    mat_bridge = _mat(Color(0.30, 0.31, 0.33))
    mat_signal = _mat(Color(0.10, 0.10, 0.11))

func _mat(color: Color):
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.72
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material, node_name := "Detail") -> Node3D:
    if detail_nodes_created >= max_detail_nodes:
        return null
    var n := MeshInstance3D.new()
    n.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    detail_nodes_created += 1
    return n

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material, node_name := "Detail") -> Node3D:
    if detail_nodes_created >= max_detail_nodes:
        return null
    var n := MeshInstance3D.new()
    n.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    n.mesh = mesh
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    detail_nodes_created += 1
    return n

func _build_road_details() -> void:
    if road_system == null:
        return

    var roads = road_system.get("roads") if "roads" in road_system else {}
    if typeof(roads) != TYPE_DICTIONARY:
        return

    for key in roads:
        if detail_nodes_created >= max_detail_nodes:
            break
        var road = roads[key]
        if typeof(road) != TYPE_DICTIONARY:
            continue

        var pos_value = road["position"] if road.has("position") else Vector3.ZERO
        var length_value = float(road["length"]) if road.has("length") else 30.0
        var width_value = float(road["width"]) if road.has("width") else 8.0
        var pos := Vector3(pos_value)

        # Sidewalks
        _box(visual_root, Vector3(length_value, 0.16, 1.1),
            pos + Vector3(0, 0.10, width_value * 0.5 + 0.65), mat_sidewalk, "Sidewalk")
        _box(visual_root, Vector3(length_value, 0.16, 1.1),
            pos + Vector3(0, 0.10, -width_value * 0.5 - 0.65), mat_sidewalk, "Sidewalk")

        # Center/edge markings
        for x in range(-4, 5):
            var mark_x: float = float(x) * maxf(4.0, length_value / 10.0)
            if abs(mark_x) < length_value * 0.5:
                _box(visual_root, Vector3(2.0, 0.025, 0.12),
                    pos + Vector3(mark_x, 0.09, 0), mat_marking, "RoadMarking")

        # Street lamps
        for x in [-0.35, 0.0, 0.35]:
            var lx: float = pos.x + length_value * x
            _cylinder(visual_root, 0.07, 3.2,
                Vector3(lx, 1.6, pos.z + width_value * 0.5 + 1.05),
                mat_lamp, "StreetLamp")
            _box(visual_root, Vector3(0.55, 0.08, 0.12),
                Vector3(lx, 3.15, pos.z + width_value * 0.5 + 1.05),
                mat_lamp, "LampHead")

        # Bins
        for side in [-1.0, 1.0]:
            _box(visual_root, Vector3(0.45, 0.70, 0.45),
                pos + Vector3(length_value * 0.25, 0.40, side * (width_value * 0.5 + 0.9)),
                mat_bin, "TrashContainer")

func _build_building_details() -> void:
    if world_root == null:
        return

    var buildings = game_state.buildings if game_state != null and "buildings" in game_state else []

    if typeof(buildings) != TYPE_ARRAY:
        return

    for building in buildings:
        if detail_nodes_created >= max_detail_nodes:
            break
        if typeof(building) != TYPE_DICTIONARY:
            continue

        var pos_value = building["position"] if building.has("position") else null
        if pos_value == null:
            continue

        var pos := Vector3(pos_value)
        var kind := str(building["type"]) if building.has("type") else "building"

        _building_facade(pos, kind)

func _building_facade(pos: Vector3, kind: String) -> void:
    var width := 4.0
    var height := 5.0

    if kind in ["hospital", "school", "university"]:
        width = 5.5
        height = 7.0
    elif kind in ["mall", "stadium", "hotel"]:
        width = 7.0
        height = 9.0

    # Main entrance
    _box(visual_root, Vector3(1.25, 1.7, 0.22),
        pos + Vector3(0, 0.85, width * 0.5 + 0.05),
        mat_road, "BuildingEntrance")

    # Window rhythm
    var rows := clampi(int(height / 1.7), 2, 5)
    var columns := clampi(int(width / 1.3), 2, 5)

    for row in range(rows):
        for col in range(columns):
            if detail_nodes_created >= max_detail_nodes:
                return
            var wx: float = -width * 0.5 + 0.75 + float(col) * (width - 1.0) / float(maxi(1, columns - 1))
            var wy := 1.4 + row * 1.45
            _box(visual_root, Vector3(0.55, 0.65, 0.10),
                pos + Vector3(wx, wy, width * 0.5 + 0.04),
                mat_window, "FacadeWindow")

func _build_environment_details() -> void:
    if world_root == null:
        return

    # Structured greenery around the starting city.
    for i in range(36):
        if detail_nodes_created >= max_detail_nodes:
            break

        var x := float((i % 9) - 4) * 8.0
        var z := float((i / 9) - 2) * 9.0

        _cylinder(visual_root, 0.28, 1.4,
            Vector3(x, 0.70, z), mat_lamp, "TreeTrunk")
        _cylinder(visual_root, 1.15, 2.0,
            Vector3(x, 2.0, z), mat_tree, "TreeCrown")

        if i % 3 == 0:
            _box(visual_root, Vector3(0.8, 0.55, 0.8),
                Vector3(x + 1.2, 0.30, z + 0.8), mat_green, "Bush")

    # Extra bins at public spaces.
    for i in range(10):
        _box(visual_root, Vector3(0.45, 0.70, 0.45),
            Vector3(float(i - 5) * 6.0, 0.40, -18.0),
            mat_bin, "PublicBin")

func _build_transport_details() -> void:
    if road_system == null:
        return

    for i in range(12):
        if detail_nodes_created >= max_detail_nodes:
            break

        var x := float(i - 6) * 5.0
        var z := 11.0 if i % 2 == 0 else -11.0

        _box(visual_root, Vector3(1.8, 0.65, 3.2),
            Vector3(x, 0.45, z), mat_vehicle, "CityVehicle")
        _box(visual_root, Vector3(1.35, 0.35, 1.0),
            Vector3(x, 0.88, z - 0.15), mat_window, "VehicleWindow")

func _build_special_location_details() -> void:
    # Metro / station entrances
    for i in range(3):
        var x := float(i - 1) * 16.0
        _box(visual_root, Vector3(4.0, 0.35, 2.0),
            Vector3(x, 0.20, 22.0), mat_bridge, "MetroEntrance")
        _box(visual_root, Vector3(3.0, 1.8, 0.20),
            Vector3(x, 1.05, 22.95), mat_window, "StationGlass")

    # Airport/port visual anchors
    _box(visual_root, Vector3(24.0, 0.25, 5.0),
        Vector3(35.0, 0.15, 25.0), mat_bridge, "AirportApron")
    _box(visual_root, Vector3(22.0, 0.35, 4.0),
        Vector3(-35.0, 0.25, 25.0), mat_bridge, "PortDock")

func _build_coast_details() -> void:
    _box(visual_root, Vector3(90.0, 0.20, 7.0),
        Vector3(0, -0.05, 42.0), mat_water, "CoastalWater")

    for i in range(12):
        if detail_nodes_created >= max_detail_nodes:
            break

        var x := float(i - 6) * 7.0

        _box(visual_root, Vector3(5.5, 0.14, 1.5),
            Vector3(x, 0.12, 37.5), mat_sidewalk, "CoastalWalk")
        _box(visual_root, Vector3(5.5, 0.10, 0.7),
            Vector3(x, 0.20, 35.9), mat_marking, "BikePath")

        if i % 2 == 0:
            _cylinder(visual_root, 0.05, 2.0,
                Vector3(x, 1.0, 36.9), mat_lamp, "CoastalLamp")

func get_status() -> Dictionary:
    return {
        "system": "Phase2FinalVisualSystem",
        "detail_nodes_created": detail_nodes_created,
        "max_detail_nodes": max_detail_nodes,
        "status": "ready"
    }
