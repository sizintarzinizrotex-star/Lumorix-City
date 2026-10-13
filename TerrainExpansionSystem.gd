class_name LumorixTerrainExpansionSystem
extends Node

signal parcel_selected(parcel_id: String)
signal terrain_job_started(parcel_id: String, machine: String)
signal terrain_job_completed(parcel_id: String)
signal building_placed(parcel_id: String, building_type: String, building_id: String)

var state: Node
var world: Node
var parcels: Dictionary = {}
var active_jobs: Dictionary = {}
var rng := RandomNumberGenerator.new()

var building_costs := {
    "residential":{"lucb":1200,"materials":{"cement":20,"steel":8}},
    "commercial":{"lucb":1800,"materials":{"cement":30,"steel":12,"glass":8}},
    "factory":{"lucb":2400,"materials":{"cement":40,"steel":18,"machine":2}},
    "public":{"lucb":2200,"materials":{"cement":35,"steel":14,"glass":6}}
}

var machine_costs := {
    "bulldozer":{"lucb":450,"fuel":8,"time":8.0},
    "excavator":{"lucb":700,"fuel":12,"time":12.0},
    "grader":{"lucb":500,"fuel":9,"time":9.0},
    "dump_truck":{"lucb":350,"fuel":7,"time":7.0},
    "crane":{"lucb":900,"fuel":15,"time":15.0},
    "asphalt_machine":{"lucb":650,"fuel":11,"time":11.0}
}

func initialize(game_state: Node, city_world: Node) -> void:
    state = game_state
    world = city_world
    rng.seed = 998877
    _create_parcels()

func _process(delta: float) -> void:
    for id in active_jobs.keys().duplicate():
        active_jobs[id].remaining -= delta
        if active_jobs[id].remaining <= 0.0:
            var parcel_id := str(id)
            active_jobs.erase(id)
            if parcels.has(parcel_id):
                parcels[parcel_id].obstacles.clear()
                parcels[parcel_id].buildable = true
            if world and world.has_method("set_terrain_job_visual"):
                world.set_terrain_job_visual(parcel_id, false)
            state.city_message.emit("🚜 %s arazisi düzenlendi; inşaata hazır." % parcel_id, "success")
            terrain_job_completed.emit(parcel_id)

func _create_parcels() -> void:
    var definitions := [
        {"id":"sector_north", "center":Vector3(0,0,-120), "terrain":"forest", "obstacles":["tree_cluster","tree_cluster","rock"]},
        {"id":"sector_east", "center":Vector3(120,0,0), "terrain":"hill", "obstacles":["rock","stone"]},
        {"id":"sector_south", "center":Vector3(0,0,120), "terrain":"mountain", "obstacles":["mountain","rock","stone"]},
        {"id":"sector_west", "center":Vector3(-120,0,0), "terrain":"forest", "obstacles":["tree_cluster","tree_cluster","tree_cluster"]}
    ]
    for d in definitions:
        parcels[d.id] = {"id":d.id,"center":d.center,"terrain":d.terrain,"obstacles":d.obstacles.duplicate(),"unlocked":false,"buildable":false,"road_connected":false,"building_slots":6,"used_slots":0,"placed_buildings":[]}
        if world and world.has_method("add_terrain_parcel"):
            world.add_terrain_parcel(d)

func _can_modify_city() -> bool:
    var friend_system := state.get_parent().get_node_or_null("FriendSystem") if state != null and state.get_parent() != null else null
    if friend_system != null and friend_system.has_method("can_modify_city"):
        return bool(friend_system.can_modify_city())
    return true

func unlock_parcel(parcel_id: String) -> bool:
    if not _can_modify_city():
        state.city_message.emit("🏙️ Arkadaş şehrini ziyaret ederken şehir değişikliği yapılamaz.", "warning")
        return false
    if not parcels.has(parcel_id):
        return false
    var parcel: Dictionary = parcels[parcel_id]
    if parcel.unlocked:
        return true
    var cost := 2500 + parcels.keys().find(parcel_id) * 1750
    if not state.spend_lucb(cost):
        return false
    parcel.unlocked = true
    parcels[parcel_id] = parcel
    if world and world.has_method("set_terrain_parcel_unlocked_visual"):
        world.set_terrain_parcel_unlocked_visual(parcel_id, true)
    state.city_message.emit("🌍 %s açıldı. Araziyi düzenlemek için üzerine tıkla." % parcel_id, "success")
    return true

func begin_terrain_edit(parcel_id: String, machine: String = "excavator") -> bool:
    if not _can_modify_city():
        state.city_message.emit("🏙️ Arkadaş şehrini ziyaret ederken şehir değişikliği yapılamaz.", "warning")
        return false
    if not parcels.has(parcel_id):
        return false
    var parcel: Dictionary = parcels[parcel_id]
    if not parcel.unlocked:
        state.city_message.emit("Önce bu araziyi açmalısın.", "warning")
        return false
    if parcel.buildable:
        state.city_message.emit("Bu arazi zaten düzenlenmiş ve yapılaşmaya hazır.", "info")
        return false
    if active_jobs.has(parcel_id):
        state.city_message.emit("Arazi düzenleme işlemi devam ediyor.", "info")
        return false
    var slot_capacity: int = int(state.construction_slot_capacity)
    if active_jobs.size() >= slot_capacity:
        state.city_message.emit("🏗️ Tüm inşaat vinçleri meşgul. Aktif kapasite: %d/%d. Premium vinç paketi ile 5 slota çıkabilirsin." % [active_jobs.size(), slot_capacity], "warning")
        return false
    var spec: Dictionary = machine_costs.get(machine, machine_costs.excavator)
    var production := state.get_parent().get_node_or_null("ProductionSystem")
    if production and not production.remove_item("fuel", int(spec.fuel)):
        state.city_message.emit("⛽ Arazi düzenlemek için yeterli yakıt yok.", "warning")
        return false
    if not state.spend_lucb(int(spec.lucb)):
        if production:
            production.add_item("fuel", int(spec.fuel))
        return false
    active_jobs[parcel_id] = {"machine":machine,"remaining":float(spec.time),"total":float(spec.time),"fuel":int(spec.fuel)}
    if world and world.has_method("set_terrain_job_visual"):
        world.set_terrain_job_visual(parcel_id, true, machine)
    state.city_message.emit("🚜 %s ile %s arazisi düzenleniyor..." % [machine.capitalize(), parcel_id], "info")
    terrain_job_started.emit(parcel_id, machine)
    return true

