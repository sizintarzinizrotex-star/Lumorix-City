class_name LumorixRoadNetworkSystem
extends Node3D

signal road_message(text: String, severity: String)

var roads_root: Node3D
var road_segments: Array[Dictionary] = []
var traffic_lights: Array[Node3D] = []
var crosswalks: Array[Node3D] = []
var signal_clock := 0.0
var signal_phase := 0 # 0 horizontal green, 1 yellow, 2 vertical green, 3 yellow
var horizontal_pressure := 1.0
var vertical_pressure := 1.0
var signal_cycle_length := 20.0
var signal_delay_events := 0
var adaptive_extension_events := 0
var road_maintenance_clock := 0.0
var road_maintenance_events := 0

func initialize(parent_root: Node3D) -> void:
    roads_root = Node3D.new()
    roads_root.name = "AdvancedRoadNetwork"
    parent_root.add_child(roads_root)
    _build_demo_network()
    _update_traffic_light_visuals()

func _process(delta: float) -> void:
    signal_clock += delta
    var horizontal_green: float = clampf(5.0 + horizontal_pressure * 3.0, 5.0, 11.0)
    var vertical_green: float = clampf(5.0 + vertical_pressure * 3.0, 5.0, 11.0)
    signal_cycle_length = horizontal_green + 2.0 + vertical_green + 2.0
    if horizontal_pressure > vertical_pressure * 1.35 or vertical_pressure > horizontal_pressure * 1.35:
        adaptive_extension_events += 1 if fmod(signal_clock, 5.0) < 0.1 else 0
    var cycle := fmod(signal_clock, signal_cycle_length)
    if cycle < horizontal_green:
        signal_phase = 0
    elif cycle < horizontal_green + 2.0:
        signal_phase = 1
    elif cycle < horizontal_green + 2.0 + vertical_green:
        signal_phase = 2
    else:
        signal_phase = 3
    _update_traffic_light_visuals()
    road_maintenance_clock += delta
    if road_maintenance_clock >= 12.0:
        road_maintenance_clock = 0.0
        _simulate_road_wear()

func set_intersection_pressure(horizontal: float, vertical: float) -> void:
    horizontal_pressure = clamp(horizontal, 0.25, 4.0)
    vertical_pressure = clamp(vertical, 0.25, 4.0)

func register_signal_delay() -> void:
    signal_delay_events += 1

func get_signal_status() -> Dictionary:
    return {
        "phase": signal_phase,
        "cycle_length": signal_cycle_length,
        "horizontal_pressure": horizontal_pressure,
        "vertical_pressure": vertical_pressure,
        "delay_events": signal_delay_events,
        "adaptive_extension_events": adaptive_extension_events
    }

func is_horizontal_green() -> bool:
    return signal_phase == 0

func is_vertical_green() -> bool:
    return signal_phase == 2

func _update_traffic_light_visuals() -> void:
    for light in traffic_lights:
        if not is_instance_valid(light):
            continue
        var lamp := light.get_node_or_null("SignalLamp") as MeshInstance3D
        if lamp == null:
            continue
        var mat := StandardMaterial3D.new()
        var axis := str(light.get_meta("axis", "horizontal"))
        if signal_phase == 1 or signal_phase == 3:
            mat.albedo_color = Color("#e0b83f")
        elif (axis == "horizontal" and signal_phase == 0) or (axis == "vertical" and signal_phase == 2):
            mat.albedo_color = Color("#4cc96b")
        else:
            mat.albedo_color = Color("#d94b45")
        lamp.material_override = mat

