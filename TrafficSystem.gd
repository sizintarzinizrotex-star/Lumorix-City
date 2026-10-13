class_name LumorixTrafficSystem
extends Node3D

var traffic_score := 85.0
var vehicles: Array[Node3D] = []
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var state: Node
var road_network: Node
var target_vehicle_count := 24
var demand_index := 0.0
var road_capacity := 70.0
var route_counter := 0
var alternate_route_count := 0
var stopped_vehicle_count := 0

func initialize(game_state: Node = null, roads: Node = null) -> void:
    state = game_state
    road_network = roads
    rng.seed = 22331
    _spawn_demo_traffic(24)

func _spawn_demo_traffic(count: int) -> void:
    for i in count:
        _spawn_vehicle(i)

func _spawn_vehicle(index: int) -> void:
    var car := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.1, 0.45, 2.0)
    car.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = [Color("#d94b45"), Color("#4d82c8"), Color("#e0c34f"), Color("#d8d8d8")][index % 4]
    car.material_override = mat
    var vertical := index % 3 == 0
    if vertical:
        car.position = Vector3(64.0 + rng.randf_range(-2.0, 2.0), 0.35, rng.randf_range(-140.0, 140.0))
    else:
        car.position = Vector3(rng.randf_range(-140.0, 140.0), 0.35, 32.0 + rng.randf_range(-2.0, 2.0))
    car.set_meta("speed", 3.0 + float(index % 4))
    car.set_meta("axis", "vertical" if vertical else "horizontal")
    var preferred_class := "arterial"
    if index % 9 == 0:
        preferred_class = "highway"
    elif index % 5 == 0:
        preferred_class = "express"
    elif index % 3 == 0:
        preferred_class = "local"
    car.set_meta("road_class", preferred_class)
    car.set_meta("direction", 1.0 if index % 2 == 0 else -1.0)
    car.set_meta("route", "primary")
    car.set_meta("detour_stage", 0)
    add_child(car)
    vehicles.append(car)

func _process(delta: float) -> void:
    elapsed += delta
    if state != null:
        _update_demand()
    _update_vehicle_population()
    _assign_alternate_routes()
    _move_vehicles(delta)
    _update_corridor_metrics()
    _update_intersection_pressure()
    _update_traffic_score()

func _update_demand() -> void:
    var mobility: float = clampf(float(state.citizen_mobility_demand), 0.0, 3.0)
    var activity: float = clampf(float(state.citizen_economic_activity), 0.0, 1.5)
    var phase_multiplier: float = 1.0
    match str(state.citizen_routine_phase):
        "is", "alisveris": phase_multiplier = 1.25
        "ulasim": phase_multiplier = 1.5
        "ev": phase_multiplier = 0.65
    demand_index = clamp((mobility * 0.65 + activity * 0.35) * phase_multiplier, 0.2, 4.5)
    road_capacity = _calculate_road_capacity()
    target_vehicle_count = clamp(int(12.0 + demand_index * 15.0 + float(state.population) / 250.0), 12, 80)

func _calculate_road_capacity() -> float:
    if road_network == null:
        return 70.0
    var total := 0.0
    var segments = road_network.road_segments if road_network.get("road_segments") != null else []
    for segment in segments:
        var lanes := int(segment.get("lanes", 2))
        var road_class: String = str(segment.get("class", "local"))
        var class_factor := 1.0
        match road_class:
            "highway": class_factor = 1.25
            "express": class_factor = 1.15
            "arterial": class_factor = 1.05
        total += float(segment.get("capacity", lanes * 35)) * class_factor
    # A mobile city uses effective capacity rather than raw lane count:
    # intersections, signals and route conflicts consume part of it.
    var network_factor := 0.72
    if road_network.has_method("get_network_efficiency"):
        network_factor = clamp(float(road_network.get_network_efficiency()), 0.55, 0.95)
    return max(total * network_factor, 70.0)

func _update_vehicle_population() -> void:
    while vehicles.size() < target_vehicle_count:
        _spawn_vehicle(vehicles.size())
    while vehicles.size() > target_vehicle_count and vehicles.size() > 8:
        var car: Node3D = vehicles.pop_back() as Node3D
        if is_instance_valid(car):
            car.queue_free()

