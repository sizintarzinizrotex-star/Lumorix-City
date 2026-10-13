class_name LumorixCityAddressSystem
extends Node

signal address_changed
var state: Node
var neighborhoods: Array[String] = []
var streets: Array[String] = []
var avenues: Array[String] = []

func initialize(game_state: Node) -> void:
    state = game_state
    if neighborhoods.is_empty():
        neighborhoods = ["Lumorix Merkez", "Gamer Mahallesi", "Güneş Mahallesi"]
    if streets.is_empty():
        streets = ["Lumorix Sokak", "Gamer Sokak", "Pixel Sokak", "Şehir Işığı Sokak"]
    if avenues.is_empty():
        avenues = ["Lumorix Bulvarı", "Gamer Caddesi", "Metropol Caddesi"]
    _sync()

func set_city_name(value: String) -> bool:
    var clean := value.strip_edges()
    if clean.is_empty():
        return false
    if clean.length() > 32:
        clean = clean.substr(0, 32)
    state.city_name = clean
    _sync()
    address_changed.emit()
    state.state_changed.emit()
    return true

func add_neighborhood(name: String) -> bool:
    return _add_unique(neighborhoods, name, "Mahallesi")

func add_street(name: String) -> bool:
    return _add_unique(streets, name, "Sokak")

func add_avenue(name: String) -> bool:
    return _add_unique(avenues, name, "Caddesi")

func get_address_for_position(position: Vector3, building_id: String = "") -> Dictionary:
    if state == null:
        return {"city":"", "neighborhood":"Lumorix Merkez", "street":"Lumorix Sokak", "avenue":"Lumorix Bulvarı", "number":1, "full":""}
    var n: String = neighborhoods[maxi(0, int(round((position.x + 80.0) / 55.0))) % maxi(1, neighborhoods.size())]
    var s: String = streets[maxi(0, int(round((position.z + 80.0) / 45.0))) % maxi(1, streets.size())]
    var a: String = avenues[maxi(0, int(round((position.x + position.z + 160.0) / 90.0))) % maxi(1, avenues.size())]
    var number: int = 1 + (absi(int(round(position.x * 3.0))) + absi(int(round(position.z * 2.0)))) % 199
    var full := "%s, %s No:%d, %s, %s" % [s, n, number, a, state.city_name]
    return {"city":state.city_name, "neighborhood":n, "street":s, "avenue":a, "number":number, "building_id":building_id, "full":full}

func get_address_catalog() -> Dictionary:
    return {"neighborhoods": neighborhoods.duplicate(), "streets": streets.duplicate(), "avenues": avenues.duplicate()}

func export_data() -> Dictionary:
    return {"neighborhoods": neighborhoods, "streets": streets, "avenues": avenues}

func restore_data(data: Dictionary) -> void:
    if data.is_empty():
        _sync()
        return
    neighborhoods = _string_array(data.get("neighborhoods", neighborhoods))
    streets = _string_array(data.get("streets", streets))
    avenues = _string_array(data.get("avenues", avenues))
    if neighborhoods.is_empty(): neighborhoods = ["Lumorix Merkez"]
    if streets.is_empty(): streets = ["Lumorix Sokak"]
    if avenues.is_empty(): avenues = ["Lumorix Bulvarı"]
    _sync()

func _add_unique(target: Array[String], raw: String, suffix: String) -> bool:
    var clean := raw.strip_edges()
    if clean.is_empty():
        return false
    if clean.length() > 40:
        clean = clean.substr(0, 40)
    if not clean.to_lower().ends_with(suffix.to_lower()):
        clean += " " + suffix
    if target.has(clean):
        return false
    target.append(clean)
    _sync()
    address_changed.emit()
    return true

func _string_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for item in value:
            result.append(str(item))
    return result

func _sync() -> void:
    if state == null:
        return
    state.city_neighborhoods = neighborhoods.duplicate()
    state.city_streets = streets.duplicate()
    state.city_avenues = avenues.duplicate()