func _build_demo_network() -> void:
    add_road(Vector3(0,0.05,0), Vector3(280,0.12,3.2), 2, "main_east_west")
    add_road(Vector3(0,0.06,32), Vector3(280,0.12,6.2), 4, "arterial_east_west")
    add_road(Vector3(0,0.07,64), Vector3(280,0.12,9.0), 6, "express_east_west")
    add_road(Vector3(-64,0.07,0), Vector3(3.2,0.12,280), 2, "main_north_south")
    add_road(Vector3(64,0.08,0), Vector3(6.2,0.12,280), 4, "arterial_north_south")
    add_road(Vector3(-96,0.09,0), Vector3(8.8,0.12,280), 6, "express_north_south")
    add_road(Vector3(96,0.10,0), Vector3(11.4,0.12,280), 8, "highway_north_south")
    add_intersection(Vector3(0,0.12,32), "four_way")
    add_roundabout(Vector3(-64,0.12,32), 9.0)
    add_crosswalk(Vector3(0,0.16,29), 10.0)
    add_traffic_light(Vector3(5,0.7,27), "horizontal")
    add_traffic_light(Vector3(-5,0.7,37), "horizontal")
    add_traffic_light(Vector3(69,0.7,27), "vertical")
    add_traffic_light(Vector3(59,0.7,37), "vertical")
    add_overpass(Vector3(55,0,65), 26.0, 8.0)
    add_underpass(Vector3(-55,0,-65), 26.0, 8.0)
    add_bridge(Vector3(0,0,112), 70.0, 10.0, false)


func connect_terrain_parcel(parcel_id: String, center: Vector3, lanes: int = 2) -> void:
    var direction := Vector3(0, 0, 1) if abs(center.z) >= abs(center.x) else Vector3(1, 0, 0)
    var start := center - direction * 15.0
    var end := center - direction * 70.0
    var size := Vector3(3.2 if direction.z != 0 else 55.0, 0.14, 55.0 if direction.z != 0 else 3.2)
    if lanes >= 4:
        size = Vector3(6.2 if direction.z != 0 else 55.0, 0.14, 55.0 if direction.z != 0 else 6.2)
    add_road((start + end) / 2.0 + Vector3(0,0.08,0), size, lanes, "terrain_%s" % parcel_id)

func add_road(center: Vector3, size: Vector3, lanes: int, road_id: String) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _mat(Color("#252a2e"))
    mesh.position = center
    mesh.name = "Road_%s_%dlane" % [road_id, lanes]
    roads_root.add_child(mesh)
    var road_class: String = "highway" if lanes >= 8 else ("express" if lanes >= 6 else ("arterial" if lanes >= 4 else "local"))
    var speed_limit := 13.0 if lanes >= 8 else (11.0 if lanes >= 6 else (8.0 if lanes >= 4 else 6.0))
    road_segments.append({"id":road_id, "lanes":lanes, "capacity":lanes * 35, "class":road_class, "speed_limit":speed_limit, "center":center, "axis":"horizontal" if size.x >= size.z else "vertical", "condition":100.0, "level":1, "maintenance_cost":max(4, lanes * 3)})

func add_intersection(center: Vector3, kind: String) -> void:
    var node := Node3D.new()
    node.name = "Intersection_%s" % kind
    node.position = center
    roads_root.add_child(node)
    var marker := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 4.5
    mesh.bottom_radius = 4.5
    mesh.height = 0.05
    marker.mesh = mesh
    marker.material_override = _mat(Color("#30353a"))
    node.add_child(marker)

func add_roundabout(center: Vector3, radius: float) -> void:
    var node := Node3D.new()
    node.name = "Roundabout"
    node.position = center
    roads_root.add_child(node)
    var ring := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = max(1.0, radius - 2.0)
    mesh.outer_radius = radius
    mesh.material = _mat(Color("#252a2e"))
    ring.mesh = mesh
    ring.rotation_degrees.x = 90
    node.add_child(ring)

func add_crosswalk(center: Vector3, width: float) -> void:
    var node := Node3D.new()
    node.name = "Crosswalk"
    node.position = center
    roads_root.add_child(node)
    for i in range(7):
        var stripe := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(width, 0.025, 0.32)
        stripe.mesh = box
        stripe.position.z = -2.0 + i * 0.65
        stripe.material_override = _mat(Color("#e8e8e8"))
        node.add_child(stripe)
    var sign := MeshInstance3D.new()
    var sign_mesh := BoxMesh.new()
    sign_mesh.size = Vector3(0.18, 1.0, 0.08)
    sign.mesh = sign_mesh
    sign.position = Vector3(width * 0.5 + 0.7, 0.5, 0.0)
    sign.material_override = _mat(Color("#d9dfe3"))
    node.add_child(sign)
    crosswalks.append(node)