func _assign_alternate_routes() -> void:
    # Trafik arttıkça araçların bir kısmı yüksek kapasiteli koridorları tercih eder.
    # Böylece 6/8 şerit yollar yalnızca görsel olarak değil, talep dağılımında da işe yarar.
    var congestion: float = float(vehicles.size()) / max(road_capacity, 1.0)
    var express_share: float = clampf((congestion - 0.10) * 2.2 + demand_index * 0.08, 0.0, 0.55)
    for i in vehicles.size():
        var vehicle := vehicles[i]
        if not is_instance_valid(vehicle):
            continue
        if i % 20 < int(express_share * 20.0):
            vehicle.set_meta("road_class", "highway" if i % 3 == 0 else "express")
        elif i % 7 == 0:
            vehicle.set_meta("road_class", "arterial")
    var use_alternates: bool = congestion > 0.16 or demand_index > 1.8
    alternate_route_count = 0
    for i in vehicles.size():
        var car := vehicles[i]
        if not is_instance_valid(car):
            continue
        var axis: String = str(car.get_meta("axis", "horizontal"))
        var previous_route := str(car.get_meta("route", "primary"))
        var route := "primary"
        if use_alternates and i % 4 == 0:
            route = "alternate"
        if previous_route != route:
            car.set_meta("detour_stage", 0)
        car.set_meta("route", route)
        car.set_meta("avoid_signal", route == "alternate")
        if route == "alternate":
            alternate_route_count += 1
            # Alternatif rota kavşakta şerit değiştirmek yerine kontrollü bir
            # yan koridor kullanır: yatay araçlar z=0, dikey araçlar x=-64.
            # Araç mevcut konumundan bu koridora kademeli olarak geçer.
            if axis == "horizontal" and abs(car.position.x) < 24.0:
                car.set_meta("detour_stage", 1)
            elif axis == "vertical" and abs(car.position.z - 32.0) < 24.0:
                car.set_meta("detour_stage", 1)
    if state != null:
        state.set("traffic_alternate_route_count", alternate_route_count)


func _move_vehicles(delta: float) -> void:
    var congestion: float = clamp(float(vehicles.size()) / max(road_capacity, 1.0), 0.0, 2.0)
    var speed_factor: float = clampf(1.0 - congestion * 0.35, 0.25, 1.0)
    for car in vehicles:
        if not is_instance_valid(car):
            continue
        var axis: String = str(car.get_meta("axis", "horizontal"))
        var direction: float = float(car.get_meta("direction", 1.0))
        var base_speed: float = float(car.get_meta("speed", 3.0))
        var road_speed_limit := 6.0
        var road_class: String = str(car.get_meta("road_class", "arterial"))
        var lane_factor: float = 1.0
        if road_network != null and road_network.has_method("get_road_profile_at"):
            var profile: Dictionary = road_network.get_road_profile_at(car.position, axis)
            road_speed_limit = float(profile.get("speed_limit", 6.0))
            var actual_class: String = str(profile.get("class", "local"))
            var preferred_bonus: float = 1.0 if actual_class == road_class else 0.92
            lane_factor = clamp(float(profile.get("lanes", 2)) / 4.0, 0.70, 1.80) * preferred_bonus
        elif road_network != null and road_network.has_method("get_speed_limit_at"):
            road_speed_limit = float(road_network.get_speed_limit_at(car.position, axis))
        var speed_class_factor: float = clampf(road_speed_limit / 6.0, 0.70, 1.55)
        var speed: float = base_speed * speed_factor * speed_class_factor * clamp(lane_factor, 0.75, 1.35)
        var stopped: bool = false
        var alternate: bool = bool(car.get_meta("avoid_signal", false))
        var detour_stage: int = int(car.get_meta("detour_stage", 0))

        if road_network != null and road_network.has_method("is_horizontal_green") and not alternate:
            if axis == "horizontal":
                var dx: float = absf(car.position.x)
                if dx < 7.0 and abs(car.position.z - 32.0) < 5.0 and not road_network.is_horizontal_green():
                    stopped = true
            else:
                var dz: float = absf(car.position.z - 32.0)
                if dz < 7.0 and abs(car.position.x - 64.0) < 5.0 and not road_network.is_vertical_green():
                    stopped = true
        car.set_meta("stopped_at_light", stopped)
        if stopped:
            continue

        if alternate and axis == "horizontal":
            # Kavşak yoğunken ana kesişimi z=0 yan koridorundan dolaş.
            if detour_stage == 1:
                var target_z := 0.0
                var dz := target_z - car.position.z
                if abs(dz) > 0.8:
                    car.position.z += sign(dz) * delta * speed
                    car.rotation_degrees.y = 90.0 if dz > 0.0 else -90.0
                    continue
                car.set_meta("detour_stage", 2)
            elif detour_stage == 2:
                car.position.x += delta * speed * direction
                if abs(car.position.x) > 25.0:
                    car.set_meta("detour_stage", 3)
                car.rotation_degrees.y = 0.0 if direction > 0.0 else 180.0
                continue
            elif detour_stage == 3:
                var dz := 32.0 - car.position.z
                if abs(dz) > 0.8:
                    car.position.z += sign(dz) * delta * speed
                    car.rotation_degrees.y = 90.0 if dz > 0.0 else -90.0
                    continue
                car.set_meta("detour_stage", 0)

        elif alternate and axis == "vertical":
            # Dikey trafik için roundabout/yan koridor x=-64 kullanılır.
            if detour_stage == 1:
                var target_x := -64.0
                var dx := target_x - car.position.x
                if abs(dx) > 0.8:
                    car.position.x += sign(dx) * delta * speed
                    car.rotation_degrees.y = 0.0 if dx > 0.0 else 180.0
                    continue
                car.set_meta("detour_stage", 2)
            elif detour_stage == 2:
                car.position.z += delta * speed * direction
                if abs(car.position.z - 32.0) > 25.0:
                    car.set_meta("detour_stage", 3)
                car.rotation_degrees.y = 90.0 if direction > 0.0 else -90.0
                continue
            elif detour_stage == 3:
                var dx := 64.0 - car.position.x
                if abs(dx) > 0.8:
                    car.position.x += sign(dx) * delta * speed
                    car.rotation_degrees.y = 0.0 if dx > 0.0 else 180.0
                    continue
                car.set_meta("detour_stage", 0)

        if axis == "vertical":
            car.position.z += delta * speed * direction
            if car.position.z > 150.0:
                car.position.z = -150.0
            elif car.position.z < -150.0:
                car.position.z = 150.0
            car.rotation_degrees.y = 90.0 if direction > 0.0 else -90.0
        else:
            car.position.x += delta * speed * direction
            if car.position.x > 150.0:
                car.position.x = -150.0
            elif car.position.x < -150.0:
                car.position.x = 150.0
            car.rotation_degrees.y = 0.0 if direction > 0.0 else 180.0


