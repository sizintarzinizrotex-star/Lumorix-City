class_name LumorixWeatherSystem
extends Node

signal weather_changed(weather_name: String, intensity: float)

var state: Node
var current_weather := "clear"
var intensity := 0.0
var timer := 0.0
var cycle_seconds := 90.0
var rng := RandomNumberGenerator.new()

func initialize(game_state: Node) -> void:
    state = game_state
    rng.seed = 92741
    _set_weather("clear", 0.0)

func _process(delta: float) -> void:
    if state == null:
        return
    timer += delta
    if timer >= cycle_seconds:
        timer = 0.0
        var choices := ["clear", "cloudy", "rain", "storm"]
        _set_weather(choices[rng.randi_range(0, choices.size() - 1)], rng.randf_range(0.25, 0.9))

func _set_weather(name: String, value: float) -> void:
    current_weather = name
    intensity = value
    if state != null:
        state.weather = current_weather
        state.weather_intensity = intensity
        state.state_changed.emit()
    weather_changed.emit(current_weather, intensity)
