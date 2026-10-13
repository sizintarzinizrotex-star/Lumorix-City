class_name LumorixPhase3CityLifeSystem
extends Node3D

signal city_event_created(event_data)
signal citizen_reaction_changed(reaction_data)
signal city_complaint_created(complaint_data)
signal building_life_changed(building_data)

var world_root: Node3D
var game_state
var city_life_root: Node3D

var active_events: Array = []
var complaints: Array = []
var citizen_reactions: Array = []
var building_activity: Dictionary = {}

var city_morale := 72.0
var public_health := 82.0
var public_safety := 84.0
var education_level := 70.0
var utility_stability := 92.0
var entertainment_level := 65.0

var fire_incidents := 0
var theft_incidents := 0
var medical_incidents := 0
var outage_incidents := 0
var protest_count := 0
var citizens_left := 0

var weather_state := "clear"
var day_state := "day"
var simulation_clock := 0.0
var event_timer := 0.0

func initialize(p_world_root: Node3D, p_game_state) -> void:
    world_root = p_world_root
    game_state = p_game_state
    city_life_root = Node3D.new()
    city_life_root.name = "Phase3CityLife"
    add_child(city_life_root)
    _initialize_building_activity()

func _process(delta: float) -> void:
    simulation_clock += delta
    event_timer += delta
    if event_timer >= 18.0:
        event_timer = 0.0
        _simulate_city_life_tick()

func _initialize_building_activity() -> void:
    building_activity.clear()
    var buildings = game_state.buildings if game_state != null and "buildings" in game_state else []
    if typeof(buildings) != TYPE_ARRAY:
        return

    for index in range(buildings.size()):
        var building = buildings[index]
        if typeof(building) != TYPE_DICTIONARY:
            continue
        building_activity[str(index)] = {
            "building_index": index,
            "type": str(building["type"]) if building.has("type") else "building",
            "activity": 50.0,
            "visitors": 0,
            "workers": 0,
            "patients": 0,
            "students": 0,
            "customers": 0,
            "open": true
        }

func _simulate_city_life_tick() -> void:
    _update_day_night()
    _update_weather()
    _update_building_activity()
    _update_city_metrics()
    _maybe_create_incident()
    _evaluate_citizen_reactions()
    _evaluate_population_movement()

func _update_day_night() -> void:
    var phase := fmod(simulation_clock, 120.0)
    day_state = "day" if phase >= 30.0 and phase < 90.0 else "night"

func _update_weather() -> void:
    if weather_state == "storm":
        utility_stability = max(25.0, utility_stability - 0.3)
        public_safety = max(25.0, public_safety - 0.2)
    elif weather_state == "rain":
        utility_stability = max(40.0, utility_stability - 0.1)
    elif weather_state == "snow":
        public_safety = max(30.0, public_safety - 0.2)
    else:
        utility_stability = min(100.0, utility_stability + 0.1)

func _update_building_activity() -> void:
    for key in building_activity:
        var data: Dictionary = building_activity[key]
        var activity := float(data.get("activity", 50.0))
        activity += 1.0 if day_state == "day" else -0.5
        data["activity"] = clampf(activity, 0.0, 100.0)
        data["open"] = true
        building_activity[key] = data
        building_life_changed.emit(data)

func _update_city_metrics() -> void:
    city_morale = clampf(city_morale + 0.1 - float(active_events.size()) * 0.03, 0.0, 100.0)
    public_safety = clampf(public_safety + 0.05, 0.0, 100.0)
    public_health = clampf(public_health + 0.05, 0.0, 100.0)

func _maybe_create_incident() -> void:
    var roll := randi_range(0, 99)
    if roll < 7:
        _create_event("fire", "Yangın ihbarı", 3)
    elif roll < 13:
        _create_event("theft", "Hırsızlık ihbarı", 2)
    elif roll < 19:
        _create_event("medical", "Tıbbi acil durum", 2)
    elif roll < 23:
        _create_event("outage", "Elektrik/su kesintisi", 3)
    elif roll < 26 and city_morale < 55.0:
        _create_event("protest", "Vatandaş protestosu", 4)

