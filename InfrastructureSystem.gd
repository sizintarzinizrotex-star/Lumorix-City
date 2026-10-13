class_name LumorixInfrastructureSystem
extends Node

signal service_status_changed(service_id: String, capacity: int, demand: int, score: float)
signal service_problem(service_id: String, level: int, shortage: float, outage: bool)

const LEVEL_DATA := {
    "electricity": {"capacity": 500, "step": 250, "maintenance": 40},
    "water": {"capacity": 500, "step": 250, "maintenance": 35},
    "sewage": {"capacity": 500, "step": 250, "maintenance": 35},
    "waste": {"capacity": 400, "step": 220, "maintenance": 30},
    "police": {"capacity": 400, "step": 200, "maintenance": 45},
    "fire": {"capacity": 400, "step": 200, "maintenance": 45},
    "health": {"capacity": 350, "step": 180, "maintenance": 50},
    "education": {"capacity": 350, "step": 180, "maintenance": 45},
    "parks": {"capacity": 300, "step": 150, "maintenance": 15}
}

var state: Node
var last_scores: Dictionary = {}
var maintenance_per_tick: int = 0

const SERVICE_RADII := {
    "electricity": [70, 85, 105, 130, 160],
    "water": [60, 80, 100, 125, 150],
    "sewage": [60, 80, 100, 125, 150],
    "waste": [55, 75, 95, 120, 145],
    "police": [45, 60, 80, 105, 135],
    "fire": [45, 60, 80, 105, 135],
    "health": [50, 65, 85, 110, 140],
    "education": [50, 65, 85, 110, 140],
    "parks": [35, 50, 70, 95, 120]
}

const SERVICE_LEVEL_NAMES := {
    "electricity": ["Küçük Santral", "Orta Santral", "Büyük Enerji Tesisi", "Güneş + Rüzgâr Kompleksi", "Mega Enerji Merkezi"],
    "water": ["Su Kuyusu", "Su Arıtma Tesisi", "Büyük Su Tesisi", "İleri Arıtma Tesisi", "Mega Su Kompleksi"],
    "sewage": ["Küçük Kanalizasyon", "Orta Arıtma", "Büyük Atık Su Tesisi", "Biyolojik Arıtma", "Mega Atık Su Merkezi"],
    "waste": ["Çöp Toplama Merkezi", "Aktarma İstasyonu", "Düzenli Depolama", "Geri Dönüşüm + Enerji", "Entegre Atık Kompleksi"],
    "police": ["Küçük Polis Merkezi", "İlçe Polis Merkezi", "Merkez Emniyet", "Büyük Güvenlik Merkezi", "Super Polis Merkezi"],
    "fire": ["Küçük İtfaiye", "İtfaiye İstasyonu", "Merkez İtfaiye", "Bölgesel İtfaiye", "Super İtfaiye Merkezi"],
    "health": ["Sağlık Ocağı", "Hastane", "Büyük Hastane", "Bölgesel Sağlık Merkezi", "Özel Sağlık Kompleksi"],
    "education": ["Küçük Okul", "Okul Kampüsü", "Büyük Eğitim Merkezi", "Üniversite Kampüsü", "Mega Eğitim Kompleksi"],
    "parks": ["Mahalle Parkı", "Semt Parkı", "Büyük Kent Parkı", "Bölgesel Yeşil Alan", "Mega Şehir Parkı"]
}

func get_service_detail(service_id: String) -> Dictionary:
    var status := get_service_status(service_id)
    var level := int(status.get("level", 0))
    var names: Array = SERVICE_LEVEL_NAMES.get(service_id, [])
    var name := "Kurulu değil"
    if level > 0 and level <= names.size():
        name = str(names[level - 1])
    var cfg: Dictionary = LEVEL_DATA.get(service_id, {})
    var radii: Array = SERVICE_RADII.get(service_id, [])
    var coverage_radius := 0
    if level > 0 and level <= radii.size():
        coverage_radius = int(radii[level - 1])
    var buildings := 0
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) == service_id:
            buildings += 1
    var coverage := float(status.get("score", 0.0))
    return {
        "id": service_id,
        "level": level,
        "name": name,
        "capacity": int(status.get("capacity", 0)),
        "demand": int(status.get("demand", 0)),
        "score": coverage,
        "shortage": float(status.get("shortage", 0.0)),
        "outage": bool(status.get("outage", false)),
        "maintenance": get_service_maintenance(service_id),
        "buildings": buildings,
        "coverage_radius": coverage_radius,
        "base_capacity": int(cfg.get("capacity", 0)),
        "capacity_step": int(cfg.get("step", 0))
    }

