class_name LumorixDeliverySystem
extends Node3D

# Branded city logistics: Lumorix Kargo handles freight; Lumorix Kurye handles food/order delivery.
var state: Node
var elapsed := 0.0
var report_timer := 0.0
var cargo_deliveries := 0
var courier_deliveries := 0
var cargo_income := 0
var courier_income := 0
var food_orders := 0
var active_routes: Array[Dictionary] = []
var route_elapsed := 0.0
var road_network: Node = null
var delivery_route_count := 0
var cargo_units := 0
var food_units := 0
var production: Node = null

func initialize(game_state: Node) -> void:
    state = game_state
    cargo_deliveries = 0
    courier_deliveries = 0
    cargo_income = 0
    courier_income = 0
    food_orders = 0
    active_routes.clear()
    route_elapsed = 0.0
    delivery_route_count = 0
    road_network = get_parent().get_node_or_null("RoadNetworkSystem") if get_parent() != null else null
    production = get_parent().get_node_or_null("ProductionSystem") if get_parent() != null else null
    _sync_state()

func _process(delta: float) -> void:
    if state == null:
        return
    elapsed += delta
    report_timer += delta
    if elapsed >= 4.0:
        elapsed = 0.0
        _simulate_orders()
    route_elapsed += delta
    if route_elapsed >= 6.0:
        route_elapsed = 0.0
        _dispatch_route()
    _update_routes(delta)
    if report_timer >= 30.0:
        report_timer = 0.0
        if cargo_deliveries > 0 or courier_deliveries > 0:
            state.city_message.emit("📦 Lumorix Kargo %d | 🛵 Lumorix Kurye %d teslimat tamamladı." % [cargo_deliveries, courier_deliveries], "info")

func _simulate_orders() -> void:
    var activity: float = clampf((float(state.population) / 1250.0) * (0.65 + float(state.happiness) / 180.0), 0.2, 4.0)
    var cargo := int(activity * 0.7)
    var food := int(activity * 0.55)
    if cargo > 0:
        cargo_deliveries += cargo
        cargo_units += cargo * 10
        cargo_income += cargo * 3
        state.add_lucb(cargo * 3)
    if food > 0:
        food_orders += food
        food_units += food * 4
        courier_deliveries += food
        courier_income += food * 2
        state.add_lucb(food * 2)
    _sync_state()

func _dispatch_route() -> void:
    var address_system := state.get_parent().get_node_or_null("CityAddressSystem")
    if address_system == null:
        return
    var destinations: Array[Dictionary] = []
    for b in state.buildings:
        var addr: Dictionary = b.get("address", {})
        if not addr.is_empty() and b.get("position", null) is Vector3:
            destinations.append({"address":str(addr.get("full", "")), "position":b.get("position")})
    if destinations.is_empty():
        return
    var is_food := food_orders > 0 and (courier_deliveries <= cargo_deliveries or destinations.size() % 2 == 0)
    if production != null and production.has_method("get_inventory"):
        var inv: Dictionary = production.get_inventory()
        if is_food and int(inv.get("food", 0)) < 4:
            is_food = false
        if not is_food and int(inv.get("cement", 0)) + int(inv.get("steel", 0)) + int(inv.get("electronics", 0)) < 10:
            is_food = true if int(inv.get("food", 0)) >= 4 else is_food
    var destination: Dictionary = destinations[(cargo_deliveries + courier_deliveries) % destinations.size()]
    var kind := "courier" if is_food else "cargo_van"
    var vehicle := LumorixProceduralAssetFactory.service_vehicle(kind)
    var start := Vector3(0, 0.55, 92) if is_food else Vector3(108, 0.55, 66)
    vehicle.position = start
    add_child(vehicle)
    var route_points := _build_delivery_route(start, destination.position + Vector3(0, 0.55, 0), kind)
    var manifest_units := 4 if is_food else 10
    var route := {"kind":kind, "address":destination.address, "target":destination.position + Vector3(0, 0.55, 0), "vehicle":vehicle, "points":route_points, "point_index":0, "remaining":18.0, "manifest_units":manifest_units}
    active_routes.append(route)
    delivery_route_count += 1
    state.city_message.emit("%s → %s" % ["🛵 Lumorix Kurye" if is_food else "📦 Lumorix Kargo", str(route.address)], "info")

func _build_delivery_route(start: Vector3, target: Vector3, kind: String) -> Array[Vector3]:
    var points: Array[Vector3] = []
    var waypoints := [
        Vector3(96, 0.55, 64),
        Vector3(64, 0.55, 64),
        Vector3(64, 0.55, 32),
        Vector3(0, 0.55, 32),
        Vector3(0, 0.55, 0)
    ]
    var current := start
    var best_path: Array[Vector3] = []
    var best_score: float = INF
    for pivot in waypoints:
        var score: float = current.distance_to(pivot) + pivot.distance_to(target)
        if kind == "cargo_van" and pivot.x >= 64.0:
            score -= 18.0
        if score < best_score:
            best_score = score
            best_path = [pivot]
    points.append_array(best_path)
    points.append(target)
    return points

func _update_routes(delta: float) -> void:
    for i in range(active_routes.size() - 1, -1, -1):
        active_routes[i].remaining = float(active_routes[i].remaining) - delta
        var vehicle := active_routes[i].vehicle as Node3D
        if vehicle != null:
            var points: Array = active_routes[i].points
            var point_index := int(active_routes[i].point_index)
            if point_index < points.size():
                var target: Vector3 = points[point_index]
                var axis := "horizontal" if abs(target.x - vehicle.position.x) >= abs(target.z - vehicle.position.z) else "vertical"
                var speed: float = 10.0
                if road_network != null and road_network.has_method("get_speed_limit_at"):
                    speed = float(road_network.get_speed_limit_at(vehicle.position, axis))
                if active_routes[i].kind == "courier":
                    speed *= 1.08
                var step: float = minf(speed * delta, vehicle.position.distance_to(target))
                var direction := vehicle.position.direction_to(target)
                vehicle.position += direction * step
                if direction.length() > 0.01:
                    vehicle.look_at(Vector3(target.x, vehicle.position.y, target.z), Vector3.UP)
                if vehicle.position.distance_to(target) < 0.2:
                    active_routes[i].point_index = point_index + 1
            else:
                active_routes[i].remaining = 0.0
        if active_routes[i].remaining <= 0.0:
            if vehicle != null:
                vehicle.queue_free()
            var manifest_units := int(active_routes[i].get("manifest_units", 0))
            if active_routes[i].kind == "courier":
                food_units = max(0, food_units - manifest_units)
            else:
                cargo_units = max(0, cargo_units - manifest_units)
            state.city_message.emit("✅ Teslimat tamamlandı: %s | %d birim" % [str(active_routes[i].address), manifest_units], "success")
            active_routes.remove_at(i)

func _sync_state() -> void:
    state.lumorix_cargo_deliveries = cargo_deliveries
    state.lumorix_courier_deliveries = courier_deliveries
    state.lumorix_food_orders = food_orders
    state.lumorix_cargo_income = cargo_income
    state.lumorix_courier_income = courier_income
    state.lumorix_cargo_units = cargo_units
    state.lumorix_food_units = food_units
    state.lumorix_active_routes = active_routes.size()
    state.lumorix_logistics_efficiency = clamp(1.0 - float(active_routes.size()) * 0.025 + float(state.traffic) * 0.001, 0.55, 1.15)
