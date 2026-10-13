class_name LumorixCityWorld
extends Node3D

const WORLD_SIZE := 80
const CELL_SIZE := 4.0
const WORLD_METERS := WORLD_SIZE * CELL_SIZE
const WATER_LEVEL := -0.15

var game_state: Node
var world_root: Node3D
var buildings_root: Node3D
var terrain_parcels: Dictionary = {}
var roads_root: Node3D
var props_root: Node3D
var citizens_root: Node3D
var recreation_root: Node3D
var recreation_actors: Array[Dictionary] = []
var recreation_time := 0.0
var representative_citizen: Node3D
var representative_trip_key := ""
var representative_target := Vector3.ZERO
var representative_moving := false
var citizen_agents: Array[Dictionary] = []
var citizen_agent_clock := 0.0
var transit_hubs: Array[Dictionary] = []
var transit_hub_time := 0.0
var event_area_nodes: Dictionary = {}
var event_area_time := 0.0
var event_crowd_nodes: Array[Node3D] = []
var construction_cranes: Array[Node3D] = []
var road_network: Node = null
var rng := RandomNumberGenerator.new()
var building_lookup: Dictionary = {}
signal building_selected(building: LumorixBuilding)

func build_world(state: Node) -> void:
    game_state = state
    rng.seed = 424242
    world_root = Node3D.new()
    world_root.name = "GeneratedWorld"
    add_child(world_root)
    roads_root = _container("Roads")
    buildings_root = _container("Buildings")
    props_root = _container("Props")
    citizens_root = _container("CitizenMarkers")
    recreation_root = _container("CoastalRecreation")
    _create_ground()
    _create_water()
    _create_coast()
    _create_roads()
    _create_initial_city()
    _create_parks()
    _create_event_areas()
    _create_construction_cranes()
    _create_transit_hubs()
    _create_transit_transfer_nodes()
    _create_coastal_recreation()
    _create_representative_citizen()
    _create_citizen_agents()

func _process(delta: float) -> void:
    if recreation_root == null:
        return
    recreation_time += delta
    event_area_time += delta
    _update_event_area_lights()
    for actor in recreation_actors:
        var node: Node3D = actor.node
        var start: Vector3 = actor.start
        var end: Vector3 = actor.end
        var speed: float = actor.speed
        var loop_time: float = actor.loop_time
        var t: float = fmod(recreation_time * speed / loop_time, 1.0)
        if bool(actor.reverse):
            t = 1.0 - t
        node.position = start.lerp(end, t)
        if end.x != start.x:
            node.rotation.y = PI * 0.5 if end.x > start.x else -PI * 0.5
        var kind := str(actor.get("kind", "walker"))
        var hour := float(game_state.day_time) if game_state != null else 12.0
        var weather := str(game_state.weather) if game_state != null else "clear"
        var daylight := hour >= 6.0 and hour <= 22.0
        if kind == "child":
            node.visible = hour >= 8.0 and hour <= 20.5
        elif kind == "runner":
            node.visible = hour >= 5.5 and hour <= 22.0
        elif kind == "fisher":
            node.visible = hour >= 5.0 and hour <= 20.0
        elif kind == "seated":
            node.visible = hour >= 9.0 and hour <= 23.0
        else:
            node.visible = daylight
        # Kötü hava açık hava aktivitelerini gerçek zamanlı azaltır.
        if weather == "storm":
            node.visible = false
        elif weather == "rain" and kind in ["runner", "cyclist", "dog_walker"]:
            node.visible = false
        elif weather == "snow" and kind in ["cyclist", "runner"]:
            node.visible = false
    _update_recreation_activity()
    _update_representative_citizen(delta)
    _update_citizen_agents(delta)
    _update_transit_hubs(delta)
    _update_transit_transfer_nodes()

func _update_recreation_activity() -> void:
    if game_state == null:
        return
    var park_walkers := 0
    var park_runners := 0
    var park_children := 0
    var park_athletes := 0
    var park_social := 0
    var coastal_walkers := 0
    var coastal_runners := 0
    var coastal_cyclists := 0
    var coastal_dogs := 0
    var coastal_children := 0
    var visible_total := 0
    for actor in recreation_actors:
        var node: Node3D = actor.node
        if not is_instance_valid(node) or not node.visible:
            continue
        visible_total += 1
        var kind := str(actor.get("kind", "walker"))
        var start: Vector3 = actor.start
        var coastal := start.z < -130.0
        if coastal:
            match kind:
                "walker": coastal_walkers += 1
                "runner": coastal_runners += 1
                "cyclist": coastal_cyclists += 1
                "dog_walker": coastal_dogs += 1
                "child": coastal_children += 1
        else:
            match kind:
                "walker": park_walkers += 1
                "runner": park_runners += 1
                "child": park_children += 1
                "cyclist": park_athletes += 1
                "seated": park_social += 1

    var hour := float(game_state.day_time)
    var weather := str(game_state.weather)
    var open_factor := 1.0 if hour >= 7.0 and hour <= 22.0 else 0.45
    if weather in ["rain", "storm"]:
        open_factor *= 0.35
    elif weather == "snow":
        open_factor *= 0.55

    game_state.park_walkers = park_walkers
    game_state.park_runners = park_runners
    game_state.park_children = park_children
    game_state.park_athletes = park_athletes
    game_state.park_social_visitors = park_social
    game_state.park_activity_count = int(round(float(park_walkers + park_runners + park_children + park_athletes + park_social) * max(open_factor, 0.2)))
    game_state.coastal_walkers = coastal_walkers
    game_state.coastal_runners = coastal_runners
    game_state.coastal_cyclists = coastal_cyclists
    game_state.coastal_dog_walkers = coastal_dogs
    game_state.coastal_children = coastal_children
    # İskelelerdeki balıkçılar statik dekor olduğu için saat/hava koşulundan ayrıca hesaplanır.
    game_state.coastal_fishers = 0 if weather in ["storm", "snow"] or hour < 5.0 or hour > 20.0 else 6
    game_state.coastal_activity_count = coastal_walkers + coastal_runners + coastal_cyclists + coastal_dogs + coastal_children + game_state.coastal_fishers

func _container(name: String) -> Node3D:
    var n := Node3D.new()
    n.name = name
    world_root.add_child(n)
    return n