func get_service_maintenance(service_id: String) -> int:
    var cfg: Dictionary = LEVEL_DATA.get(service_id, {})
    var total: float = 0
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) == service_id:
            total += int(cfg.get("maintenance", 0)) + max(0, int(b.get("lwl", 1)) - 1) * 8
    return total

func initialize(game_state: Node) -> void:
    state = game_state

func get_service_level(service_id: String) -> int:
    var highest := 0
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) != service_id:
            continue
        highest = max(highest, clamp(int(b.get("lwl", 1)), 1, 5))
    return highest

func get_service_status(service_id: String) -> Dictionary:
    var capacity: int = get_service_capacity(service_id)
    var demand := int(state.service_demand.get(service_id, 0)) if state != null else 0
    var score := get_service_score(service_id, demand)
    var level := get_service_level(service_id)
    var shortage: float = clampf(1.0 - float(capacity) / float(maxi(1, demand)), 0.0, 1.0)
    return {"level": level, "capacity": capacity, "demand": demand, "score": score, "shortage": shortage, "outage": shortage >= 0.35}

func get_service_capacity(service_id: String) -> int:
    var total: float = 0
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) != service_id:
            continue
        var level: int = clampi(int(b.get("lwl", 1)), 1, 5)
        var cfg: Dictionary = LEVEL_DATA.get(service_id, {})
        total += int(cfg.get("capacity", 0)) + (level - 1) * int(cfg.get("step", 0))
    return total

func get_service_score(service_id: String, demand: int) -> float:
    if demand <= 0:
        return 100.0
    return clamp(float(get_service_capacity(service_id)) / float(demand) * 100.0, 0.0, 100.0)

func _get_building_position(building: Dictionary) -> Vector3:
    var pos = building.get("position", Vector3.ZERO)
    if pos is Vector3:
        return pos
    if pos is Dictionary:
        return Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
    return Vector3.ZERO

func _calculate_spatial_coverage(service_id: String, level: int, radius: float) -> Dictionary:
    var covered := 0
    var total: float = 0
    var weighted := 0.0
    var uncovered: Array[String] = []
    if state == null or level <= 0 or radius <= 0.0:
        return {"covered":0, "total":0, "score":0.0, "uncovered":uncovered}
    var service_buildings: Array[Dictionary] = []
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) == service_id:
            service_buildings.append(b)
    for b in state.buildings:
        var btype := str(b.get("type", ""))
        if btype in ["road", "bridge", "park_marker", "terrain"]:
            continue
        total += 1
        var pos: Vector3 = _get_building_position(b)
        var nearest: float = INF
        for service_building in service_buildings:
            nearest = min(nearest, pos.distance_to(_get_building_position(service_building)))
        var ratio: float = 0.0 if nearest == INF else clampf(1.0 - nearest / radius, 0.0, 1.0)
        weighted += ratio
        if nearest <= radius:
            covered += 1
        else:
            var label := str(b.get("name", b.get("id", btype)))
            uncovered.append(label)
    var score := 0.0 if total <= 0 else weighted / float(total) * 100.0
    return {"covered":covered, "total":total, "score":score, "uncovered":uncovered}

func get_service_coverage_at(position: Vector3, service_id: String) -> float:
    if state == null:
        return 0.0
    var level := get_service_level(service_id)
    var radii: Array = SERVICE_RADII.get(service_id, [])
    if level <= 0 or level > radii.size():
        return 0.0
    var radius: float = float(radii[level - 1])
    var nearest: float = INF
    for b in state.buildings:
        if str(b.get("service", b.get("type", ""))) != service_id:
            continue
        nearest = min(nearest, position.distance_to(_get_building_position(b)))
    if nearest == INF:
        return 0.0
    return clamp(1.0 - nearest / radius, 0.0, 1.0) * 100.0

