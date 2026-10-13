class_name LumorixCityVisualQualitySystem
extends Node3D

# FAZ 2 - Görsel kalite ve mobil detay bütçesi.
# Amaç: şehirdeki temel geometriyi daha zengin göstermek,
# fakat kontrolsüz MeshInstance3D üretimini engellemek.

var world_root: Node3D
var road_system: Node3D
var game_state: Node
var visual_root: Node3D

var max_detail_nodes: int = 850
var detail_nodes_created: int = 0
var detail_distance: float = 125.0

var mat_road_marking: StandardMaterial3D
var mat_sidewalk: StandardMaterial3D
var mat_lamp: StandardMaterial3D
var mat_bin: StandardMaterial3D
var mat_tree: StandardMaterial3D
var mat_tree_dark: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_facade: StandardMaterial3D
var mat_facade_dark: StandardMaterial3D
var mat_signal_red: StandardMaterial3D
var mat_signal_yellow: StandardMaterial3D
var mat_signal_green: StandardMaterial3D
var mat_water: StandardMaterial3D

func initialize(p_world_root: Node3D, p_road_system: Node3D, p_game_state: Node) -> void:
    world_root = p_world_root
    road_system = p_road_system
    game_state = p_game_state

    visual_root = Node3D.new()
    visual_root.name = "MobileVisualDetails"
    world_root.add_child(visual_root)

    _create_materials()
    _build_city_quality_pass()

func _create_materials() -> void:
    mat_road_marking = _material(Color(0.92, 0.90, 0.72))
    mat_sidewalk = _material(Color(0.48, 0.48, 0.45))
    mat_lamp = _material(Color(0.12, 0.13, 0.14))
    mat_bin = _material(Color(0.16, 0.22, 0.19))
    mat_tree = _material(Color(0.16, 0.38, 0.18))
    mat_tree_dark = _material(Color(0.08, 0.25, 0.12))
    mat_glass = _material(Color(0.22, 0.42, 0.50), 0.72)
    mat_facade = _material(Color(0.66, 0.67, 0.65))
    mat_facade_dark = _material(Color(0.25, 0.28, 0.30))
    mat_signal_red = _material(Color(0.85, 0.08, 0.06))
    mat_signal_yellow = _material(Color(0.90, 0.68, 0.08))
    mat_signal_green = _material(Color(0.08, 0.72, 0.22))
    mat_water = _material(Color(0.10, 0.34, 0.46))