func _mat(color: Color, roughness := 0.8) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _mesh_box(size: Vector3, color: Color, collision := false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _mat(color)
    if collision:
        var body := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        mi.add_child(body)
    return mi


func _get_citizen_destinations() -> Dictionary:
    var homes: Array[Vector3] = []
    var works: Array[Vector3] = []
    var leisure: Array[Vector3] = []
    if game_state != null:
        for building in game_state.buildings:
            if not (building is Dictionary):
                continue
            var pos_value = building.get("position", null)
            if pos_value is Vector3:
                var kind := str(building.get("type", ""))
                if kind == "residential":
                    homes.append(pos_value)
                elif kind == "factory" or kind == "commercial" or kind == "hospital" or kind == "school" or kind == "police" or kind == "fire" or kind == "power" or kind == "water" or kind == "sewage" or kind == "waste":
                    works.append(pos_value)
                if bool(building.get("interactive", false)) or kind == "mall" or kind == "stadium":
                    leisure.append(pos_value)
        for destination in game_state.park_destinations:
            if destination is Dictionary and destination.get("position", null) is Vector3:
                leisure.append(destination.position)
    if homes.is_empty():
        homes = [Vector3(-18, 0.0, 10), Vector3(-8, 0.0, 18), Vector3(8, 0.0, 12), Vector3(18, 0.0, 6)]
    if works.is_empty():
        works = [Vector3(-42, 0.0, 20), Vector3(-24, 0.0, 32), Vector3(-6, 0.0, 20), Vector3(12, 0.0, 32)]
    if leisure.is_empty():
        leisure = [Vector3(-12, 0.08, 58), Vector3(10, 0.08, 48), Vector3(64, 0.08, 48), Vector3(0, 0.08, -142)]
    return {"homes": homes, "works": works, "leisure": leisure}

func _nearest_road_waypoint(pos: Vector3) -> Vector3:
    var waypoints: Array[Vector3] = [Vector3(0, 0.15, 0), Vector3(0, 0.15, 32), Vector3(0, 0.15, 64), Vector3(64, 0.15, 32), Vector3(96, 0.15, 32), Vector3(64, 0.15, 0), Vector3(-64, 0.15, 32), Vector3(-96, 0.15, 0), Vector3(-64, 0.15, 0)]
    var best: Vector3 = waypoints[0]
    var best_distance: float = INF
    for point in waypoints:
        var distance := pos.distance_to(point)
        if distance < best_distance:
            best_distance = distance
            best = point
    return best

func _preferred_road_waypoint(pos: Vector3, mode: String) -> Vector3:
    # Motorlu ulaşım, şehrin yüksek kapasiteli koridorlarını tercih eder.
    # Yaya/bisiklet ise daha kısa ve düşük sınıflı koridorlarda kalır.
    var candidates: Array[Vector3] = [Vector3(0, 0.15, 0), Vector3(0, 0.15, 32), Vector3(0, 0.15, 64), Vector3(64, 0.15, 32), Vector3(96, 0.15, 32), Vector3(-64, 0.15, 32), Vector3(-96, 0.15, 0)]
    var best: Vector3 = candidates[0]
    var best_score: float = INF
    for point in candidates:
        var score := pos.distance_to(point)
        var axis := "horizontal" if abs(point.x) < 1.0 or abs(point.x - 64.0) < 1.0 or abs(point.x - 96.0) < 1.0 or abs(point.x + 96.0) < 1.0 else "vertical"
        if road_network != null and road_network.has_method("get_road_profile_at"):
            var profile: Dictionary = road_network.get_road_profile_at(point, axis)
            var road_class := str(profile.get("class", "local"))
            var lanes := int(profile.get("lanes", 2))
            if mode == "arac" or mode == "otobus":
                if road_class == "highway":
                    score -= 34.0
                elif road_class == "express":
                    score -= 24.0
                elif road_class == "arterial":
                    score -= 10.0
                score -= float(lanes) * 1.5
            elif mode == "bisiklet":
                if road_class == "arterial":
                    score -= 3.0
                elif road_class == "highway":
                    score += 28.0
        if score < best_score:
            best_score = score
            best = point
    return best

func _build_citizen_route(from_pos: Vector3, to_pos: Vector3, mode: String) -> Array[Vector3]:
    if mode == "yaya":
        return [to_pos]
    var start := _preferred_road_waypoint(from_pos, mode)
    var finish := _preferred_road_waypoint(to_pos, mode)
    var route: Array[Vector3] = [start]
    if abs(start.x - finish.x) > 0.5 and abs(start.z - finish.z) > 0.5:
        route.append(Vector3(finish.x, 0.15, start.z))
    route.append(finish)
    route.append(to_pos)
    return route

func _create_citizen_agents() -> void:
    citizen_agents.clear()
    road_network = get_parent().get_node_or_null("RoadNetworkSystem") if get_parent() != null else null
    if citizens_root == null:
        return
    var destinations := _get_citizen_destinations()
    var homes: Array = destinations.homes
    var works: Array = destinations.works
    var leisure: Array = destinations.leisure
    var modes := ["yaya", "bisiklet", "arac", "otobus"]
    for i in range(8):
        var citizen := LumorixProceduralAssetFactory.pedestrian("adult")
        citizen.name = "CitizenAgent_%02d" % i
        citizens_root.add_child(citizen)
        var home: Vector3 = homes[i % homes.size()]
        var work: Vector3 = works[(i + 1) % works.size()]
        var target: Vector3 = leisure[i % leisure.size()]
        var mode: String = modes[i % modes.size()]
        citizen.position = home
        var transport: Node3D = null
        if mode == "bisiklet":
            transport = LumorixProceduralAssetFactory.vehicle("bike")
        elif mode == "arac":
            transport = LumorixProceduralAssetFactory.vehicle("car")
        elif mode == "otobus":
            transport = LumorixProceduralAssetFactory.vehicle("bus")
        if transport != null:
            transport.name = "Transport_%02d" % i
            transport.position.y = 0.35
            citizen.add_child(transport)
            transport.visible = false
        citizen_agents.append({
            "node": citizen,
            "transport": transport,
            "home": home,
            "work": work,
            "target": target,
            "phase": i % 4,
            "mode": mode,
            "wait": 0.0,
            "route": [home],
            "route_index": 0,
            "last_destination_key": "home"
        })

func _update_citizen_agents(delta: float) -> void:
    if citizen_agents.is_empty() or game_state == null:
        return
    citizen_agent_clock += delta
    var hour := float(game_state.day_time)
    for agent in citizen_agents:
        var node: Node3D = agent.node
        if not is_instance_valid(node):
            continue
        var phase := int(agent.phase)
        var destination: Vector3
        var destination_key := "home"
        if hour < 8.0:
            destination = agent.home
            destination_key = "home"
        elif hour < 13.0:
            destination = agent.work
            destination_key = "work"
        elif hour < 20.0:
            destination = agent.target
            destination_key = "leisure"
        else:
            destination = agent.home
            destination_key = "home"
        if str(agent.last_destination_key) != destination_key:
            agent.route = _build_citizen_route(node.position, destination, str(agent.mode))
            agent.route_index = 0
            agent.last_destination_key = destination_key
        var route: Array = agent.route
        if route.is_empty():
            route = [destination]
            agent.route = route
        var route_index := int(agent.route_index)
        route_index = min(route_index, route.size() - 1)
        var next_point: Vector3 = route[route_index]
        if node.position.distance_to(next_point) < 1.0:
            if route_index < route.size() - 1:
                route_index += 1
                agent.route_index = route_index
                next_point = route[route_index]
            else:
                continue
        var stagger := float((phase * 17) % 45)
        var local_clock := fmod(citizen_agent_clock + stagger, 45.0)
        if local_clock < 4.0:
            agent.wait = 4.0 - local_clock
        if float(agent.wait) > 0.0:
            agent.wait = max(0.0, float(agent.wait) - delta)
            continue
        var mode := str(agent.get("mode", "yaya"))
        var transport: Node3D = agent.get("transport", null)
        if transport != null:
            transport.visible = hour >= 8.0 and hour < 20.0 and node.position.distance_to(destination) >= 1.0
        # Yaya/bisiklet, ana arter üzerindeki yaya geçidine geldiğinde
        # araçların yeşil olduğu fazda karşıya geçmez. Gerçek şehir hissi için
        # küçük bir bekleme tamponu bırakılır; araç tarafındaki sinyal sistemi
        # ile aynı faz kullanılır.
        if mode in ["yaya", "bisiklet"] and _citizen_waits_at_crosswalk(node.position, next_point):
            continue
        var speed := 2.2
        match mode:
            "bisiklet": speed = 5.0
            "arac": speed = max(4.0, 7.0 - float(game_state.traffic) * 0.02)
            "otobus": speed = max(3.5, 6.0 - float(game_state.traffic) * 0.015)
            _: speed = 2.2
        var direction := node.position.direction_to(next_point)
        if direction.length() > 0.01:
            node.look_at(node.global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
        node.position += direction * speed * delta


func _citizen_waits_at_crosswalk(position: Vector3, next_point: Vector3) -> bool:
    if road_network == null:
        return false
    if not road_network.has_method("is_horizontal_green"):
        return false
    # Demo ağındaki yaya geçidi ana doğu-batı arterinin kuzeyindedir.
    # Vatandaş kuzey-güney yönünde geçiyorsa yatay araç trafiğinin kırmızı
    # olmasını bekler; bisiklet de aynı güvenlik kuralını kullanır.
    var near_crosswalk: bool = abs(position.x) <= 6.0 and abs(position.z - 29.0) <= 2.5
    var moving_across: bool = abs(next_point.z - position.z) > abs(next_point.x - position.x)
    if near_crosswalk and moving_across:
        return bool(road_network.is_horizontal_green())
    return false

func _create_representative_citizen() -> void:
    representative_citizen = Node3D.new()
    representative_citizen.name = "RepresentativeCitizen"
    citizens_root.add_child(representative_citizen)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 1.15
    capsule.radius = 0.22
    body.mesh = capsule
    body.position.y = 0.75
    body.material_override = _mat(Color("#f0b27a"))
    representative_citizen.add_child(body)
    var torso := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.42, 0.65, 0.24)
    torso.mesh = box
    torso.position.y = 0.35
    torso.material_override = _mat(Color("#3d5a80"))
    representative_citizen.add_child(torso)
    representative_citizen.position = Vector3.ZERO

func _find_building_position(address_text: String) -> Vector3:
    if game_state == null:
        return Vector3.ZERO
    for building in game_state.buildings:
        if not building is Dictionary:
            continue
        var b: Dictionary = building
        var address = b.get("address", {})
        if address is Dictionary and str(address.get("full", "")) == address_text:
            return b.get("position", Vector3.ZERO)
    return Vector3.ZERO

func _find_citizen_target() -> Vector3:
    var phase := str(game_state.citizen_routine_phase)
    if phase == "ev":
        return _find_building_position(str(game_state.citizen_home_address))
    var destination := str(game_state.citizen_destination_address)
    for park in game_state.park_destinations:
        if park is Dictionary and str(park.get("address", "")) == destination:
            return park.get("position", Vector3.ZERO)
    return _find_building_position(destination)

func _update_representative_citizen(delta: float) -> void:
    if representative_citizen == null or game_state == null:
        return
    var key := "%s|%s|%s|%s" % [game_state.citizen_routine_phase, game_state.citizen_destination_address, game_state.citizen_transport_mode, game_state.citizen_routine_tick]
    if key != representative_trip_key:
        representative_trip_key = key
        representative_target = _find_citizen_target()
        representative_moving = true
        if representative_citizen.position.distance_to(representative_target) > 120.0:
            representative_citizen.position = _find_building_position(str(game_state.citizen_home_address))
    if not representative_moving:
        return
    var distance := representative_citizen.position.distance_to(representative_target)
    if distance < 0.8:
        representative_citizen.position = representative_target
        representative_moving = false
        return
    var speed := 2.2
    match str(game_state.citizen_transport_mode):
        "bisiklet": speed = 5.0
        "otobus", "metro", "tren": speed = 7.0
        "arac": speed = 6.0
    var direction := representative_citizen.position.direction_to(representative_target)
    representative_citizen.position += direction * speed * delta
    representative_citizen.position.y = 0.0
    if direction.length() > 0.01:
        representative_citizen.rotation.y = atan2(direction.x, direction.z)

func _create_transit_hubs() -> void:
    # Fiziksel toplu taşıma düğümleri: istasyon, yaya erişimi ve indirme/bindirme alanı.
    var hubs := [
        {"id":"metro_001", "name":"Lumorix Metro Merkez", "type":"metro", "position":Vector3(0,0,28), "size":Vector3(9,4,7)},
        {"id":"train_001", "name":"Lumorix Tren Garı", "type":"train_station", "position":Vector3(64,0,28), "size":Vector3(12,5,8)}
    ]
    for data in hubs:
        var root := Node3D.new()
        root.name = str(data.id)
        root.position = data.position
        props_root.add_child(root)
        var visual: Node3D
        if str(data.type) == "metro":
            visual = LumorixProceduralAssetFactory.metro_station(data.size)
        else:
            visual = LumorixProceduralAssetFactory.train_station(data.size)
        root.add_child(visual)
        var approach := _mesh_box(Vector3(5.0,0.08,3.0), Color("#8d969c"))
        approach.position = Vector3(0,0.08,6.0)
        root.add_child(approach)
        var dropoff := _mesh_box(Vector3(7.0,0.08,2.2), Color("#59636a"))
        dropoff.position = Vector3(0,0.09,-5.0)
        root.add_child(dropoff)
        for i in 5:
            var passenger := LumorixProceduralAssetFactory.pedestrian("walker")
            passenger.name = "%s_Passenger_%02d" % [data.id, i]
            var angle: float = TAU * float(i) / 5.0
            passenger.position = Vector3(cos(angle) * 3.0, 0.0, sin(angle) * 2.0)
            root.add_child(passenger)
        game_state.buildings.append({
            "id":data.id, "type":data.type, "service":"transport", "lwl":1,
            "max_lwl":10, "premium":false, "interactive":false,
            "capacity":50 if str(data.type) == "metro" else 80,
            "address":{}, "position":data.position
        })
        transit_hubs.append({"node":root, "id":str(data.id), "type":str(data.type), "center":data.position, "radius":3.5, "phase":float(hubs.size())})

func _create_transit_transfer_nodes() -> void:
    # Otobüs + metro/tren aktarma noktaları: fiziksel durak, yaya yaklaşımı ve bekleme alanı.
    var stops := [
        {"id":"bus_stop_001", "name":"Lumorix Merkez Aktarma", "position":Vector3(0,0,21), "hub":"metro_001"},
        {"id":"bus_stop_002", "name":"Gamer Mahallesi Aktarma", "position":Vector3(18,0,28), "hub":"metro_001"},
        {"id":"bus_stop_003", "name":"Güneş Tren Aktarma", "position":Vector3(55,0,28), "hub":"train_001"}
    ]
    for data in stops:
        var root := Node3D.new()
        root.name = str(data.id)
        root.position = data.position
        props_root.add_child(root)
        var platform := _mesh_box(Vector3(4.5,0.08,2.0), Color("#59636a"))
        root.add_child(platform)
        var shelter := _mesh_box(Vector3(3.2,1.8,0.12), Color("#9ca7ad"))
        shelter.position = Vector3(0,0.95,0.8)
        root.add_child(shelter)
        var sign := _mesh_box(Vector3(0.12,1.8,0.12), Color("#3b4a52"))
        sign.position = Vector3(-1.8,0.9,-0.7)
        root.add_child(sign)
        for i in 3:
            var passenger := LumorixProceduralAssetFactory.pedestrian("walker")
            passenger.name = "%s_Waiter_%02d" % [data.id, i]
            passenger.position = Vector3(-1.2 + float(i) * 1.1, 0.0, -0.2)
            root.add_child(passenger)
        game_state.buildings.append({
            "id":data.id, "name":data.name, "type":"bus_stop", "service":"transport",
            "lwl":1, "max_lwl":5, "premium":false, "interactive":false,
            "capacity":30, "address":{}, "position":data.position,
            "transfer_hub":data.hub
        })

func _update_transit_transfer_nodes() -> void:
    if game_state == null:
        return
    var pressure: float = clampf(float(game_state.transit_station_load) + float(game_state.transit_transfer_pressure), 0.0, 2.0)
    for child in props_root.get_children():
        if not child.name.begins_with("bus_stop_"):
            continue
        var waiting := int(clamp(pressure * 3.0, 0.0, 6.0))
        var shown := 0
        for node in child.get_children():
            if node.name.begins_with(str(child.name) + "_Waiter_"):
                node.visible = shown < waiting
                shown += 1

func _update_transit_hubs(delta: float) -> void:
    if game_state == null:
        return
    transit_hub_time += delta
    var load: float = clampf(float(game_state.transit_station_load), 0.0, 1.5)
    var waiting := int(game_state.transit_waiting_passengers)
    for hub in transit_hubs:
        var root: Node3D = hub.node
        if not is_instance_valid(root):
            continue
        var pressure: float = clampf(load + float(waiting) / 100.0, 0.0, 1.5)
        var phase := float(hub.phase)
        var i := 0
        for child in root.get_children():
            if not child.name.begins_with(str(hub.id) + "_Passenger_"):
                continue
            var passenger := child as Node3D
            if passenger == null:
                continue
            var radius: float = float(hub.radius) + pressure * 2.2
            var angle: float = transit_hub_time * (0.35 + pressure * 0.2) + phase + float(i) * 1.25
            passenger.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius * 0.65)
            i += 1
        var crowded: bool = load >= 0.85 or waiting >= 20
        root.scale = Vector3.ONE * (1.0 + (0.015 if crowded else 0.0))