func tick() -> void:
    if state == null:
        return
    var pop: int = maxi(1, int(state.population))
    var demands: Dictionary = {
        "electricity": int(pop * 1.0), "water": int(pop * 0.95), "sewage": int(pop * 0.9),
        "waste": int(pop * 0.7), "police": int(pop * 0.75), "fire": int(pop * 0.65),
        "health": int(pop * 0.8), "education": int(pop * 0.75), "parks": int(pop * 0.6)
    }
    maintenance_per_tick = 0
    state.service_capacity = {}
    state.service_demand = {}
    state.service_scores = {}
    state.service_levels = {}
    state.service_shortages = {}
    state.service_outages = {}
    state.service_coverage = {}
    state.service_coverage_buildings = {}
    state.service_uncovered_buildings = {}
    state.service_spatial_scores = {}
    var outage_count := 0
    for id in demands.keys():
        var capacity: int = get_service_capacity(id)
        var demand := int(demands[id])
        var score := get_service_score(id, demand)
        var level := get_service_level(id)
        var shortage: float = clampf(1.0 - float(capacity) / float(maxi(1, demand)), 0.0, 1.0)
        var outage: bool = shortage >= 0.35
        last_scores[id] = score
        maintenance_per_tick += get_service_maintenance(id)
        state.service_capacity[id] = capacity
        state.service_demand[id] = demand
        state.service_scores[id] = score
        state.service_levels[id] = level
        state.service_shortages[id] = shortage
        var radii: Array = SERVICE_RADII.get(id, [])
        var coverage_radius := 0
        if level > 0 and level <= radii.size():
            coverage_radius = int(radii[level - 1])
        state.service_coverage[id] = coverage_radius
        var spatial := _calculate_spatial_coverage(id, level, float(coverage_radius))
        state.service_coverage_buildings[id] = int(spatial.get("covered", 0))
        state.service_uncovered_buildings[id] = spatial.get("uncovered", [])
        state.service_spatial_scores[id] = float(spatial.get("score", 0.0))
        # Mekânsal kapsama da kapasite açığı kadar kritik kabul edilir.
        var spatial_shortage: float = clampf(1.0 - float(spatial.get("score", 0.0)) / 100.0, 0.0, 1.0)
        var spatial_outage: bool = spatial_shortage >= 0.55 and level > 0
        state.service_outages[id] = outage or spatial_outage
        if outage:
            outage_count += 1
            service_problem.emit(id, level, shortage, true)
        elif shortage > 0.0:
            service_problem.emit(id, level, shortage, false)
        service_status_changed.emit(id, capacity, demand, score)
    state.municipal_maintenance = maintenance_per_tick
    state.health = last_scores.get("health", 0.0)
    state.education = last_scores.get("education", 0.0)
    state.safety = min(last_scores.get("police", 0.0), last_scores.get("fire", 0.0))
    state.environment = clamp(last_scores.get("waste", 0.0) * 0.55 + last_scores.get("parks", 0.0) * 0.45, 0.0, 100.0)
    if outage_count > 0:
        state.happiness = clamp(state.happiness - min(2.0, outage_count * 0.35), 0.0, 100.0)
        state.city_message.emit("⚠️ %d belediye hizmetinde kapasite açığı var." % outage_count, "warning")
    state.state_changed.emit()


func get_budget_snapshot() -> Dictionary:
    return {
        "maintenance": maintenance_per_tick,
        "service_capacity": state.service_capacity if state != null else {},
        "service_demand": state.service_demand if state != null else {},
        "service_scores": last_scores.duplicate(true)
    }

func get_weak_services() -> Array[String]:
    var result: Array[String] = []
    for id in last_scores.keys():
        if float(last_scores[id]) < 70.0:
            result.append(str(id))
    return result
