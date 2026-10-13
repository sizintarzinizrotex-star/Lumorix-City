class_name LumorixPhase4ConstructionTransportSystem
extends Node3D

signal construction_started(data)
signal construction_completed(data)
signal terrain_expanded(data)
signal terrain_adjustment_started(data)
signal terrain_obstacle_removed(data)
signal transport_route_created(data)
signal infrastructure_changed(data)

var world_root: Node3D
var game_state

var construction_root: Node3D
var terrain_root: Node3D
var transport_root: Node3D

var construction_vehicles: Array = []
var construction_jobs: Array = []
var terrain_expansions: Array = []
var terrain_obstacles: Array = []
var transport_routes: Array = []

var max_construction_vehicles := 5
var active_construction_vehicles := 0
var next_job_id := 1
var next_route_id := 1

var city_width := 80
var city_height := 80
var maximum_city_size := 200

var road_count := 0
var bridge_count := 0
var underpass_count := 0
var overpass_count := 0
var metro_route_count := 0
var train_route_count := 0
var airport_count := 0
var port_count := 0

var expansion_cost := 250
var terrain_adjustment_cost := 100

func initialize(p_world_root: Node3D, p_game_state) -> void:
    world_root = p_world_root
    game_state = p_game_state

    construction_root = Node3D.new()
    construction_root.name = "Phase4Construction"
    add_child(construction_root)

    terrain_root = Node3D.new()
    terrain_root.name = "Phase4Terrain"
    add_child(terrain_root)

    transport_root = Node3D.new()
    transport_root.name = "Phase4Transport"
    add_child(transport_root)

    _initialize_construction_vehicles()
    _initialize_terrain_obstacles()

func _initialize_construction_vehicles() -> void:
    construction_vehicles.clear()

    for index in range(max_construction_vehicles):
        construction_vehicles.append({
            "id": index + 1,
            "type": "excavator" if index < 3 else "construction_vehicle",
            "available": true,
            "job_id": 0,
            "position": Vector3.ZERO
        })

func _initialize_terrain_obstacles() -> void:
    terrain_obstacles.clear()

    terrain_obstacles.append({
        "id": 1,
        "type": "mountain",
        "position": Vector3(18.0, 0.0, 18.0),
        "removed": false,
        "cost": 900
    })

    terrain_obstacles.append({
        "id": 2,
        "type": "forest",
        "position": Vector3(-20.0, 0.0, 15.0),
        "removed": false,
        "cost": 450
    })

    terrain_obstacles.append({
        "id": 3,
        "type": "rock",
        "position": Vector3(24.0, 0.0, -20.0),
        "removed": false,
        "cost": 250
    })

func start_terrain_expansion(direction: String, amount: int = 10) -> bool:
    if amount <= 0:
        return false

    if city_width >= maximum_city_size or city_height >= maximum_city_size:
        return false

    var old_width := city_width
    var old_height := city_height

    if direction in ["north", "south", "east", "west"]:
        city_width = mini(city_width + amount, maximum_city_size)
        city_height = mini(city_height + amount, maximum_city_size)
    else:
        return false

    var expansion := {
        "direction": direction,
        "amount": amount,
        "old_width": old_width,
        "old_height": old_height,
        "new_width": city_width,
        "new_height": city_height
    }

    terrain_expansions.append(expansion)
    terrain_expanded.emit(expansion)
    return true

func start_terrain_adjustment(position: Vector3, area_size: Vector2 = Vector2(10, 10)) -> int:
    var job_id := next_job_id
    next_job_id += 1

    var job := {
        "id": job_id,
        "type": "terrain_adjustment",
        "position": position,
        "area_size": area_size,
        "progress": 0.0,
        "completed": false
    }

    construction_jobs.append(job)
    terrain_adjustment_started.emit(job)
    return job_id

func remove_terrain_obstacle(obstacle_id: int) -> bool:
    for obstacle in terrain_obstacles:
        if int(obstacle.get("id", -1)) != obstacle_id:
            continue

        if bool(obstacle.get("removed", false)):
            return false

        obstacle["removed"] = true
        terrain_obstacle_removed.emit(obstacle)
        return true

    return false