func _create_ground() -> void:
    var ground := _mesh_box(Vector3(WORLD_METERS, 0.5, WORLD_METERS), Color("#6f9a67"))
    ground.position = Vector3(0, -0.35, 0)
    world_root.add_child(ground)

func _create_water() -> void:
    var water := _mesh_box(Vector3(180, 0.15, 28), Color("#2b87b9"))
    water.position = Vector3(0, WATER_LEVEL, -170)
    world_root.add_child(water)

func _create_coast() -> void:
    for x in range(-80, 81, 8):
        var beach := _mesh_box(Vector3(7.0, 0.12, 4.0), Color("#d8c28a"))
        beach.position = Vector3(x, -0.05, -151 + sin(float(x) * 0.12) * 1.5)
        world_root.add_child(beach)

func _create_roads() -> void:
    for x in range(-144, 145, 32):
        _add_road(Vector3(x, 0.02, 0), Vector3(2.8, 0.12, WORLD_METERS), 2)
    for z in range(-144, 145, 32):
        _add_road(Vector3(0, 0.025, z), Vector3(WORLD_METERS, 0.12, 2.8), 2)
    _add_road(Vector3(0, 0.04, 92), Vector3(WORLD_METERS, 0.18, 7.5), 4)

func _add_road(pos: Vector3, size: Vector3, lanes: int) -> void:
    var road := _mesh_box(size, Color("#252a2e"))
    road.position = pos
    roads_root.add_child(road)
    if lanes >= 4:
        var stripe := _mesh_box(Vector3(size.x if size.x > size.z else 0.12, 0.02, size.z if size.z > size.x else 0.12), Color("#d8c65d"))
        stripe.position = pos + Vector3(0, 0.08, 0)
        roads_root.add_child(stripe)