func get_parcels() -> Dictionary:
    return parcels

func get_machine_cost(machine: String) -> Dictionary:
    return machine_costs.get(machine, {})

func get_machine_names() -> Array[String]:
    return ["bulldozer", "excavator", "grader", "dump_truck", "crane", "asphalt_machine"]

func get_active_job(parcel_id: String) -> Dictionary:
    return active_jobs.get(parcel_id, {})

func get_job_progress(parcel_id: String) -> float:
    if not active_jobs.has(parcel_id):
        return 0.0
    var job: Dictionary = active_jobs[parcel_id]
    var total: float = maxf(0.01, float(job.get("total", 1.0)))
    return clamp(1.0 - float(job.get("remaining", total)) / total, 0.0, 1.0)

func connect_parcel_road(parcel_id: String, lanes: int = 2) -> bool:
    if not _can_modify_city():
        state.city_message.emit("🏙️ Arkadaş şehrini ziyaret ederken şehir değişikliği yapılamaz.", "warning")
        return false
    if not parcels.has(parcel_id):
        return false
    var parcel: Dictionary = parcels[parcel_id]
    if not parcel.buildable:
        state.city_message.emit("Önce araziyi düzenlemelisin.", "warning")
        return false
    if parcel.road_connected:
        state.city_message.emit("Bu arazi zaten yol ağına bağlı.", "info")
        return true
    var road_cost: int = 650 + maxi(0, lanes - 2) * 300
    if not state.spend_lucb(road_cost):
        state.city_message.emit("Yol bağlantısı için yeterli LuCB yok.", "warning")
        return false
    var production := state.get_parent().get_node_or_null("ProductionSystem")
    if production and not production.remove_item("cement", 20 + lanes * 5):
        state.add_lucb(road_cost)
        state.city_message.emit("Yol bağlantısı için yeterli çimento yok.", "warning")
        return false
    var roads := state.get_parent().get_node_or_null("RoadNetworkSystem")
    if roads and roads.has_method("connect_terrain_parcel"):
        roads.connect_terrain_parcel(parcel_id, parcel.center, lanes)
    parcel.road_connected = true
    parcels[parcel_id] = parcel
    state.city_message.emit("🛣️ %s yol ağına bağlandı.", "success")
    return true

func get_building_slots(parcel_id: String) -> int:
    if not parcels.has(parcel_id):
        return 0
    return int(parcels[parcel_id].get("building_slots", 0)) - int(parcels[parcel_id].get("used_slots", 0))

func get_building_cost(building_type: String) -> Dictionary:
    return building_costs.get(building_type, {})

func place_building(parcel_id: String, building_type: String) -> bool:
    if not _can_modify_city():
        state.city_message.emit("🏙️ Arkadaş şehrini ziyaret ederken şehir değişikliği yapılamaz.", "warning")
        return false
    if not parcels.has(parcel_id):
        return false
    var parcel: Dictionary = parcels[parcel_id]
    if not parcel.buildable or not parcel.road_connected:
        state.city_message.emit("🏗️ Önce araziyi düzenleyip yol bağlantısını tamamlamalısın.", "warning")
        return false
    var free_slots := get_building_slots(parcel_id)
    if free_slots <= 0:
        state.city_message.emit("Bu arazide boş yapı alanı kalmadı.", "warning")
        return false
    if not building_costs.has(building_type):
        return false
    var spec: Dictionary = building_costs[building_type]
    if not state.spend_lucb(int(spec.lucb)):
        state.city_message.emit("🏗️ Bu bina için yeterli LuCB yok.", "warning")
        return false
    var production := state.get_parent().get_node_or_null("ProductionSystem")
    var materials: Dictionary = spec.get("materials", {})
    for item in materials.keys():
        if production == null or not production.has_items(str(item), int(materials[item])):
            state.add_lucb(int(spec.lucb))
            state.city_message.emit("🏭 Yeterli %s malzemesi yok." % str(item), "warning")
            return false
    for item in materials.keys():
        production.remove_item(str(item), int(materials[item]))
    var index := int(parcel.get("used_slots", 0))
    var building_id := "%s_%s_%02d" % [parcel_id, building_type, index + 1]
    var ok := false
    if world and world.has_method("place_terrain_building"):
        ok = bool(world.place_terrain_building(parcel_id, building_type, building_id, index))
    if not ok:
        state.add_lucb(int(spec.lucb))
        for item in materials.keys():
            production.add_item(str(item), int(materials[item]))
        return false
    parcel.used_slots = index + 1
    var placed: Array = parcel.get("placed_buildings", [])
    placed.append(building_id)
    parcel.placed_buildings = placed
    parcels[parcel_id] = parcel
    if state.has_method("recalculate_expansion_impact"):
        state.recalculate_expansion_impact()
    building_placed.emit(parcel_id, building_type, building_id)
    state.city_message.emit("🏗️ %s inşa edildi. Boş alan: %d" % [building_type.capitalize(), get_building_slots(parcel_id)], "success")
    return true
