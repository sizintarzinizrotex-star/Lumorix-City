class_name LumorixCitizenLifeSystem
extends Node

signal citizen_event(message: String, severity: String)

var state: Node
var timer := 0.0
var protest_level := 0.0
var move_away_pressure := 0.0
var service_complaint_clock := 0.0
var spatial_service_event_clock := 0.0
var routine_clock := 0.0
var routine_index := 0

func initialize(game_state: Node) -> void:
    state = game_state

func _process(delta: float) -> void:
    service_complaint_clock = max(0.0, service_complaint_clock - delta)
    spatial_service_event_clock = max(0.0, spatial_service_event_clock - delta)
    if state == null:
        return
    timer += delta
    routine_clock += delta
    if routine_clock >= 12.0:
        routine_clock = 0.0
        _advance_daily_routine()
    if timer < 10.0:
        return
    timer = 0.0
    _simulate_life()

func _advance_daily_routine() -> void:
    # Günlük yaşam döngüsü: Ev → İş → Alışveriş → Ulaşım/Eğlence → Ev.
    var phases := [
        ["ev", "Ev"],
        ["is", "İş"],
        ["alisveris", "Alışveriş"],
        ["ulasim", "Ulaşım / Eğlence"],
        ["ev", "Ev"]
    ]
    routine_index = (routine_index + 1) % phases.size()
    state.citizen_routine_phase = str(phases[routine_index][0])
    state.citizen_routine_activity = str(phases[routine_index][1])
    state.citizen_routine_tick += 1
    _assign_real_city_destinations(state.citizen_routine_phase)

    var population_factor: float = clampf(float(state.population) / 1250.0, 0.5, 3.0)
    var traffic_penalty: float = clampf(float(state.traffic) / 100.0, 0.0, 1.0)
    var coastal_bonus: float = clampf(float(state.coastal_activity_count) / 20.0, 0.0, 1.0)
    var park_bonus: float = clampf(float(state.park_activity_count) / 18.0, 0.0, 1.0)
    var outdoor_bonus: float = (coastal_bonus * 0.15) + (park_bonus * 0.12)
    var mobility: float = population_factor * (0.65 + traffic_penalty * 0.35) + outdoor_bonus
    if state.citizen_routine_phase == "is":
        state.citizen_economic_activity = clamp(float(state.jobs) / max(float(state.population), 1.0), 0.0, 1.5)
    elif state.citizen_routine_phase == "alisveris":
        state.citizen_economic_activity = clamp(0.45 + float(state.happiness) / 180.0, 0.0, 1.5)
    else:
        state.citizen_economic_activity = max(0.15, float(state.happiness) / 100.0)
    state.citizen_mobility_demand = mobility
    if park_bonus > 0.0 or coastal_bonus > 0.0:
        var outdoor_happiness: float = (park_bonus * 0.6 + coastal_bonus * 0.8)
        state.happiness = clamp(float(state.happiness) + outdoor_happiness * 0.08, 0.0, 100.0)
    if coastal_bonus > 0.0 and state.citizen_routine_phase in ["ulasim", "alisveris"]:
        state.city_message.emit("🌊 Sahil canlı: yürüyüş, koşu, bisiklet ve balıkçılık hareketliliği sürüyor.", "info")
    state.city_message.emit("👥 Vatandaş hareketliliği: %s" % state.citizen_routine_activity, "info")