func _create_initial_city() -> void:
    var definitions := [
        {"id":"res_001", "name":"Konut Bölgesi", "type":"residential", "size":Vector3(7, 10, 7), "color":Color("#b9d0df")},
        {"id":"com_001", "name":"Ticaret Merkezi", "type":"commercial", "size":Vector3(9, 16, 9), "color":Color("#d8b66c")},
        {"id":"fac_001", "name":"Çimento Fabrikası", "type":"factory", "size":Vector3(11, 8, 11), "color":Color("#858b92")},
        {"id":"pol_001", "name":"Polis Merkezi", "type":"police", "size":Vector3(7, 8, 7), "color":Color("#3c6795")},
        {"id":"hos_001", "name":"Şehir Hastanesi", "type":"hospital", "size":Vector3(10, 12, 8), "color":Color("#dfe9ee")},
        {"id":"sch_001", "name":"Şehir Okulu", "type":"school", "size":Vector3(9, 7, 9), "color":Color("#d69b56")},
        {"id":"fir_001", "name":"Merkez İtfaiye", "type":"fire", "size":Vector3(8, 7, 8), "color":Color("#a9473e")},
        {"id":"pow_001", "name":"Elektrik Santrali", "type":"power", "size":Vector3(9, 7, 9), "color":Color("#858b92")},
        {"id":"wat_001", "name":"Su Tesisi", "type":"water", "size":Vector3(9, 7, 9), "color":Color("#5688a8")},
        {"id":"sea_001", "name":"Kanalizasyon Tesisi", "type":"sewage", "size":Vector3(9, 7, 9), "color":Color("#667c73")},
        {"id":"was_001", "name":"Atık Tesisi", "type":"waste", "size":Vector3(9, 7, 9), "color":Color("#7b765f")},
        {"id":"mall_001", "name":"Lumorix AVM", "type":"mall", "size":Vector3(15, 9, 12), "color":Color("#6c91bd"), "interactive":true},
        {"id":"stad_001", "name":"Lumorix Stadyumu", "type":"stadium", "size":Vector3(21, 6, 15), "color":Color("#4d7d55"), "interactive":true},
        {"id":"gas_001", "name":"Benzin İstasyonu", "type":"gas_station", "size":Vector3(12, 5, 10), "color":Color("#e3e0d2"), "interactive":true},
        {"id":"dealer_001", "name":"Otomotiv Satış Bayisi", "type":"automotive_dealership", "size":Vector3(15, 8, 12), "color":Color("#d9e1e8"), "interactive":true}
    ]
    for d in definitions:
        if str(d.type) in ["power", "water", "sewage", "waste", "police", "fire", "hospital", "school"]:
            d["service"] = {"power":"electricity", "water":"water", "sewage":"sewage", "waste":"waste", "police":"police", "fire":"fire", "hospital":"health", "school":"education"}.get(str(d.type), str(d.type))
            d["max_level"] = 5

    var positions := [Vector3(-44,0,-32), Vector3(0,0,-32), Vector3(44,0,-32), Vector3(-44,0,22), Vector3(0,0,22), Vector3(44,0,22), Vector3(-32,0,70), Vector3(30,0,70), Vector3(-65,0,68), Vector3(-15,0,68), Vector3(75,0,68), Vector3(58,0,68), Vector3(92,0,68), Vector3(116,0,68), Vector3(116,0,36)]
    for i in definitions.size():
        _spawn_building(definitions[i], positions[i])