func _material(color: Color, transparency: float = 1.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.72
    if transparency < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.albedo_color.a = transparency
    return material

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    if detail_nodes_created >= max_detail_nodes:
        return null

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name

    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material

    parent.add_child(mesh_instance)
    detail_nodes_created += 1
    return mesh_instance

func _cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    if detail_nodes_created >= max_detail_nodes:
        return null

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name

    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material

    parent.add_child(mesh_instance)
    detail_nodes_created += 1
    return mesh_instance

func _build_city_quality_pass() -> void:
    _build_road_quality()
    _build_building_quality()
    _build_environment_quality()
    _build_coastal_quality()
    _build_special_locations()

func _build_road_quality() -> void:
    if road_system == null:
        return

    var road_nodes := road_system.get_children()
    for node in road_nodes:
        if detail_nodes_created >= max_detail_nodes:
            break
        if not (node is Node3D):
            continue

        var road: Node3D = node
        var road_name := road.name.to_lower()

        if "road" in road_name or "highway" in road_name:
            _add_road_markings(road)
            _add_sidewalks(road)
            _add_lamps_near_road(road)

        if "traffic" in road_name or "signal" in road_name:
            _add_signal_detail(road)

        if "bridge" in road_name or "overpass" in road_name:
            _add_bridge_detail(road)

        if "underpass" in road_name:
            _add_underpass_detail(road)

func _add_road_markings(road: Node3D) -> void:
    var p := road.global_position

    # Kompakt orta çizgi ve kenar çizgileri.
    _box(visual_root, "LaneMark", p + Vector3(0, 0.025, 0), Vector3(0.14, 0.025, 5.0), mat_road_marking)
    _box(visual_root, "LaneEdge", p + Vector3(-2.1, 0.03, 0), Vector3(0.08, 0.025, 5.0), mat_road_marking)
    _box(visual_root, "LaneEdge", p + Vector3(2.1, 0.03, 0), Vector3(0.08, 0.025, 5.0), mat_road_marking)

func _add_sidewalks(road: Node3D) -> void:
    var p := road.global_position

    _box(visual_root, "SidewalkL", p + Vector3(-3.0, 0.08, 0), Vector3(0.85, 0.16, 5.0), mat_sidewalk)
    _box(visual_root, "SidewalkR", p + Vector3(3.0, 0.08, 0), Vector3(0.85, 0.16, 5.0), mat_sidewalk)

func _add_lamps_near_road(road: Node3D) -> void:
    var p := road.global_position

    for side in [-1.0, 1.0]:
        var lamp_pos := p + Vector3(side * 3.35, 1.6, -1.8)
        _cylinder(visual_root, "StreetLampPole", lamp_pos, 0.055, 3.2, mat_lamp)
        _box(visual_root, "StreetLampHead", lamp_pos + Vector3(0, 1.55, 0.18), Vector3(0.28, 0.08, 0.42), mat_facade_dark)

func _add_signal_detail(signal_node: Node3D) -> void:
    var p := signal_node.global_position

    _cylinder(visual_root, "SignalPole", p + Vector3(0, 1.5, 0), 0.08, 3.0, mat_lamp)
    _box(visual_root, "SignalBody", p + Vector3(0, 3.0, 0), Vector3(0.35, 1.0, 0.25), mat_facade_dark)

    _cylinder(visual_root, "SignalRed", p + Vector3(0, 3.28, -0.14), 0.075, 0.10, mat_signal_red)
    _cylinder(visual_root, "SignalYellow", p + Vector3(0, 3.00, -0.14), 0.075, 0.10, mat_signal_yellow)
    _cylinder(visual_root, "SignalGreen", p + Vector3(0, 2.72, -0.14), 0.075, 0.10, mat_signal_green)

func _add_bridge_detail(bridge: Node3D) -> void:
    var p := bridge.global_position

    for x in [-2.4, 0.0, 2.4]:
        _cylinder(visual_root, "BridgeSupport", p + Vector3(x, -1.1, 0), 0.22, 2.2, mat_facade_dark)

    _box(visual_root, "BridgeRailL", p + Vector3(0, 0.65, -2.1), Vector3(6.5, 0.35, 0.16), mat_facade_dark)
    _box(visual_root, "BridgeRailR", p + Vector3(0, 0.65, 2.1), Vector3(6.5, 0.35, 0.16), mat_facade_dark)

func _add_underpass_detail(underpass: Node3D) -> void:
    var p := underpass.global_position

    _box(visual_root, "UnderpassWallL", p + Vector3(-3.1, 1.0, 0), Vector3(0.28, 2.0, 6.0), mat_facade_dark)
    _box(visual_root, "UnderpassWallR", p + Vector3(3.1, 1.0, 0), Vector3(0.28, 2.0, 6.0), mat_facade_dark)
    _box(visual_root, "UnderpassLight", p + Vector3(0, 2.0, 0), Vector3(0.35, 0.12, 0.35), mat_road_marking)

func _build_building_quality() -> void:
    if game_state == null:
        return

    if not ("buildings" in game_state):
        return

    var buildings = game_state.buildings
    if not (buildings is Array):
        return

    for building in buildings:
        if detail_nodes_created >= max_detail_nodes:
            break
        if not (building is Dictionary):
            continue
        if not building.has("position"):
            continue
        if not (building["position"] is Vector3):
            continue

        var p: Vector3 = building["position"]
        var kind := str(building["type"]) if building.has("type") else ""

        _add_facade_windows(p, kind)
        _add_building_entrance(p, kind)
        _add_special_facade(p, kind)

func _add_facade_windows(p: Vector3, kind: String) -> void:
    var height := 2.5
    if "hospital" in kind or "university" in kind or "school" in kind:
        height = 3.2
    elif "mall" in kind or "hotel" in kind:
        height = 4.0
    elif "stadium" in kind:
        return

    for floor in range(2):
        var y := 1.0 + float(floor) * height
        _box(visual_root, "FacadeWindow", p + Vector3(0.0, y, -0.56), Vector3(0.72, 0.52, 0.05), mat_glass)
        _box(visual_root, "FacadeWindow", p + Vector3(0.0, y, 0.56), Vector3(0.72, 0.52, 0.05), mat_glass)

func _add_building_entrance(p: Vector3, kind: String) -> void:
    var material := mat_facade_dark
    if "hospital" in kind:
        material = mat_signal_red
    elif "school" in kind or "university" in kind:
        material = mat_signal_yellow

    _box(visual_root, "BuildingEntrance", p + Vector3(0, 0.55, -0.62), Vector3(0.75, 1.1, 0.12), material)

func _add_special_facade(p: Vector3, kind: String) -> void:
    if "mall" in kind:
        _box(visual_root, "MallGlassFront", p + Vector3(0, 1.2, -0.7), Vector3(2.2, 1.5, 0.08), mat_glass)
        _box(visual_root, "MallSignBand", p + Vector3(0, 2.2, -0.73), Vector3(2.6, 0.25, 0.10), mat_facade_dark)

    elif "hospital" in kind:
        _box(visual_root, "HospitalSign", p + Vector3(0, 2.4, -0.72), Vector3(1.6, 0.25, 0.10), mat_signal_red)

    elif "school" in kind or "university" in kind:
        _box(visual_root, "EducationSign", p + Vector3(0, 2.2, -0.72), Vector3(1.8, 0.22, 0.10), mat_signal_yellow)

    elif "hotel" in kind:
        _box(visual_root, "HotelEntrance", p + Vector3(0, 1.0, -0.72), Vector3(1.4, 1.5, 0.08), mat_glass)

func _build_environment_quality() -> void:
    # Şehir geneline seyrek çevre objeleri.
    # Sabit düşük sayı mobil performansı korur.
    if world_root == null:
        return

    var anchors := [
        Vector3(-12, 0, -10),
        Vector3(12, 0, -10),
        Vector3(-12, 0, 10),
        Vector3(12, 0, 10),
        Vector3(-24, 0, 0),
        Vector3(24, 0, 0)
    ]

    for p in anchors:
        _add_tree_cluster(p)
        _add_bin(p + Vector3(2.0, 0, 1.5))

func _add_tree_cluster(p: Vector3) -> void:
    _cylinder(visual_root, "TreeTrunk", p + Vector3(0, 0.8, 0), 0.13, 1.6, mat_facade_dark)
    _cylinder(visual_root, "TreeCrown", p + Vector3(0, 1.9, 0), 0.65, 1.5, mat_tree)
    _cylinder(visual_root, "TreeCrownSmall", p + Vector3(0.45, 1.7, 0.2), 0.38, 0.9, mat_tree_dark)

func _add_bin(p: Vector3) -> void:
    _box(visual_root, "WasteContainer", p + Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.55), mat_bin)
    _box(visual_root, "WasteContainerLid", p + Vector3(0, 0.93, 0), Vector3(0.60, 0.10, 0.60), mat_facade_dark)