func _assign_real_city_destinations(phase: String) -> void:
    var buildings: Array = state.buildings
    if buildings.is_empty():
        return
    var homes: Array[Dictionary] = []
    var workplaces: Array[Dictionary] = []
    var leisure: Array[Dictionary] = []
    for building in buildings:
        if not building is Dictionary:
            continue
        var b := building as Dictionary
        var addr: Dictionary = b.get("address", {})
        if addr.is_empty():
            continue
        match str(b.get("type", "")):
            "residential": homes.append(b)
            "factory", "commercial", "public": workplaces.append(b)
        if bool(b.get("interactive", false)) or str(b.get("type", "")) in ["commercial", "stadium", "mall"]:
            leisure.append(b)
    if homes.is_empty():
        for b in buildings:
            if b is Dictionary and not (b as Dictionary).get("address", {}).is_empty():
                homes.append(b)
    var home: Dictionary = homes[state.citizen_routine_tick % homes.size()] if not homes.is_empty() else {}
    var work: Dictionary = workplaces[state.citizen_routine_tick % workplaces.size()] if not workplaces.is_empty() else home
    var target: Dictionary = home
    var trip_type := "ev"
    if phase == "is":
        target = work
        trip_type = "is"
    elif phase == "alisveris":
        if not leisure.is_empty():
            target = leisure[state.citizen_routine_tick % leisure.size()]
        else:
            target = work
        trip_type = "sosyal"
    elif phase == "ulasim":
        var parks: Array = state.park_destinations if state.park_destinations is Array else []
        if not parks.is_empty():
            target = parks[state.citizen_routine_tick % parks.size()]
            trip_type = "park / spor"
        elif not leisure.is_empty():
            target = leisure[state.citizen_routine_tick % leisure.size()]
            trip_type = "sosyal"
        else:
            target = work
            trip_type = "ulasim"
    state.citizen_home_address = str((home.get("address", {}) as Dictionary).get("full", ""))
    state.citizen_work_address = str((work.get("address", {}) as Dictionary).get("full", ""))
    var target_address = target.get("address", "")
    if target_address is Dictionary:
        target_address = (target_address as Dictionary).get("full", "")
    state.citizen_destination_address = str(target_address)
    state.citizen_destination_type = trip_type
    state.citizen_active_trip = "%s → %s" % [state.citizen_home_address, state.citizen_destination_address]
    var mode := _choose_transport_mode(home, target, phase)
    state.citizen_transport_mode = mode
    state.citizen_trip_time = _estimate_trip_time(home, target, mode)
    var icon: String = str({"yaya":"🚶", "bisiklet":"🚲", "arac":"🚗", "otobus":"🚌", "metro":"🚇", "tren":"🚆"}.get(mode, "🚶"))
    state.city_message.emit("%s Vatandaş rotası: %s | %s | %.0f dk" % [icon, state.citizen_active_trip, mode, state.citizen_trip_time], "info")

func _choose_transport_mode(home: Dictionary, target: Dictionary, phase: String) -> String:
    if phase == "ev":
        return "yaya"
    var a: Vector3 = home.get("position", Vector3.ZERO)
    var b: Vector3 = target.get("position", a)
    var distance := a.distance_to(b)
    if phase == "ulasim" and distance <= 45.0:
        return "bisiklet"
    if distance <= 32.0:
        return "yaya"
    var metro_access := _nearest_transit_distance(home, target, ["metro", "premium_metro_station"])
    var train_access := _nearest_transit_distance(home, target, ["train_station", "premium_train_station"])
    var transit_pressure := float(state.transit_service_pressure)
    var station_load := float(state.transit_station_load)
    if float(state.metro_passenger_count) > 0.0 and distance > 70.0 and metro_access < distance * 0.55:
        if station_load < 1.15 or transit_pressure < 0.8:
            return "metro"
    if float(state.train_passenger_count) > 0.0 and distance > 110.0 and train_access < distance * 0.60:
        if station_load < 1.25 or transit_pressure < 0.65:
            return "tren"
    if float(state.bus_passenger_count) > 0.0 and distance > 45.0:
        return "otobus"
    return "arac"


func _nearest_transit_distance(home: Dictionary, target: Dictionary, types: Array[String]) -> float:
    var a: Vector3 = home.get("position", Vector3.ZERO)
    var b: Vector3 = target.get("position", a)
    var best := 999999.0
    for building in state.buildings:
        if not (building is Dictionary):
            continue
        if not types.has(str(building.get("type", ""))):
            continue
        var pos: Vector3 = building.get("position", Vector3.ZERO)
        var access := a.distance_to(pos) + pos.distance_to(b)
        best = min(best, access)
    return best