func _spawn_building(data: Dictionary, pos: Vector3) -> void:
    var root := LumorixBuilding.new()
    root.setup({"id":data.id, "name":data.name, "type":data.type, "lwl":1, "max_lwl":int(data.get("max_level", 10)), "interactive":data.get("interactive", false), "capacity":int(data.get("capacity", 100))})
    root.name = data.id
    buildings_root.add_child(root)
    root.position = pos
    var visual: Node3D
    match data.type:
        "residential": visual = LumorixProceduralAssetFactory.residential(data.size)
        "commercial": visual = LumorixProceduralAssetFactory.commercial(data.size)
        "police": visual = LumorixProceduralAssetFactory.police(data.size)
        "hospital": visual = LumorixProceduralAssetFactory.hospital(data.size)
        "mall": visual = LumorixProceduralAssetFactory.mall(data.size)
        "stadium": visual = LumorixProceduralAssetFactory.stadium(data.size)
        "gas_station": visual = LumorixProceduralAssetFactory.gas_station(data.size)
        "automotive_dealership": visual = LumorixProceduralAssetFactory.automotive_dealership(data.size)
        "factory": visual = LumorixProceduralAssetFactory.factory(data.size)
        "school": visual = LumorixProceduralAssetFactory.school(data.size)
        "fire": visual = LumorixProceduralAssetFactory.fire_station(data.size)
        "power", "water", "sewage", "waste": visual = LumorixProceduralAssetFactory.utility(data.size, data.color)
        _: visual = LumorixProceduralAssetFactory.building_shell(data.size, data.color, Color("#243b5a"))
    root.add_child(visual)
    var body := visual.get_child(0) as MeshInstance3D
    if body != null:
        var static_body := StaticBody3D.new()
        static_body.name = "BuildingCollision"
        var collision := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = data.size
        collision.shape = box
        collision.position.y = data.size.y / 2.0
        static_body.add_child(collision)
        root.add_child(static_body)
    var roof := visual.get_child(1) as MeshInstance3D if visual.get_child_count() > 1 else null
    root.set_visuals(body, roof)
    root.selected.connect(_on_building_selected)
    if root.interactive:
        var area := Area3D.new()
        area.name = "InteractionArea"
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(data.size.x, data.size.y + 1.0, data.size.z)
        shape_node.shape = shape
        shape_node.position.y = data.size.y / 2.0
        area.add_child(shape_node)
        root.add_child(area)
        area.input_event.connect(_on_interaction_input.bind(root))
    var address_system := get_parent().get_node_or_null("CityAddressSystem")
    var address: Dictionary = {}
    if address_system != null:
        address = address_system.get_address_for_position(pos, str(data.id))
    game_state.buildings.append({"id":data.id, "type":data.type, "service":data.get("service", data.type), "lwl":1, "max_lwl":int(data.get("max_level", 10)), "premium":false, "expansion":bool(data.get("expansion", false)), "address":address, "position":pos})
    building_lookup[data.id] = root

func apply_building_upgrade_visual(building_id: String, new_level: int) -> void:
    if not building_lookup.has(building_id):
        return
    var building: LumorixBuilding = building_lookup[building_id]
    if is_instance_valid(building):
        building.set_level(new_level)
        var state_data: Dictionary = {}
        for data in game_state.buildings:
            if str(data.get("id", "")) == building_id:
                state_data = data
                break
        var label := building.get_node_or_null("UpgradeLevelLabel") as Label3D
        if label == null:
            label = Label3D.new()
            label.name = "UpgradeLevelLabel"
            label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            label.font_size = 28
            label.outline_size = 6
            building.add_child(label)
        label.text = "LWL %d" % new_level
        label.position = Vector3(0, max(4.0, float(state_data.get("position", building.position).y) + 4.0), 0)
        label.visible = new_level >= 2

func place_terrain_building(parcel_id: String, building_type: String, building_id: String, slot_index: int) -> bool:
    var friend_system := get_parent().get_node_or_null("FriendSystem") if get_parent() != null else null
    if friend_system != null and friend_system.has_method("can_modify_city") and not friend_system.can_modify_city():
        return false
    if not terrain_parcels.has(parcel_id):
        return false
    var parcel: Node3D = terrain_parcels[parcel_id]
    var offsets := [Vector3(-9,0,-8), Vector3(0,0,-8), Vector3(9,0,-8), Vector3(-9,0,7), Vector3(0,0,7), Vector3(9,0,7)]
    if slot_index < 0 or slot_index >= offsets.size():
        return false
    var data := {
        "id":building_id,
        "name":building_type.capitalize(),
        "type":building_type,
        "size":Vector3(6,7,6),
        "color":Color("#8aa0b8"),
        "interactive":false,
        "expansion":true
    }
    if building_type == "commercial":
        data.size = Vector3(7,10,7)
        data.color = Color("#d8b66c")
    elif building_type == "factory":
        data.size = Vector3(8,6,8)
        data.color = Color("#858b92")
    elif building_type == "public":
        data.size = Vector3(7,8,7)
        data.color = Color("#3c6795")
    _spawn_building(data, parcel.position + offsets[slot_index])
    return true

func _create_service_vehicles() -> void:
    var placements := [
        {"kind":"garbage_truck", "pos":Vector3(67,0.55,66)},
        {"kind":"fuel_tanker", "pos":Vector3(108,0.55,66)},
        {"kind":"logistics_truck", "pos":Vector3(100,0.55,28)},
        {"kind":"construction_truck", "pos":Vector3(76,0.55,34)},
        {"kind":"municipal_service", "pos":Vector3(54,0.55,42)}
    ]
    for item in placements:
        var vehicle := LumorixProceduralAssetFactory.service_vehicle(str(item.kind))
        vehicle.position = item.pos
        props_root.add_child(vehicle)

func _create_event_areas() -> void:
    var definitions := [
        {"id":"concert_area_001", "type":"concert_area", "name":"Lumorix Konser Alanı", "position":Vector3(-20,0,92), "size":Vector3(22,0.3,16), "premium":false, "kind":"concert"},
        {"id":"rally_area_001", "type":"rally_area", "name":"Lumorix Halk / Miting Alanı", "position":Vector3(28,0,92), "size":Vector3(22,0.3,16), "premium":false, "kind":"rally"}
    ]
    for d in definitions:
        var node := LumorixProceduralAssetFactory.event_area(d.size, false, d.kind)
        node.position = d.position
        node.name = d.id
        props_root.add_child(node)
        event_area_nodes[d.id] = node
        game_state.event_area_status[d.kind] = true
        _spawn_event_crowd(d.position + Vector3(0, 0.55, 0), 18 if d.kind == "concert" else 16)
        game_state.buildings.append({"id":d.id,"name":d.name,"type":d.type,"lwl":1,"max_lwl":10,"premium":false,"position":d.position,"address":{}})

func _spawn_event_crowd(center: Vector3, count: int, premium: bool = false) -> void:
    var parent := Node3D.new()
    parent.name = "EventCrowd_%s" % str(center)
    add_child(parent)
    for i in range(count):
        var actor := LumorixProceduralAssetFactory.pedestrian("walker" if i % 3 else "runner")
        actor.position = center + Vector3(((i % 7) - 3) * 2.2, 0.0, ((i / 7) - 2) * 1.8)
        parent.add_child(actor)
        event_crowd_nodes.append(actor)
    if premium:
        var light := OmniLight3D.new()
        light.position = center + Vector3(0, 5, 0)
        light.omni_range = 12.0
        light.light_energy = 0.9
        parent.add_child(light)

