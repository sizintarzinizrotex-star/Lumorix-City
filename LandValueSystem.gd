class_name LumorixLandValueSystem
extends Node

signal land_value_updated(average_value: float)

var state: Node
var world: Node
var update_timer := 0.0
var parcel_values: Dictionary = {}

func initialize(game_state: Node, city_world: Node) -> void:
    state = game_state
    world = city_world
    _recalculate()

func _process(delta: float) -> void:
    update_timer += delta
    if update_timer < 5.0:
        return
    update_timer = 0.0
    _recalculate()

func _recalculate() -> void:
    if state == null:
        return
    var center_bonus: float = clampf(float(state.city_development_lwl) * 0.8, 0.0, 20.0)
    var transit_bonus: float = clampf(float(state.metro_passenger_count + state.train_passenger_count + state.bus_passenger_count) / 120.0, 0.0, 15.0)
    var park_bonus := 0.0
    var social_bonus := 0.0
    var factory_penalty := 0.0
    var pollution_penalty: float = clampf((70.0 - float(state.environment)) * 0.35, 0.0, 18.0)
    var traffic_penalty: float = clampf((70.0 - float(state.traffic)) * 0.28, 0.0, 15.0)

    for building in state.buildings:
        match str(building.get("type", "")):
            "park": park_bonus += 2.5
            "commercial": social_bonus += 1.2
            "stadium", "mall": social_bonus += 1.8
            "factory": factory_penalty += 2.0

    var raw: float = 50.0 + center_bonus + transit_bonus + park_bonus + social_bonus - factory_penalty - pollution_penalty - traffic_penalty
    var average: float = clampf(raw, 5.0, 100.0)
    state.land_value_average = average
    state.land_value_factor = clamp(average / 50.0, 0.25, 2.0)
    parcel_values["city_center"] = clamp(average + 12.0, 0.0, 100.0)
    parcel_values["industrial"] = clamp(average - factory_penalty * 2.0, 0.0, 100.0)
    parcel_values["residential"] = clamp(average + park_bonus + transit_bonus * 0.4, 0.0, 100.0)
    land_value_updated.emit(average)

func get_average_value() -> float:
    return float(state.land_value_average) if state else 0.0

func get_parcel_value(parcel_id: String) -> float:
    return float(parcel_values.get(parcel_id, get_average_value()))
