class_name LumorixDayNightSystem
extends Node3D

@export var sun_path: NodePath
@export var cycle_speed := 0.45
var state: Node
var sun: DirectionalLight3D
var environment: WorldEnvironment

func initialize(game_state: Node, world_environment: WorldEnvironment, directional_light: DirectionalLight3D) -> void:
    state = game_state
    environment = world_environment
    sun = directional_light

func _process(delta: float) -> void:
    if state == null or sun == null:
        return
    var t: float = state.day_time / 24.0
    var angle: float = t * 360.0 - 90.0
    sun.rotation_degrees.x = angle
    var daylight: float = clampf(sin((t - 0.25) * TAU) * 0.5 + 0.5, 0.08, 1.0)
    sun.light_energy = lerp(0.15, 1.2, daylight)
    if environment and environment.environment:
        environment.environment.ambient_light_energy = lerp(0.18, 0.72, daylight)