func _update_event_crowds(delta: float) -> void:
    if event_crowd_nodes.is_empty():
        return
    event_area_time += delta
    for i in range(event_crowd_nodes.size()):
        var actor := event_crowd_nodes[i]
        if is_instance_valid(actor):
            actor.rotation.y = sin(event_area_time * 0.7 + float(i)) * 0.18
            actor.position.y = 0.03 + abs(sin(event_area_time * 1.2 + float(i))) * 0.03

func activate_premium_catalog_item(premium_id: String) -> void:
    if premium_id in ["premium_concert_area", "premium_rally_area", "premium_crane_pack"]:
        if premium_id in ["premium_concert_area", "premium_rally_area"]:
            activate_premium_event_area(premium_id)
        elif premium_id == "premium_crane_pack":
            set_construction_slot_capacity(5)
        return
    var existing_id := "premium_%s_001" % premium_id
    if building_lookup.has(existing_id):
        return
    for item in game_state.buildings:
        if str(item.get("id", "")) == existing_id:
            return
    var positions := {
        "super_police":Vector3(-116,0,92), "super_fire":Vector3(-92,0,92),
        "special_hospital":Vector3(-68,0,92), "special_university":Vector3(-44,0,92),
        "grand_hotel":Vector3(52,0,92), "mega_airport":Vector3(78,0,92),
        "mega_port":Vector3(104,0,92), "premium_metro":Vector3(-116,0,112),
        "premium_train_station":Vector3(-92,0,112), "mega_bridge":Vector3(-68,0,112),
        "premium_roundabout":Vector3(-44,0,112), "premium_power":Vector3(52,0,112),
        "premium_water":Vector3(78,0,112), "premium_sewage":Vector3(104,0,112),
        "premium_waste":Vector3(-116,0,132), "premium_treatment":Vector3(-92,0,132),
        "premium_mall":Vector3(-68,0,132), "mega_stadium":Vector3(-44,0,132),
        "premium_gas_station":Vector3(52,0,132), "premium_automotive_dealership":Vector3(78,0,132)
    }
    if not positions.has(premium_id):
        return
    var node := LumorixProceduralAssetFactory.premium_landmark(premium_id)
    node.position = positions[premium_id]
    node.name = existing_id
    props_root.add_child(node)
    building_lookup[existing_id] = node
    game_state.buildings.append({"id":existing_id,"name":premium_id,"type":premium_id,"lwl":20,"max_lwl":20,"premium":true,"position":node.position,"address":{}})

func activate_premium_event_area(premium_id: String) -> void:
    var is_concert := premium_id == "premium_concert_area"
    var kind := "concert" if is_concert else "rally"
    var id := "premium_concert_area_001" if is_concert else "premium_rally_area_001"
    if event_area_nodes.has(id):
        return
    var pos := Vector3(-20,0,112) if is_concert else Vector3(28,0,112)
    var node := LumorixProceduralAssetFactory.event_area(Vector3(26,0.3,20), true, kind)
    node.position = pos
    node.name = id
    props_root.add_child(node)
    event_area_nodes[id] = node
    game_state.event_area_status["premium_concert" if is_concert else "premium_rally"] = true
    game_state.buildings.append({"id":id,"name":("Lumorix Süper Konser Alanı" if is_concert else "Lumorix Süper Miting Alanı"),"type":("premium_concert_area" if is_concert else "premium_rally_area"),"lwl":20,"max_lwl":20,"premium":true,"position":pos,"address":{}})
    _spawn_event_crowd(pos + Vector3(0, 0.55, 0), 28 if is_concert else 24, true)
    game_state.city_message.emit("💎 Premium etkinlik alanı açıldı: %s" % ("Süper Konser Alanı" if is_concert else "Süper Miting Alanı"), "success")

func _update_event_area_lights() -> void:
    for id in ["premium_concert_area_001", "premium_rally_area_001"]:
        if not event_area_nodes.has(id):
            continue
        var root: Node3D = event_area_nodes[id]
        var pulse := 1.4 + sin(event_area_time * 4.0) * 0.8
        for child in root.get_children():
            if child is OmniLight3D:
                child.light_energy = max(0.3, pulse)

func _create_construction_cranes() -> void:
    var positions := [Vector3(-4,0,4), Vector3(16,0,4), Vector3(36,0,4), Vector3(-4,0,18), Vector3(16,0,18)]
    for i in positions.size():
        var crane := LumorixProceduralAssetFactory.construction_crane(i >= 3)
        crane.position = positions[i]
        crane.name = "ConstructionCrane_%02d" % i
        crane.visible = i < 3
        props_root.add_child(crane)
        construction_cranes.append(crane)

func set_construction_slot_capacity(capacity: int) -> void:
    var allowed: int = clampi(capacity, 3, 10)
    game_state.construction_slot_capacity = allowed
    game_state.construction_slots = allowed
    for i in construction_cranes.size():
        construction_cranes[i].visible = i < allowed