func start_construction(position: Vector3, construction_type: String, duration: float = 10.0) -> int:
    if active_construction_vehicles >= max_construction_vehicles:
        return -1

    var job_id := next_job_id
    next_job_id += 1

    var job := {
        "id": job_id,
        "type": construction_type,
        "position": position,
        "duration": maxf(duration, 1.0),
        "progress": 0.0,
        "completed": false
    }

    construction_jobs.append(job)
    active_construction_vehicles += 1
    _assign_vehicle_to_job(job_id)

    construction_started.emit(job)
    return job_id

func _assign_vehicle_to_job(job_id: int) -> void:
    for vehicle in construction_vehicles:
        if bool(vehicle.get("available", false)):
            vehicle["available"] = false
            vehicle["job_id"] = job_id
            return

func create_transport_route(route_type: String, start_position: Vector3, end_position: Vector3) -> int:
    var valid_types := [
        "road",
        "bridge",
        "underpass",
        "overpass",
        "metro",
        "train",
        "bike",
        "walking",
        "coastal"
    ]

    if route_type not in valid_types:
        return -1

    var route_id := next_route_id
    next_route_id += 1

    var route := {
        "id": route_id,
        "type": route_type,
        "start": start_position,
        "end": end_position,
        "active": true
    }

    transport_routes.append(route)

    match route_type:
        "road":
            road_count += 1
        "bridge":
            bridge_count += 1
        "underpass":
            underpass_count += 1
        "overpass":
            overpass_count += 1
        "metro":
            metro_route_count += 1
        "train":
            train_route_count += 1

    transport_route_created.emit(route)
    infrastructure_changed.emit(get_transport_status())
    return route_id

func register_airport(position: Vector3) -> bool:
    airport_count += 1
    infrastructure_changed.emit({
        "type": "airport",
        "count": airport_count,
        "position": position
    })
    return true

func register_port(position: Vector3) -> bool:
    port_count += 1
    infrastructure_changed.emit({
        "type": "port",
        "count": port_count,
        "position": position
    })
    return true

func _process(delta: float) -> void:
    _process_construction(delta)

func _process_construction(delta: float) -> void:
    for job in construction_jobs:
        if bool(job.get("completed", false)):
            continue

        var duration := maxf(float(job.get("duration", 10.0)), 1.0)
        var progress := float(job.get("progress", 0.0))
        progress += (delta / duration) * 100.0
        job["progress"] = minf(progress, 100.0)

        if job["progress"] >= 100.0:
            job["completed"] = true
            active_construction_vehicles = maxi(active_construction_vehicles - 1, 0)
            _release_vehicle(job["id"])
            construction_completed.emit(job)

func _release_vehicle(job_id: int) -> void:
    for vehicle in construction_vehicles:
        if int(vehicle.get("job_id", -1)) == job_id:
            vehicle["available"] = true
            vehicle["job_id"] = 0
            return

func get_construction_status() -> Dictionary:
    return {
        "vehicles_total": construction_vehicles.size(),
        "vehicles_active": active_construction_vehicles,
        "vehicles_available": construction_vehicles.size() - active_construction_vehicles,
        "jobs": construction_jobs.size()
    }

func get_terrain_status() -> Dictionary:
    var removed := 0

    for obstacle in terrain_obstacles:
        if bool(obstacle.get("removed", false)):
            removed += 1

    return {
        "width": city_width,
        "height": city_height,
        "maximum_size": maximum_city_size,
        "obstacles": terrain_obstacles.size(),
        "obstacles_removed": removed,
        "expansions": terrain_expansions.size()
    }

func get_transport_status() -> Dictionary:
    return {
        "routes": transport_routes.size(),
        "roads": road_count,
        "bridges": bridge_count,
        "underpasses": underpass_count,
        "overpasses": overpass_count,
        "metro": metro_route_count,
        "train": train_route_count,
        "airports": airport_count,
        "ports": port_count
    }