func _create_event(event_type: String, title: String, severity: int) -> void:
    var event_data := {
        "id": "CITY_%d_%d" % [Time.get_ticks_msec(), active_events.size()],
        "type": event_type,
        "title": title,
        "severity": severity,
        "resolved": false,
        "status": "active"
    }
    active_events.append(event_data)

    match event_type:
        "fire":
            fire_incidents += 1
            public_safety -= severity * 1.5
        "theft":
            theft_incidents += 1
            public_safety -= severity
        "medical":
            medical_incidents += 1
            public_health -= severity
        "outage":
            outage_incidents += 1
            utility_stability -= severity * 2.0
        "protest":
            protest_count += 1
            city_morale -= severity * 2.0

    city_event_created.emit(event_data)

func resolve_event(event_id: String) -> bool:
    for event in active_events:
        if str(event.get("id", "")) == event_id and not bool(event.get("resolved", false)):
            event["resolved"] = true
            event["status"] = "resolved"
            return true
    return false

func add_complaint(category: String, message: String, severity: int = 1) -> void:
    complaints.append({
        "id": "CMP_%d" % Time.get_ticks_msec(),
        "category": category,
        "message": message,
        "severity": clampi(severity, 1, 5),
        "resolved": false
    })
    city_morale = clampf(city_morale - severity * 0.25, 0.0, 100.0)

func resolve_complaint(complaint_id: String) -> bool:
    for complaint in complaints:
        if str(complaint.get("id", "")) == complaint_id:
            complaint["resolved"] = true
            return true
    return false

func _evaluate_citizen_reactions() -> void:
    var mood := "happy"
    if city_morale < 35.0:
        mood = "angry"
    elif city_morale < 55.0:
        mood = "unhappy"
    elif city_morale < 75.0:
        mood = "neutral"

    var reaction := {
        "mood": mood,
        "morale": city_morale,
        "health": public_health,
        "safety": public_safety,
        "utilities": utility_stability
    }
    citizen_reactions.append(reaction)
    citizen_reaction_changed.emit(reaction)

    if mood == "angry":
        add_complaint("morale", "Vatandaşlar şehir hizmetlerinden memnun değil.", 3)

func _evaluate_population_movement() -> void:
    var pressure := 0.0
    if city_morale < 40.0:
        pressure += 1.5
    if public_safety < 45.0:
        pressure += 1.5
    if public_health < 45.0:
        pressure += 1.0
    if utility_stability < 45.0:
        pressure += 1.5

    if pressure > 3.0 and randi_range(0, 99) < 20:
        citizens_left += 1

func set_weather(new_weather: String) -> void:
    if new_weather in ["clear", "rain", "storm", "snow", "fog"]:
        weather_state = new_weather

func set_day_state(new_state: String) -> void:
    if new_state in ["day", "night"]:
        day_state = new_state

func get_building_activity(building_index: int) -> Dictionary:
    return building_activity.get(str(building_index), {})

func get_active_events() -> Array:
    return active_events

func get_open_complaints() -> Array:
    var result: Array = []
    for complaint in complaints:
        if not bool(complaint.get("resolved", false)):
            result.append(complaint)
    return result

func get_city_status() -> Dictionary:
    return {
        "morale": city_morale,
        "public_health": public_health,
        "public_safety": public_safety,
        "education": education_level,
        "utility_stability": utility_stability,
        "entertainment": entertainment_level,
        "weather": weather_state,
        "day_state": day_state,
        "fire_incidents": fire_incidents,
        "theft_incidents": theft_incidents,
        "medical_incidents": medical_incidents,
        "outage_incidents": outage_incidents,
        "protests": protest_count,
        "citizens_left": citizens_left,
        "active_events": active_events.size(),
        "open_complaints": get_open_complaints().size()
    }