func _create_parks() -> void:
    var park_positions := [Vector3(-12,0,58), Vector3(10,0,48), Vector3(64,0,48)]
    for index in park_positions.size():
        var p: Vector3 = park_positions[index]
        var park := Node3D.new()
        park.name = "Park_%d" % (index + 1)
        park.position = p
        props_root.add_child(park)
        var base := _mesh_box(Vector3(18,0.15,12), Color("#4f9a55"))
        park.add_child(base)
        for i in 7:
            var trunk := _mesh_box(Vector3(0.35,2.2,0.35), Color("#6b472b"))
            trunk.position = Vector3(rng.randf_range(-7,7),1.1,rng.randf_range(-4,4))
            park.add_child(trunk)
            var crown := _mesh_box(Vector3(1.5,1.5,1.5), Color("#2f733d"))
            crown.position = trunk.position + Vector3(0,1.6,0)
            park.add_child(crown)

        # Çocuk oyun alanı: salıncak, kaydırak ve küçük oyun zemini.
        var playground := _mesh_box(Vector3(5.0,0.08,3.8), Color("#d7b35f"))
        playground.position = Vector3(-4.5,0.14,2.5)
        park.add_child(playground)
        var slide := _mesh_box(Vector3(1.8,0.16,0.35), Color("#c96b4b"))
        slide.position = Vector3(-4.5,1.25,2.5)
        slide.rotation_degrees.z = -25
        park.add_child(slide)
        for sx in [-1.3, 1.3]:
            var swing_post := _mesh_box(Vector3(0.16,2.0,0.16), Color("#48545b"))
            swing_post.position = Vector3(-4.5 + sx,1.0,1.0)
            park.add_child(swing_post)
        var swing_bar := _mesh_box(Vector3(2.8,0.14,0.14), Color("#48545b"))
        swing_bar.position = Vector3(-4.5,2.0,1.0)
        park.add_child(swing_bar)

        # Açık spor alanı: basketbol/futbol/fitness kullanımı.
        var court := _mesh_box(Vector3(8.0,0.06,5.0), Color("#667c83"))
        court.position = Vector3(4.0,0.13,-2.0)
        park.add_child(court)
        var hoop_post := _mesh_box(Vector3(0.16,2.8,0.16), Color("#d9d9d9"))
        hoop_post.position = Vector3(0.5,1.45,-4.0)
        park.add_child(hoop_post)
        var hoop := _mesh_box(Vector3(0.9,0.08,0.08), Color("#e07b42"))
        hoop.position = Vector3(0.5,2.55,-3.75)
        park.add_child(hoop)
        var fitness := _mesh_box(Vector3(2.4,0.45,0.5), Color("#5c6670"))
        fitness.position = Vector3(4.0,0.45,2.8)
        park.add_child(fitness)

        # Banklar ve çöp kutuları.
        for bx in [-5.5, 0.0, 5.5]:
            var bench := _mesh_box(Vector3(2.0,0.3,0.55), Color("#76553a"))
            bench.position = Vector3(bx,0.28,-4.5)
            park.add_child(bench)
            var bin := _mesh_box(Vector3(0.35,0.65,0.35), Color("#3f5557"))
            bin.position = Vector3(bx + 1.4,0.33,-4.2)
            park.add_child(bin)

        # Park içi gerçek hareket: çocuk, yürüyüş ve spor grupları.
        _spawn_recreation_actor("child", p + Vector3(-5.5,0.08,2.0), p + Vector3(-1.5,0.08,2.0), 0.65, 90.0, false)
        _spawn_recreation_actor("child", p + Vector3(-2.0,0.08,1.8), p + Vector3(-6.0,0.08,1.8), 0.55, 105.0, true)
        _spawn_recreation_actor("walker", p + Vector3(-7.0,0.08,-3.8), p + Vector3(7.0,0.08,-3.8), 0.55, 150.0, false)
        _spawn_recreation_actor("runner", p + Vector3(-7.0,0.08,-1.0), p + Vector3(7.0,0.08,-1.0), 1.2, 100.0, true)
        _spawn_recreation_actor("cyclist", p + Vector3(7.0,0.08,3.8), p + Vector3(-7.0,0.08,3.8), 0.8, 135.0, false)
        _spawn_recreation_actor("seated", p + Vector3(-1.5,0.08,-4.0), p + Vector3(1.5,0.08,-4.0), 0.18, 180.0, false)
        _spawn_recreation_actor("seated", p + Vector3(1.5,0.08,-4.0), p + Vector3(-1.5,0.08,-4.0), 0.16, 210.0, true)

    if game_state != null:
        var destinations: Array[Dictionary] = [
            {"name":"Lumorix Merkez Parkı", "type":"park", "position":park_positions[0], "address":"Lumorix Merkez, Park Yolu"},
            {"name":"Gamer Yaşam Parkı", "type":"park", "position":park_positions[1], "address":"Gamer Mahallesi, Yeşil Park Caddesi"},
            {"name":"Sahil Spor Parkı", "type":"sports_park", "position":park_positions[2], "address":"Güneş Mahallesi, Sahil Spor Yolu"}
        ]
        game_state.park_destinations = destinations

func _create_coastal_recreation() -> void:
    # Sahil yürüyüşü + bisiklet yolu + oturma/balık tutma alanları.
    var walk := LumorixProceduralAssetFactory.coastal_path_segment(Vector3(150, 0.08, 2.8), false)
    walk.position = Vector3(0, 0.02, -143.0)
    recreation_root.add_child(walk)
    var bike := LumorixProceduralAssetFactory.coastal_path_segment(Vector3(150, 0.08, 2.0), true)
    bike.position = Vector3(0, 0.04, -138.8)
    recreation_root.add_child(bike)
    for x in range(-68, 69, 17):
        var bench := _mesh_box(Vector3(2.2, 0.35, 0.65), Color("#76553a"))
        bench.position = Vector3(float(x), 0.25, -146.0)
        recreation_root.add_child(bench)
        var back := _mesh_box(Vector3(2.2, 0.75, 0.16), Color("#76553a"))
        back.position = Vector3(float(x), 0.62, -146.25)
        recreation_root.add_child(back)
        var bin := _mesh_box(Vector3(0.35, 0.65, 0.35), Color("#3f5557"))
        bin.position = Vector3(float(x) + 1.7, 0.33, -145.6)
        recreation_root.add_child(bin)
    for x in [-58.0, -35.0, -12.0, 12.0, 35.0, 58.0]:
        var pier := _mesh_box(Vector3(3.0, 0.12, 5.0), Color("#806547"))
        pier.position = Vector3(x, 0.02, -149.0)
        recreation_root.add_child(pier)
        var fisher := LumorixProceduralAssetFactory.pedestrian("fisher")
        fisher.position = Vector3(x, 0.08, -149.5)
        recreation_root.add_child(fisher)
    _spawn_recreation_actor("walker", Vector3(-65,0.08,-143), Vector3(65,0.08,-143), 0.9, 140.0, false)
    _spawn_recreation_actor("walker", Vector3(65,0.08,-142), Vector3(-65,0.08,-142), 0.75, 150.0, true)
    _spawn_recreation_actor("runner", Vector3(-65,0.08,-140.2), Vector3(65,0.08,-140.2), 1.5, 95.0, false)
    _spawn_recreation_actor("runner", Vector3(55,0.08,-139.6), Vector3(-55,0.08,-139.6), 1.35, 90.0, true)
    _spawn_recreation_actor("walker", Vector3(-48,0.08,-138.8), Vector3(48,0.08,-138.8), 0.65, 155.0, false)
    _spawn_recreation_actor("cyclist", Vector3(-60,0.08,-137.7), Vector3(60,0.08,-137.7), 1.15, 105.0, false)
    _spawn_recreation_actor("cyclist", Vector3(58,0.08,-137.2), Vector3(-58,0.08,-137.2), 1.0, 112.0, true)
    _spawn_recreation_actor("dog_walker", Vector3(42,0.08,-143.0), Vector3(-42,0.08,-143.0), 0.55, 150.0, true)
    _spawn_recreation_actor("child", Vector3(-24,0.08,-142.4), Vector3(24,0.08,-142.4), 0.7, 110.0, false)
    _spawn_recreation_actor("child", Vector3(30,0.08,-141.6), Vector3(-30,0.08,-141.6), 0.6, 120.0, true)
    # Küçük sahil kafesi / açık oturma alanları.
    for x in [-50.0, 0.0, 50.0]:
        var cafe := _mesh_box(Vector3(6.0, 0.15, 3.2), Color("#c7a36a"))
        cafe.position = Vector3(x, 0.08, -146.5)
        recreation_root.add_child(cafe)
        var table := _mesh_box(Vector3(0.75, 0.55, 0.75), Color("#76553a"))
        table.position = Vector3(x, 0.4, -146.2)
        recreation_root.add_child(table)
        for side in [-1.0, 1.0]:
            var seat := _mesh_box(Vector3(0.6, 0.25, 0.5), Color("#8c6b4c"))
            seat.position = Vector3(x + side * 0.95, 0.2, -146.2)
            recreation_root.add_child(seat)
    var coastal_sign := _mesh_box(Vector3(1.2, 2.0, 0.18), Color("#47748b"))
    coastal_sign.position = Vector3(-72, 1.0, -143.0)
    recreation_root.add_child(coastal_sign)
    for lx in [-60.0, -30.0, 0.0, 30.0, 60.0]:
        var light := LumorixProceduralAssetFactory.street_lamp()
        light.position = Vector3(lx, 0, -145.5)
        recreation_root.add_child(light)
    state_coastal_activity(20)

