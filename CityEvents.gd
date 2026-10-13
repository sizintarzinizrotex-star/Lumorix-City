class_name LumorixCityEvents
extends Node

var state: Node
var rng := RandomNumberGenerator.new()
var cooldown := 35.0
var civic_cooldown := 95.0

func initialize(game_state: Node) -> void:
    state = game_state
    rng.seed = 99117

func _process(delta: float) -> void:
    if state == null:
        return
    cooldown -= delta
    civic_cooldown -= delta
    if civic_cooldown <= 0.0:
        civic_cooldown = rng.randf_range(120.0, 190.0)
        _try_civic_event()
    if cooldown > 0.0:
        return
    cooldown = rng.randf_range(45.0, 90.0)
    _try_event()


func _try_civic_event() -> void:
    var has_rally := bool(state.event_area_status.get("rally", false))
    var has_concert := bool(state.event_area_status.get("concert", false))
    var roll := rng.randi_range(0, 99)
    if has_rally and roll < 55:
        var speeches := [
            "🎤 Başkan halka sesleniyor: Bu şehri sizinle yeniden kuracağız! Oylarınızı ve desteğinizi bekliyorum.",
            "🗣️ Başkan: Lumorix City'nin geleceğini birlikte inşa edeceğiz. Her mahalle bizim için değerli.",
            "🏙️ Başkan: Daha güvenli, daha yeşil ve daha güçlü bir Lumorix için çalışıyoruz!"
        ]
        var speech: String = speeches[rng.randi_range(0, speeches.size() - 1)]
        state.last_president_speech = speech
        state.president_speech_count += 1
        state.city_message.emit(speech, "info")
    elif has_concert:
        state.city_message.emit("🎵 Lumorix Konser Alanı: Sahne hazırlıkları başladı, vatandaşlar etkinlik alanına geliyor.", "success")
        state.happiness = clamp(state.happiness + 0.8, 0.0, 100.0)
    state.state_changed.emit()

func _try_event() -> void:
    var risks: Dictionary = state.active_city_risks if state.active_city_risks is Dictionary else {}
    var crime := float(risks.get("crime", 0.0))
    var fire := float(risks.get("fire", 0.0))
    var disease := float(risks.get("disease", 0.0))
    var waste := float(risks.get("waste", 0.0))
    var traffic_risk := float(risks.get("traffic", 0.0))
    var roll := rng.randi_range(0, 99)

    if crime > 55.0 and roll < int(min(70.0, crime)):
        state.city_message.emit("🚨 Hırsızlık dalgası: Polis kapasitesi yetersiz olduğu için ihbarlar arttı.", "danger")
        state.happiness = clamp(state.happiness - 2.0, 0.0, 100.0)
    elif fire > 60.0 and roll < int(min(75.0, fire)):
        state.city_message.emit("🔥 İtfaiye alarmı: Müdahale kapasitesi yetersiz, yangın riski yükseldi.", "danger")
        state.happiness = clamp(state.happiness - 1.5, 0.0, 100.0)
    elif disease > 60.0 and roll < int(min(70.0, disease)):
        state.city_message.emit("🏥 Sağlık alarmı: Hastane kapasitesi yetersiz, hastalık riski arttı.", "danger")
        state.happiness = clamp(state.happiness - 2.0, 0.0, 100.0)
    elif waste > 55.0 and roll < int(min(70.0, waste)):
        state.city_message.emit("🗑️ Çöp birikimi: Atık kapasitesi yetersiz olduğu için çevre şikâyetleri arttı.", "warning")
        state.environment = clamp(state.environment - 2.0, 0.0, 100.0)
    elif traffic_risk > 55.0 and roll < int(min(70.0, traffic_risk)):
        state.city_message.emit("🚗 Trafik kazası: Yoğunluk nedeniyle ulaşım süresi arttı.", "warning")
        state.happiness = clamp(state.happiness - 1.0, 0.0, 100.0)
    elif state.happiness > 75.0 and roll < 55:
        state.city_message.emit("🎉 Şehir etkinliği: Vatandaşlar merkezde keyifli vakit geçiriyor.", "success")
        state.happiness = clamp(state.happiness + 1.0, 0.0, 100.0)
    else:
        state.city_message.emit("🏙️ Şehir yaşamı: Vatandaş hareketliliği normal seviyede.", "info")
    state.state_changed.emit()

