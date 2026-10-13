class_name LumorixMobileOptimizationSystem
extends Node

signal quality_changed(level: String)
signal performance_status_changed(status: Dictionary)

const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"

const TARGET_FPS := 30
const HIGH_FPS_THRESHOLD := 48
const LOW_FPS_THRESHOLD := 24

const SCALE_LOW := 0.70
const SCALE_MEDIUM := 0.82
const SCALE_HIGH := 1.0

const DETAIL_LOW := 450
const DETAIL_MEDIUM := 700
const DETAIL_HIGH := 1100

var quality_level: String = QUALITY_HIGH
var render_scale: float = SCALE_HIGH
var detail_budget: int = DETAIL_HIGH

var fps_samples: Array[float] = []
var sample_timer: float = 0.0
var adjustment_cooldown: float = 0.0

var world_root: Node3D
var game_state: Node

func initialize(world: Node3D, state: Node) -> void:
    world_root = world
    game_state = state

    _configure_mobile_viewport()
    _detect_initial_quality()
    _apply_quality()

func _process(delta: float) -> void:
    sample_timer += delta
    adjustment_cooldown = maxf(0.0, adjustment_cooldown - delta)

    if sample_timer < 2.0:
        return

    sample_timer = 0.0

    var fps := float(Engine.get_frames_per_second())

    if fps > 0.0:
        fps_samples.append(fps)

    if fps_samples.size() > 5:
        fps_samples.pop_front()

    _evaluate_performance()

func _detect_initial_quality() -> void:
    var processor_count := OS.get_processor_count()

    if processor_count <= 4:
        quality_level = QUALITY_LOW
    elif processor_count <= 6:
        quality_level = QUALITY_MEDIUM
    else:
        quality_level = QUALITY_HIGH

func _evaluate_performance() -> void:
    if fps_samples.is_empty() or adjustment_cooldown > 0.0:
        return

    var total := 0.0

    for value in fps_samples:
        total += value

    var average_fps := total / float(fps_samples.size())

    if average_fps < LOW_FPS_THRESHOLD:
        _set_quality(QUALITY_LOW)
    elif average_fps < TARGET_FPS:
        if quality_level == QUALITY_HIGH:
            _set_quality(QUALITY_MEDIUM)
        elif quality_level == QUALITY_MEDIUM:
            _set_quality(QUALITY_LOW)
    elif average_fps >= HIGH_FPS_THRESHOLD:
        if quality_level == QUALITY_LOW:
            _set_quality(QUALITY_MEDIUM)
        elif quality_level == QUALITY_MEDIUM:
            _set_quality(QUALITY_HIGH)

func _set_quality(level: String) -> void:
    if quality_level == level:
        return

    quality_level = level
    _apply_quality()
    adjustment_cooldown = 6.0
    quality_changed.emit(quality_level)

func _apply_quality() -> void:
    match quality_level:
        QUALITY_LOW:
            render_scale = SCALE_LOW
            detail_budget = DETAIL_LOW
        QUALITY_MEDIUM:
            render_scale = SCALE_MEDIUM
            detail_budget = DETAIL_MEDIUM
        _:
            render_scale = SCALE_HIGH
            detail_budget = DETAIL_HIGH

    _configure_mobile_viewport()
    _apply_detail_budgets()

    performance_status_changed.emit(get_status())

func _configure_mobile_viewport() -> void:
    var viewport := get_viewport()

    if viewport == null:
        return

    viewport.scaling_3d_scale = render_scale

func _apply_detail_budgets() -> void:
    var main := get_parent()

    if main == null:
        return

    var quality_system = main.get_node_or_null("CityVisualQualitySystem")

    if quality_system != null and "max_detail_nodes" in quality_system:
        quality_system.max_detail_nodes = mini(
            int(quality_system.max_detail_nodes),
            detail_budget
        )

    var final_system = main.get_node_or_null("Phase2FinalVisualSystem")

    if final_system != null and "max_detail_nodes" in final_system:
        final_system.max_detail_nodes = mini(
            int(final_system.max_detail_nodes),
            detail_budget
        )

func get_average_fps() -> float:
    if fps_samples.is_empty():
        return 0.0

    var total := 0.0

    for value in fps_samples:
        total += value

    return total / float(fps_samples.size())

func get_status() -> Dictionary:
    return {
        "quality": quality_level,
        "render_scale": render_scale,
        "detail_budget": detail_budget,
        "average_fps": get_average_fps(),
        "target_fps": TARGET_FPS,
        "dynamic_scaling": true,
        "mobile_ready": true
    }