func state_coastal_activity(count: int) -> void:
    if game_state != null:
        game_state.coastal_activity_count = count
        game_state.coastal_walkers = 3
        game_state.coastal_runners = 2
        game_state.coastal_cyclists = 2
        game_state.coastal_fishers = 6
        game_state.coastal_dog_walkers = 1
        game_state.coastal_children = 2

func _spawn_recreation_actor(kind: String, start: Vector3, end: Vector3, speed: float, loop_time: float, reverse: bool) -> void:
    var actor := LumorixProceduralAssetFactory.pedestrian(kind)
    actor.position = start
    recreation_root.add_child(actor)
    recreation_actors.append({"node":actor, "kind":kind, "start":start, "end":end, "speed":speed, "loop_time":loop_time, "reverse":reverse})

func add_terrain_parcel(data: Dictionary) -> void:
    if world_root == null:
        return
    var parcel := Node3D.new()
    parcel.name = str(data.id)
    parcel.position = data.center
    terrain_parcels[str(data.id)] = parcel
    world_root.add_child(parcel)
    var base := _mesh_box(Vector3(30, 0.25, 30), Color("#77705c"))
    base.name = "TerrainBase"
    base.position.y = 0.1
    parcel.add_child(base)
    var obstacle_index := 0
    for obstacle in data.obstacles:
        var prop := Node3D.new()
        prop.name = "Obstacle_%d" % obstacle_index
        var x := -9.0 + float(obstacle_index % 3) * 9.0
        var z := -7.0 + float(obstacle_index / 3) * 8.0
        prop.position = Vector3(x, 0.0, z)
        parcel.add_child(prop)
        if obstacle == "tree_cluster":
            var trunk := _mesh_box(Vector3(0.8, 3.5, 0.8), Color("#5c402a"))
            trunk.position.y = 1.75
            prop.add_child(trunk)
            var crown := _mesh_box(Vector3(4.0, 3.0, 4.0), Color("#315f36"))
            crown.position.y = 4.0
            prop.add_child(crown)
        elif obstacle == "mountain":
            var rock := _mesh_box(Vector3(10, 8, 10), Color("#65676b"))
            rock.position.y = 4.0
            prop.add_child(rock)
        else:
            var rock := _mesh_box(Vector3(4.5, 2.5, 4.0), Color("#77787a"))
            rock.position.y = 1.25
            prop.add_child(rock)
        obstacle_index += 1
    var area := Area3D.new()
    area.position.y = 0.5
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(30, 2, 30)
    shape.shape = box
    area.add_child(shape)
    parcel.add_child(area)
    area.input_event.connect(_on_terrain_input.bind(str(data.id)))

func set_terrain_parcel_unlocked_visual(parcel_id: String, unlocked: bool) -> void:
    if not terrain_parcels.has(parcel_id):
        return
    var parcel: Node3D = terrain_parcels[parcel_id]
    var base := parcel.get_node_or_null("TerrainBase")
    if base:
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("#8a7d5b") if unlocked else Color("#77705c")
        material.roughness = 1.0
        base.material_override = material

func set_terrain_job_visual(parcel_id: String, active: bool, machine: String = "excavator") -> void:
    if not terrain_parcels.has(parcel_id):
        return
    var parcel: Node3D = terrain_parcels[parcel_id]
    var existing := parcel.get_node_or_null("TerrainMachine")
    if active:
        if existing:
            existing.queue_free()
        var machine_root := Node3D.new()
        machine_root.name = "TerrainMachine"
        machine_root.position = Vector3(-10, 0.2, -8)
        parcel.add_child(machine_root)
        var body := _mesh_box(Vector3(3.0, 1.2, 2.0), Color("#d29a32"))
        body.position.y = 0.9
        machine_root.add_child(body)
        var cabin := _mesh_box(Vector3(1.2, 1.2, 1.3), Color("#3d5568"))
        cabin.position = Vector3(0.3, 1.8, 0)
        machine_root.add_child(cabin)
        if machine == "excavator":
            var arm := _mesh_box(Vector3(2.4, 0.35, 0.35), Color("#b87920"))
            arm.position = Vector3(1.8, 1.45, 0)
            arm.rotation.z = -0.35
            machine_root.add_child(arm)
            var bucket := _mesh_box(Vector3(1.0, 0.8, 1.2), Color("#8a6325"))
            bucket.position = Vector3(3.0, 0.8, 0)
            machine_root.add_child(bucket)
        elif machine == "bulldozer":
            var blade := _mesh_box(Vector3(0.35, 1.8, 3.0), Color("#8a6325"))
            blade.position = Vector3(1.7, 0.75, 0)
            machine_root.add_child(blade)
        elif machine == "grader":
            var blade := _mesh_box(Vector3(2.2, 0.25, 2.2), Color("#8a6325"))
            blade.position = Vector3(1.0, 0.55, 0)
            machine_root.add_child(blade)
        elif machine == "dump_truck":
            var bed := _mesh_box(Vector3(2.2, 1.0, 2.0), Color("#8a6325"))
            bed.position = Vector3(-0.3, 1.7, 0)
            machine_root.add_child(bed)
        elif machine == "crane":
            var tower := _mesh_box(Vector3(0.5, 4.0, 0.5), Color("#b87920"))
            tower.position.y = 2.6
            machine_root.add_child(tower)
            var boom := _mesh_box(Vector3(4.0, 0.3, 0.3), Color("#b87920"))
            boom.position = Vector3(1.8, 4.3, 0)
            machine_root.add_child(boom)
        elif machine == "asphalt_machine":
            var hopper := _mesh_box(Vector3(2.0, 1.0, 2.2), Color("#40464a"))
            hopper.position = Vector3(-0.4, 1.5, 0)
            machine_root.add_child(hopper)
        var timer := Timer.new()
        timer.name = "WorkTimer"
        timer.wait_time = 0.55
        timer.autostart = true
        timer.timeout.connect(func():
            if is_instance_valid(machine_root):
                machine_root.position.x = -10.0 if machine_root.position.x > 9.0 else machine_root.position.x + 1.2
                machine_root.position.z = -8.0 + sin(Time.get_ticks_msec() / 350.0) * 2.0
        )
        machine_root.add_child(timer)
    else:
        if existing:
            existing.queue_free()
        var base := parcel.get_node_or_null("TerrainBase")
        if base:
            var material := StandardMaterial3D.new()
            material.albedo_color = Color("#4f9a55")
            material.roughness = 1.0
            base.material_override = material
        for child in parcel.get_children():
            if child.name.begins_with("Obstacle_"):
                child.queue_free()


func _on_terrain_input(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, parcel_id: String) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var terrain := get_parent().get_node_or_null("TerrainExpansionSystem")
        if terrain:
            terrain.parcel_selected.emit(parcel_id)
            game_state.city_message.emit("🌍 %s seçildi — Araziyi Düzenle panelini aç." % parcel_id, "info")

func _on_interaction_input(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, building: LumorixBuilding) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        building.selected.emit(building)
        if building.interactive:
            var interactive_system := get_parent().get_node_or_null("InteractiveBuildingSystem")
            if interactive_system:
                interactive_system.open_building(building.building_type)

func _on_building_selected(building: LumorixBuilding) -> void:
    building_selected.emit(building)
    game_state.city_message.emit("%s — %d LWL%s" % [building.display_name, building.lwl, " • ETKİLEŞİMLİ" if building.interactive else ""], "info")

func get_buildings() -> Array[Node]:
    return buildings_root.get_children()