func _estimate_trip_time(home: Dictionary, target: Dictionary, mode: String) -> float:
    var a: Vector3 = home.get("position", Vector3.ZERO)
    var b: Vector3 = target.get("position", a)
    var distance := a.distance_to(b)
    var speed := 4.5
    match mode:
        "bisiklet": speed = 8.0
        "arac": speed = max(5.0, 15.0 - float(state.traffic) * 0.08)
        "otobus": speed = max(5.5, 13.0 - float(state.traffic) * 0.05)
        "metro": speed = 28.0
        "tren": speed = 36.0
    return max(1.0, distance / speed * 3.0)

func _emit_service_specific_complaint(scores: Dictionary) -> void:
    if service_complaint_clock > 0.0 or state == null:
        return
    var messages := {
        "electricity": "⚡ Vatandaşlar: Elektrik kesintileri yaşam kalitemizi düşürüyor.",
        "water": "💧 Vatandaşlar: Su hizmeti yetersiz, basınç ve erişim sorunu yaşıyoruz.",
        "sewage": "🚰 Vatandaşlar: Kanalizasyon hizmeti yetersiz, çevre sorunları oluşuyor.",
        "waste": "🗑️ Vatandaşlar: Çöp toplama yetersiz, sokakların temizlenmesi gerekiyor.",
        "police": "👮 Vatandaşlar: Kendimizi güvende hissetmiyoruz, güvenlik hizmeti artırılmalı.",
        "fire": "🚒 Vatandaşlar: İtfaiye erişimi yetersiz, müdahale süresi endişe veriyor.",
        "health": "🏥 Vatandaşlar: Sağlık hizmetlerine erişim yetersiz.",
        "education": "🏫 Vatandaşlar: Eğitim kapasitesi yetersiz, daha fazla okul gerekiyor.",
        "parks": "🌳 Vatandaşlar: Yakınımızda yeterli park ve yeşil alan bulunmuyor."
    }
    var worst_id: String = ""
    var worst_score := 101.0
    for service_id in messages.keys():
        var score := float(scores.get(service_id, 100.0))
        var spatial := float(state.service_spatial_scores.get(service_id, score))
        var effective: float = minf(score, spatial)
        if effective < worst_score:
            worst_score = effective
            worst_id = str(service_id)
    if worst_id == "" or worst_score >= 70.0:
        return
    state.complaints.append({
        "type": worst_id,
        "text": str(messages[worst_id]),
        "score": worst_score,
        "day": int(state.day_time)
    })
    if state.complaints.size() > 30:
        state.complaints.pop_front()
    state.city_message.emit(str(messages[worst_id]), "warning" if worst_score >= 45.0 else "danger")
    service_complaint_clock = 18.0

func _emit_spatial_service_event() -> void:
    if state == null or spatial_service_event_clock > 0.0:
        return
    var messages := {
        "police": ["👮 Güvenlik devriyesi uzak: kapsama dışındaki bölgede güvenlik riski arttı.", "warning"],
        "fire": ["🚒 İtfaiye erişimi zayıf: uzak bölgede müdahale süresi riski oluştu.", "warning"],
        "health": ["🏥 Sağlık hizmeti uzakta: bazı vatandaşların sağlık erişimi zorlaşıyor.", "warning"],
        "waste": ["🗑️ Çöp hizmeti kapsama dışında: uzak bölgede atık birikme riski oluştu.", "warning"],
        "water": ["💧 Su hizmeti kapsama dışında: bazı binalarda erişim sorunu oluştu.", "danger"],
        "sewage": ["🚰 Kanalizasyon kapsaması yetersiz: uzak bölgede çevre riski oluştu.", "danger"],
        "electricity": ["⚡ Elektrik hizmeti kapsama dışında: bazı binalarda kesinti riski var.", "danger"],
        "education": ["🏫 Eğitim hizmeti uzak: bazı konutların okula erişimi zayıf.", "warning"],
        "parks": ["🌳 Yeşil alan kapsaması zayıf: bazı mahallelerde rekreasyon erişimi düşük.", "info"]
    }
    var worst_id: String = ""
    var worst_score := 101.0
    var worst_building := ""
    for service_id in messages.keys():
        var score := float(state.service_spatial_scores.get(service_id, 100.0))
        var uncovered: Array = state.service_uncovered_buildings.get(service_id, [])
        if uncovered.is_empty() or score >= worst_score:
            continue
        worst_score = score
        worst_id = str(service_id)
        worst_building = str(uncovered[0])
    if worst_id == "":
        return
    var payload: Array = messages[worst_id]
    state.city_message.emit("%s Bölge: %s" % [str(payload[0]), worst_building], str(payload[1]))
    spatial_service_event_clock = 30.0


