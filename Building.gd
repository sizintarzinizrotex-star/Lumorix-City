class_name LumorixBuilding
extends Node3D

signal selected(building: LumorixBuilding)

var building_id := ""
var display_name := "Building"
var building_type := "generic"
var lwl: int = 1
var normal_max_lwl: int = 10
var premium := false
var premium_level: int = 20
var service_capacity: int = 100
var service_radius: float = 20.0
var interactive := false
var visual_body: MeshInstance3D
var accent: MeshInstance3D

func setup(data: Dictionary) -> void:
    building_id = str(data.get("id", "building"))
    display_name = str(data.get("name", "Building"))
    building_type = str(data.get("type", "generic"))
    lwl = int(data.get("level", 1))
    normal_max_lwl = int(data.get("max_level", 10))
    if building_type in ["power", "water", "sewage", "waste", "police", "fire", "hospital", "health", "school", "education", "parks"]:
        normal_max_lwl = min(normal_max_lwl, 5)
    premium = bool(data.get("premium", false))
    premium_level = int(data.get("premium_level", 20))
    service_capacity = int(data.get("capacity", 100))
    service_radius = float(data.get("radius", 20.0))
    interactive = bool(data.get("interactive", false))

func set_visuals(body: MeshInstance3D, roof: MeshInstance3D = null) -> void:
    visual_body = body
    accent = roof
    _update_visual_scale()

func set_level(level: int) -> void:
    lwl = clamp(level, 1, premium_level if premium else normal_max_lwl)
    _update_visual_scale()

func upgrade_normal() -> bool:
    if premium or lwl >= normal_max_lwl:
        return false
    lwl += 1
    _update_visual_scale()
    return true

func activate_premium() -> void:
    premium = true
    lwl = premium_level
    _update_visual_scale()

func _update_visual_scale() -> void:
    var ratio := 1.0
    if premium:
        ratio = 1.0 + float(max(lwl - 10, 0)) * 0.045
    else:
        ratio = 1.0 + float(max(lwl - 1, 0)) * 0.025
    if visual_body:
        visual_body.scale = Vector3(1.0, ratio, 1.0)
    if accent:
        accent.position.y = max(accent.position.y, 0.1) * ratio

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        selected.emit(self)