func add_traffic_light(center: Vector3, axis: String = "horizontal") -> void:
    var node := Node3D.new()
    node.name = "TrafficLight"
    node.position = center
    roads_root.add_child(node)
    var pole := MeshInstance3D.new()
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.12
    pole_mesh.bottom_radius = 0.12
    pole_mesh.height = 2.8
    pole.mesh = pole_mesh
    pole.material_override = _mat(Color("#3a3a3a"))
    pole.position.y = 1.4
    node.add_child(pole)
    var lamp := MeshInstance3D.new()
    lamp.name = "SignalLamp"
    var lamp_mesh := BoxMesh.new()
    lamp_mesh.size = Vector3(0.45, 0.85, 0.3)
    lamp.mesh = lamp_mesh
    lamp.material_override = _mat(Color("#181818"))
    lamp.position.y = 2.55
    node.add_child(lamp)
    node.set_meta("axis", axis)
    traffic_lights.append(node)

func add_bridge(center: Vector3, length: float, width: float, premium: bool) -> void:
    _add_elevated_structure("PremiumBridge" if premium else "Bridge", center, length, width, 3.0)

func add_overpass(center: Vector3, length: float, width: float) -> void:
    _add_elevated_structure("Overpass", center, length, width, 4.0)

func add_underpass(center: Vector3, length: float, width: float) -> void:
    var node := Node3D.new()
    node.name = "Underpass"
    node.position = center
    roads_root.add_child(node)
    add_road(center + Vector3(0,-0.8,0), Vector3(length,0.12,width), 4, "underpass")

func _add_elevated_structure(kind: String, center: Vector3, length: float, width: float, height: float) -> void:
    var node := Node3D.new()
    node.name = kind
    node.position = center
    roads_root.add_child(node)
    var deck := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(length, 0.65, width)
    deck.mesh = mesh
    deck.material_override = _mat(Color("#4a4f54"))
    deck.position.y = height
    node.add_child(deck)
    for x in [-length * 0.35, 0.0, length * 0.35]:
        var pillar := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.55
        pm.bottom_radius = 0.75
        pm.height = height
        pillar.mesh = pm
        pillar.material_override = _mat(Color("#777b80"))
        pillar.position = Vector3(x, height / 2.0, 0)
        node.add_child(pillar)

func get_road_profile_at(position: Vector3, axis: String = "horizontal") -> Dictionary:
    # Aracın bulunduğu koridor için hız + kapasite + sınıf bilgisini birlikte döndürür.
    var best_distance := INF
    var best := {"class":"local", "lanes":2, "capacity":70, "speed_limit":6.0}
    for segment in road_segments:
        var road_axis := str(segment.get("axis", ""))
        if road_axis != "" and road_axis != axis:
            continue
        var center: Vector3 = segment.get("center", Vector3.ZERO)
        var distance: float = absf(position.z - center.z) if axis == "horizontal" else absf(position.x - center.x)
        if distance < best_distance:
            best_distance = distance
            best = {
                "class":str(segment.get("class", "local")),
                "lanes":int(segment.get("lanes", 2)),
                "capacity":float(segment.get("capacity", 70)) * clamp(float(segment.get("condition", 100.0)) / 100.0, 0.55, 1.0),
                "speed_limit":float(segment.get("speed_limit", 6.0)) * clamp(0.82 + float(segment.get("condition", 100.0)) / 555.0, 0.80, 1.0),
                "condition":float(segment.get("condition", 100.0)),
                "level":int(segment.get("level", 1)),
                "maintenance_cost":int(segment.get("maintenance_cost", 4))
            }
    return best