func _simulate_life() -> void:
    var score := float(state.happiness)
    var scores: Dictionary = state.service_scores if state.service_scores is Dictionary else {}
    var weak_services: Array[String] = []
    var effective_scores: Dictionary = {}
    for service_id in scores.keys():
        var capacity_score := float(scores[service_id])
        var spatial_score := float(state.service_spatial_scores.get(service_id, capacity_score))
        var effective: float = minf(capacity_score, spatial_score)
        effective_scores[service_id] = effective
        if effective < 70.0:
            weak_services.append(str(service_id))

    _emit_service_specific_complaint(scores)
    _emit_spatial_service_event()

    var critical_count := 0
    for service_id in effective_scores.keys():
        if float(effective_scores[service_id]) < 45.0:
            critical_count += 1

    # Hizmet açıkları vatandaş davranışına doğrudan yansır.
    if critical_count >= 2 or score < 25.0:
        protest_level = min(100.0, protest_level + 10.0)
        move_away_pressure = min(100.0, move_away_pressure + 7.0)
        if state.has_method("register_protest") and int(state.protest_count) % 3 == 0:
            state.register_protest("birden fazla temel belediye hizmeti yetersiz")
        citizen_event.emit("📢 Vatandaşlar temel hizmetlerin yetersizliği nedeniyle protesto ediyor.", "danger")
    elif critical_count == 1 or score < 45.0:
        protest_level = min(100.0, protest_level + 4.0)
        move_away_pressure = min(100.0, move_away_pressure + 3.0)
        citizen_event.emit("⚠️ Vatandaş şikâyetleri arttı: %s hizmetlerinde kapasite sorunu var." % ", ".join(weak_services), "warning")
    elif score >= 85.0 and weak_services.is_empty():
        protest_level = max(0.0, protest_level - 8.0)
        move_away_pressure = max(0.0, move_away_pressure - 7.0)
        citizen_event.emit("😊 Vatandaşlar şehir yaşamından memnun; hizmetler dengeli.", "success")
    else:
        protest_level = max(0.0, protest_level - 2.0)
        move_away_pressure = max(0.0, move_away_pressure - 2.0)

    # Riskler hizmet skorlarından türetilir ve CityEvents tarafından kullanılır.
    var police_score := float(effective_scores.get("police", 100.0))
    var fire_score := float(effective_scores.get("fire", 100.0))
    var health_score := float(effective_scores.get("health", 100.0))
    var waste_score := float(effective_scores.get("waste", 100.0))
    var traffic_score := float(state.traffic)
    state.set_city_risk("crime", 100.0 - police_score)
    state.set_city_risk("fire", 100.0 - fire_score)
    state.set_city_risk("disease", 100.0 - health_score)
    state.set_city_risk("waste", 100.0 - waste_score)
    state.set_city_risk("traffic", 100.0 - float(state.traffic))

    if move_away_pressure >= 70.0:
        var leaving: int = maxi(1, int(state.population * 0.01))
        if state.has_method("apply_citizen_departure"):
            state.apply_citizen_departure(leaving, "uzun süren hizmet ve yaşam kalitesi sorunları")
        move_away_pressure = 45.0
    elif move_away_pressure >= 45.0:
        citizen_event.emit("🏠 Bazı vatandaşlar şehirden taşınmayı düşünüyor.", "warning")

    if score >= 80.0 and critical_count == 0:
        state.service_recovery_bonus = min(5.0, float(state.service_recovery_bonus) + 0.5)
    else:
        state.service_recovery_bonus = max(0.0, float(state.service_recovery_bonus) - 0.5)

