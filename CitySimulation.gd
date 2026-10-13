class_name LumorixCitySimulation
extends Node

signal simulation_message(text: String, severity: String)

var state: Node
var service_tick := 0.0
var citizen_tick := 0.0
var economy_tick := 0.0

func initialize(game_state: Node) -> void:
    state = game_state

func _process(delta: float) -> void:
    if state == null:
        return
    service_tick += delta
    citizen_tick += delta
    if service_tick >= 5.0:
        service_tick = 0.0
        _update_services()
    if citizen_tick >= 8.0:
        citizen_tick = 0.0
        _update_citizens()

func _update_services() -> void:
    var buildings: Array = state.buildings
    var capacity := {"electricity":0, "water":0, "sewage":0, "waste":0, "police":0, "fire":0, "health":0, "education":0, "parks":0}
    for b in buildings:
        if not b is Dictionary:
            continue
        var kind := str(b.get("type", ""))
        var lvl := int(b.get("lwl", 1))
        var service_key := kind
        if kind == "hospital": service_key = "health"
        elif kind == "school" or kind == "education": service_key = "education"
        elif kind == "police": service_key = "police"
        elif kind == "fire": service_key = "fire"
        elif kind == "power": service_key = "electricity"
        elif kind == "water": service_key = "water"
        elif kind == "sewage": service_key = "sewage"
        elif kind == "waste": service_key = "waste"
        if capacity.has(service_key):
            capacity[service_key] += 100 + (lvl - 1) * 75
    var pop: int = maxi(1, int(state.population))
    var infra := get_parent().get_node_or_null("InfrastructureSystem")
    if infra != null:
        infra.tick()
        state.health = float(infra.last_scores.get("health", _service_score(capacity["health"], pop * 1.0, 100.0)))
        state.education = float(infra.last_scores.get("education", _service_score(capacity["education"], pop * 0.9, 100.0)))
        state.safety = min(float(infra.last_scores.get("police", 100.0)), float(infra.last_scores.get("fire", 100.0)))
        var waste := float(infra.last_scores.get("waste", 100.0))
        var sewage := float(infra.last_scores.get("sewage", 100.0))
        var water := float(infra.last_scores.get("water", 100.0))
        var electricity := float(infra.last_scores.get("electricity", 100.0))
        var parks := float(infra.last_scores.get("parks", 100.0))
        state.environment = clamp(waste * 0.35 + sewage * 0.25 + water * 0.15 + parks * 0.25, 0.0, 100.0)
        var utility_score := (water + sewage + electricity) / 3.0
        state.happiness = clamp((state.health + state.education + state.safety + state.environment + state.traffic + utility_score) / 6.0, 0.0, 100.0)
        if utility_score < 55.0:
            simulation_message.emit("⚠️ Elektrik, su veya kanalizasyon kapasitesi nüfusu karşılamıyor.", "warning")
    else:
        state.health = _service_score(capacity["health"], pop * 1.0, 100.0)
        state.education = _service_score(capacity["education"], pop * 0.9, 100.0)
        state.safety = _service_score(capacity["police"], pop * 0.8, 100.0)
        state.environment = clamp(_service_score(capacity["waste"], pop * 0.65, 100.0) * 0.65 + _service_score(capacity["parks"], pop * 0.35, 100.0) * 0.35, 0.0, 100.0)
        state.happiness = clamp((state.health + state.education + state.safety + state.environment + state.traffic) / 5.0, 0.0, 100.0)
    state.state_changed.emit()

func _service_score(capacity: float, demand: float, base: float) -> float:
    if demand <= 0.0:
        return base
    return clamp(capacity / demand * 100.0, 0.0, 100.0)

func _update_citizens() -> void:
    if state.happiness < 20.0:
        simulation_message.emit("🚨 Vatandaşlar ciddi hizmet sorunlarından şikâyet ediyor.", "danger")
    elif state.happiness < 40.0:
        simulation_message.emit("😡 Vatandaş memnuniyeti düşük. Şehirden ayrılma eğilimi oluşuyor.", "warning")
    elif state.happiness < 60.0:
        simulation_message.emit("😐 Vatandaşlardan hizmet kalitesi hakkında şikâyetler geliyor.", "info")
    elif state.happiness >= 85.0:
        simulation_message.emit("😊 Vatandaşlar Lumorix City'deki yaşamdan çok memnun.", "success")