func _simulate_road_wear() -> void:
    var total_condition := 0.0
    for segment in road_segments:
        var lanes := int(segment.get("lanes", 2))
        var wear := 0.25 + float(lanes) * 0.025 + horizontal_pressure * 0.02 + vertical_pressure * 0.02
        segment["condition"] = clamp(float(segment.get("condition", 100.0)) - wear, 55.0, 100.0)
        total_condition += float(segment["condition"])
    if not road_segments.is_empty():
        var average := total_condition / float(road_segments.size())
        if state_available():
            get_parent().get_node("GameState").road_condition_average = average
            get_parent().get_node("GameState").road_maintenance_events = road_maintenance_events

func state_available() -> bool:
    return get_parent() != null and get_parent().get_node_or_null("GameState") != null

func get_road_maintenance_status() -> Dictionary:
    var total := 0.0
    var worst := 100.0
    for segment in road_segments:
        var condition := float(segment.get("condition", 100.0))
        total += condition
        worst = min(worst, condition)
    var average: float = total / maxf(1.0, float(road_segments.size()))
    return {"average_condition":average, "worst_condition":worst, "maintenance_events":road_maintenance_events, "segments":road_segments.size()}

func maintain_road_segment(road_id: String, recovery: float = 18.0) -> bool:
    for segment in road_segments:
        if str(segment.get("id", "")) == road_id:
            var before := float(segment.get("condition", 100.0))
            segment["condition"] = min(100.0, before + recovery)
            road_maintenance_events += 1
            road_message.emit("🛣️ Yol bakımı tamamlandı: %s (%.0f%% → %.0f%%)" % [road_id, before, float(segment["condition"])], "info")
            return true
    return false

func upgrade_road_segment(road_id: String) -> Dictionary:
    for segment in road_segments:
        if str(segment.get("id", "")) != road_id:
            continue
        var level := int(segment.get("level", 1))
        if level >= 5:
            return {"ok":false, "reason":"Yol maksimum seviyeye ulaştı."}
        var lanes := int(segment.get("lanes", 2))
        var next_lanes := 4 if level == 1 else (6 if level == 2 else (8 if level == 3 else 8))
        var next_level := level + 1
        var requirements := {"lucb":1000 * next_level, "cement":20 * next_level, "steel":15 * next_level, "construction_equipment":next_level}
        if level >= 4:
            requirements["construction_equipment"] = next_level + 2
            requirements["electronics"] = 5 * next_level
        return {"ok":true, "road_id":road_id, "current_level":level, "next_level":next_level, "current_lanes":lanes, "next_lanes":next_lanes, "requirements":requirements}
    return {"ok":false, "reason":"Yol bulunamadı."}

func get_speed_limit_at(position: Vector3, axis: String = "horizontal") -> float:
    # Araç konumuna en yakın yol sınıfını seçer. Hız sınırı yolun sınıfından gelir.
    var best_distance := INF
    var best_speed := 6.0
    for segment in road_segments:
        var speed := float(segment.get("speed_limit", 6.0))
        var road_axis := str(segment.get("axis", ""))
        if road_axis != "" and road_axis != axis:
            continue
        var center: Vector3 = segment.get("center", Vector3.ZERO)
        var distance: float = absf(position.z - center.z) if axis == "horizontal" else absf(position.x - center.x)
        if distance < best_distance:
            best_distance = distance
            best_speed = speed
    return best_speed

func get_network_efficiency() -> float:
    # Signalized intersections, roundabouts and grade-separated links
    # determine how much of the theoretical lane capacity is usable.
    var intersections := 0
    var grade_separated := 0
    for child in roads_root.get_children() if roads_root != null else []:
        var n := str(child.name).to_lower()
        if n.begins_with("intersection") or n == "roundabout":
            intersections += 1
        elif n.begins_with("overpass") or n.begins_with("underpass") or n.begins_with("bridge"):
            grade_separated += 1
    var efficiency := 0.82 - float(intersections) * 0.035 + float(grade_separated) * 0.015
    return clamp(efficiency, 0.55, 0.95)

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.82
    return m