func _update_corridor_metrics() -> void:
    # Trafiğin hangi yol omurgasını kullandığını ölç: yerel, arter, ekspres ve otoyol.
    # Bu metrikler ileride AI rota seçimi ve UI için kullanılabilir.
    var local_count: int = 0
    var arterial_count: int = 0
    var express_count: int = 0
    var highway_count: int = 0
    if road_network != null and road_network.has_method("get_road_profile_at"):
        for car in vehicles:
            if not is_instance_valid(car):
                continue
            var axis: String = str(car.get_meta("axis", "horizontal"))
            var profile: Dictionary = road_network.get_road_profile_at(car.position, axis)
            var vehicle_class := str(profile.get("class", "local"))
            match vehicle_class:
                "highway": highway_count += 1
                "express": express_count += 1
                "arterial": arterial_count += 1
                _: local_count += 1
    var total: int = maxi(vehicles.size(), 1)
    if state != null:
        state.set("traffic_local_usage", float(local_count) / float(total))
        state.set("traffic_arterial_usage", float(arterial_count) / float(total))
        state.set("traffic_express_usage", float(express_count) / float(total))
        state.set("traffic_highway_usage", float(highway_count) / float(total))


func _update_intersection_pressure() -> void:
    if road_network == null or not road_network.has_method("set_intersection_pressure"):
        return
    var horizontal: float = 0.5
    var vertical: float = 0.5
    stopped_vehicle_count = 0
    for car in vehicles:
        if not is_instance_valid(car):
            continue
        var axis: String = str(car.get_meta("axis", "horizontal"))
        var near_intersection: bool = false
        if axis == "horizontal":
            near_intersection = abs(car.position.x) < 18.0 and abs(car.position.z - 32.0) < 5.0
            if near_intersection:
                horizontal += 1.0
        else:
            near_intersection = abs(car.position.z - 32.0) < 18.0 and abs(car.position.x - 64.0) < 5.0
            if near_intersection:
                vertical += 1.0
        if bool(car.get_meta("stopped_at_light", false)):
            stopped_vehicle_count += 1
    road_network.set_intersection_pressure(horizontal, vertical)
    if state != null:
        state.set("traffic_stopped_vehicle_count", stopped_vehicle_count)
        state.set("traffic_alternate_route_count", alternate_route_count)
        state.set("traffic_signal_delay_events", int(road_network.get_signal_status().get("delay_events", 0)))

func _update_traffic_score() -> void:
    var congestion: float = clamp(float(vehicles.size()) / max(road_capacity, 1.0), 0.0, 1.5)
    var demand_penalty: float = clampf((demand_index - 1.0) * 7.0, 0.0, 28.0)
    traffic_score = clamp(100.0 - congestion * 55.0 - demand_penalty, 15.0, 98.0)
    if state != null:
        state.traffic = traffic_score
        state.traffic_vehicle_count = vehicles.size()
        state.traffic_demand_index = demand_index
        state.traffic_road_capacity = road_capacity
        state.set_city_risk("traffic", 100.0 - traffic_score)