func _build_coastal_quality() -> void:
    # Sahil/walking/bike yolu isimlerinden mevcut düğümleri yakala.
    if world_root == null:
        return

    for node in world_root.get_children():
        if detail_nodes_created >= max_detail_nodes:
            break
        if not (node is Node3D):
            continue

        var node_name := node.name.to_lower()
        if "coast" in node_name or "waterfront" in node_name or "bike" in node_name or "walk" in node_name:
            _add_coast_detail(node)

func _add_coast_detail(node: Node3D) -> void:
    var p := node.global_position

    _box(visual_root, "CoastPathEdge", p + Vector3(0, 0.06, 1.4), Vector3(5.0, 0.10, 0.14), mat_facade_dark)
    _box(visual_root, "BikePathMark", p + Vector3(0, 0.08, -1.0), Vector3(4.0, 0.05, 0.08), mat_road_marking)
    _cylinder(visual_root, "CoastLamp", p + Vector3(-1.5, 1.3, 0), 0.045, 2.6, mat_lamp)
    _cylinder(visual_root, "CoastLamp", p + Vector3(1.5, 1.3, 0), 0.045, 2.6, mat_lamp)

func _build_special_locations() -> void:
    if world_root == null:
        return

    for node in world_root.get_children():
        if detail_nodes_created >= max_detail_nodes:
            break
        if not (node is Node3D):
            continue

        var n := node.name.to_lower()
        var p: Vector3 = node.global_position

        if "port" in n:
            _box(visual_root, "PortPlatform", p + Vector3(0, 0.15, 0), Vector3(5.0, 0.25, 2.5), mat_facade_dark)

        elif "airport" in n:
            _box(visual_root, "AirportMarking", p + Vector3(0, 0.08, 0), Vector3(7.0, 0.05, 0.30), mat_road_marking)

        elif "metro" in n:
            _box(visual_root, "MetroEntrance", p + Vector3(0, 0.55, 0), Vector3(1.5, 1.1, 0.8), mat_facade_dark)

func get_status() -> Dictionary:
    return {
        "detail_nodes_created": detail_nodes_created,
        "max_detail_nodes": max_detail_nodes,
        "detail_budget_remaining": max_detail_nodes - detail_nodes_created,
        "mobile_safe_budget": true
    }
