class_name LumorixCitizenSystem
extends Node3D

var city_world: Node
var game_state: Node
var citizens: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var spawn_count := 90
var routine_targets := {
    "ev": Vector3(-18, 0.45, 18),
    "is": Vector3(18, 0.45, -12),
    "alisveris": Vector3(8, 0.45, 12),
    "ulasim": Vector3(-5, 0.45, -18)
}

func initialize(world: Node, state: Node) -> void:
    city_world = world
    game_state = state
    rng.seed = 8842
    _spawn_citizens(spawn_count)

func _spawn_citizens(count: int) -> void:
    for i in count:
        var c := MeshInstance3D.new()
        c.name = "Citizen_%03d" % i
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.12
        mesh.height = 0.7
        c.mesh = mesh
        c.material_override = _citizen_material(i)
        c.position = Vector3(rng.randf_range(-130,130), 0.45, rng.randf_range(-120,120))
        add_child(c)
        citizens.append(c)

func _citizen_material(i: int) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    var colors := [Color("#e5c39b"), Color("#d8a47f"), Color("#f1d0ae"), Color("#b87d62")]
    m.albedo_color = colors[i % colors.size()]
    return m

func _process(delta: float) -> void:
    elapsed += delta
    var phase := "ev"
    if game_state != null:
        phase = str(game_state.citizen_routine_phase)
    var target: Vector3 = routine_targets.get(phase, routine_targets["ev"])
    for i in citizens.size():
        var c := citizens[i]
        var t := elapsed * (0.22 + float(i % 5) * 0.035) + i
        var offset := Vector3(sin(t) * (3.0 + float(i % 6) * 0.7), 0.0, cos(t * 0.7) * (2.5 + float(i % 5) * 0.6))
        var destination := target + offset
        c.position = c.position.lerp(destination, delta * (0.35 + float(i % 4) * 0.04))
        c.position.y = 0.45 + abs(sin(t * 1.4)) * 0.04
        if abs(c.position.x) > 150:
            c.position.x = clamp(c.position.x, -145.0, 145.0)
        if abs(c.position.z) > 145:
            c.position.z = clamp(c.position.z, -140.0, 140.0)
