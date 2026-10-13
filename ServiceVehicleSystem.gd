class_name LumorixServiceVehicleSystem
extends Node3D

# Mobile-first municipal/logistics vehicle simulation.
# Vehicles follow short deterministic routes instead of full pathfinding.
var state: Node
var world: Node
var vehicles: Array[Node3D] = []
var routes := [
    {"kind":"garbage_truck", "from":Vector3(66,0.55,66), "to":Vector3(18,0.55,18), "label":"Çöp toplama"},
    {"kind":"fuel_tanker", "from":Vector3(108,0.55,66), "to":Vector3(116,0.55,36), "label":"Akaryakıt ikmali"},
    {"kind":"logistics_truck", "from":Vector3(100,0.55,28), "to":Vector3(44,0.55,22), "label":"Lojistik sevkiyat"},
    {"kind":"construction_truck", "from":Vector3(76,0.55,34), "to":Vector3(0,0.55,70), "label":"İnşaat malzemesi"},
    {"kind":"municipal_service", "from":Vector3(54,0.55,42), "to":Vector3(-32,0.55,70), "label":"Belediye bakım"}
]

func initialize(game_state: Node = null, city_world: Node = null) -> void:
    state = game_state
    world = city_world
    for route in routes:
        _spawn_route_vehicle(route)

func _spawn_route_vehicle(route: Dictionary) -> void:
    var vehicle := LumorixProceduralAssetFactory.service_vehicle(str(route.kind))
    vehicle.position = route.from
    vehicle.set_meta("route_from", route.from)
    vehicle.set_meta("route_to", route.to)
    vehicle.set_meta("route_label", route.label)
    vehicle.set_meta("route_progress", 0.0)
    vehicle.set_meta("route_speed", 4.0 if route.kind == "garbage_truck" else 5.0)
    add_child(vehicle)
    vehicles.append(vehicle)

func _process(delta: float) -> void:
    for vehicle in vehicles:
        if not is_instance_valid(vehicle):
            continue
        var from: Vector3 = vehicle.get_meta("route_from", vehicle.position)
        var to: Vector3 = vehicle.get_meta("route_to", vehicle.position)
        var progress := float(vehicle.get_meta("route_progress", 0.0))
        progress += delta * float(vehicle.get_meta("route_speed", 4.0)) / max(from.distance_to(to), 1.0)
        if progress >= 1.0:
            progress = 0.0
            var old_from := from
            from = to
            to = old_from
            vehicle.set_meta("route_from", from)
            vehicle.set_meta("route_to", to)
            vehicle.rotation.y = atan2(to.x - from.x, to.z - from.z)
            _report_service_activity(str(vehicle.get_meta("route_label", "Şehir hizmeti")))
            if str(vehicle.get_meta("route_label", "")) == "Akaryakıt ikmali":
                var economy := get_node_or_null("../VehicleEconomySystem")
                if economy != null and economy.has_method("register_fuel_delivery"):
                    economy.register_fuel_delivery()
                    state.fuel_delivery_count += 1
        vehicle.set_meta("route_progress", progress)
        vehicle.position = from.lerp(to, progress)

func _report_service_activity(label: String) -> void:
    if state == null:
        return
    if label == "Çöp toplama":
        state.city_message.emit("🚛 Çöp kamyonu toplama rotasını tamamladı.", "success")
    elif label == "Akaryakıt ikmali":
        state.city_message.emit("⛽ Yakıt tankeri ikmal rotasını tamamladı.", "info")
