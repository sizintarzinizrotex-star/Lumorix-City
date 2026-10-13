class_name LumorixProceduralAssetFactory
extends RefCounted

static func material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

static func box(size: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = material(color)
    return node

static func cylinder(radius: float, height: float, color: Color, radial_segments := 16) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = radial_segments
    node.mesh = mesh
    node.material_override = material(color)
    return node

static func building_shell(size: Vector3, body_color: Color, roof_color: Color) -> Node3D:
    var root := Node3D.new()
    var body := box(size, body_color)
    body.position.y = size.y * 0.5
    root.add_child(body)
    var roof := box(Vector3(size.x * 0.82, 0.35, size.z * 0.82), roof_color)
    roof.position.y = size.y + 0.18
    root.add_child(roof)
    return root

static func residential(size := Vector3(7, 10, 7)) -> Node3D:
    var root := building_shell(size, Color("#b9d0df"), Color("#324c68"))
    for y in range(2, int(size.y), 2):
        var band := box(Vector3(size.x * 0.9, 0.08, size.z * 0.03), Color("#9dc1d6"))
        band.position = Vector3(0, y, -size.z * 0.51)
        root.add_child(band)
    return root

static func commercial(size := Vector3(9, 16, 9)) -> Node3D:
    var root := building_shell(size, Color("#d8b66c"), Color("#55442c"))
    var sign := box(Vector3(size.x * 0.65, 0.6, 0.15), Color("#f4e6a5"))
    sign.position = Vector3(0, size.y * 0.55, -size.z * 0.52)
    root.add_child(sign)
    return root

static func police(size := Vector3(8, 9, 8), premium := false) -> Node3D:
    var root := building_shell(size, Color("#3c6795") if not premium else Color("#173e70"), Color("#d8e9f5"))
    var mast := cylinder(0.18, 3.0 if not premium else 5.0, Color("#e8eef5"), 12)
    mast.position.y = size.y + 1.5
    root.add_child(mast)
    if premium:
        var pad := cylinder(2.2, 0.12, Color("#3b4248"), 24)
        pad.position = Vector3(0, 0.1, size.z * 0.65)
        root.add_child(pad)
    return root

static func hospital(size := Vector3(10, 12, 8), premium := false) -> Node3D:
    var root := building_shell(size, Color("#dfe9ee") if not premium else Color("#eef7ff"), Color("#8bb3cf"))
    var cross_h := box(Vector3(0.65, 2.5, 0.18), Color("#d84949"))
    cross_h.position = Vector3(0, size.y * 0.6, -size.z * 0.52)
    root.add_child(cross_h)
    var cross_v := box(Vector3(2.5, 0.65, 0.18), Color("#d84949"))
    cross_v.position = cross_h.position
    root.add_child(cross_v)
    return root

static func mall(size := Vector3(15, 9, 12), premium := false) -> Node3D:
    var root := building_shell(size, Color("#6c91bd") if not premium else Color("#415f91"), Color("#243b5a"))
    var glass := box(Vector3(size.x * 0.72, size.y * 0.42, 0.12), Color("#9fd4e8"))
    glass.position = Vector3(0, size.y * 0.55, -size.z * 0.52)
    root.add_child(glass)
    if premium:
        var tower := cylinder(1.2, 7.0, Color("#d7b96b"), 20)
        tower.position.y = size.y + 3.5
        root.add_child(tower)
    return root

static func stadium(size := Vector3(21, 6, 15), premium := false) -> Node3D:
    var root := Node3D.new()
    var field := box(Vector3(size.x * 0.58, 0.2, size.z * 0.42), Color("#3e9b52"))
    field.position.y = 0.2
    root.add_child(field)
    for i in 4:
        var stand := box(Vector3(size.x * 0.9, 1.3 + i * 0.35, 2.0), Color("#4d7d55") if not premium else Color("#596c9c"))
        stand.position = Vector3(0, (1.3 + i * 0.35) * 0.5, -size.z * 0.42 + i * 0.75)
        root.add_child(stand)
    var roof := box(Vector3(size.x * 0.95, 0.35, 1.0), Color("#d7dce2"))
    roof.position.y = 5.0 + (2.0 if premium else 0.0)
    root.add_child(roof)
    return root

static func utility(size := Vector3(9, 7, 9), color := Color("#858b92")) -> Node3D:
    var root := building_shell(size, color, Color("#343a40"))
    var tank := cylinder(size.x * 0.18, size.y * 0.8, Color("#b7c0c8"), 16)
    tank.position = Vector3(size.x * 0.28, size.y * 0.4, size.z * 0.28)
    root.add_child(tank)
    return root

static func park(size := Vector3(18, 0.15, 12)) -> Node3D:
    var root := Node3D.new()
    var base := box(size, Color("#4f9a55"))
    base.position.y = 0.05
    root.add_child(base)
    for i in 7:
        var tree_node := tree()
        tree_node.position = Vector3(-7.0 + float(i % 4) * 4.5, 0, -3.0 + float(i / 4) * 5.0)
        root.add_child(tree_node)
    return root

static func pedestrian(kind := "walker") -> Node3D:
    var root := Node3D.new()
    var body_color := Color("#d9a06f") if kind == "runner" else (Color("#7aa96b") if kind == "cyclist" else (Color("#d88f9b") if kind == "child" else Color("#6b8fb3")))
    var body := box(Vector3(0.32, 0.75, 0.22), body_color)
    body.position.y = 0.75
    root.add_child(body)
    var head := cylinder(0.16, 0.28, Color("#d8ad82"), 12)
    head.position.y = 1.3
    root.add_child(head)
    var leg_l := box(Vector3(0.09, 0.55, 0.09), Color("#30343a"))
    leg_l.position = Vector3(-0.09, 0.28, 0)
    root.add_child(leg_l)
    var leg_r := box(Vector3(0.09, 0.55, 0.09), Color("#30343a"))
    leg_r.position = Vector3(0.09, 0.28, 0)
    root.add_child(leg_r)
    if kind == "runner":
        var bottle := cylinder(0.05, 0.18, Color("#6db7d6"), 8)
        bottle.position = Vector3(0.25, 0.85, 0)
        root.add_child(bottle)
    elif kind == "child":
        body.scale = Vector3(0.78, 0.78, 0.78)
        head.scale = Vector3(0.85, 0.85, 0.85)
    elif kind == "cyclist":
        var wheel_l := cylinder(0.22, 0.04, Color("#20252a"), 12)
        wheel_l.rotation_degrees.x = 90
        wheel_l.position = Vector3(-0.32, 0.24, 0.0)
        root.add_child(wheel_l)
        var wheel_r := cylinder(0.22, 0.04, Color("#20252a"), 12)
        wheel_r.rotation_degrees.x = 90
        wheel_r.position = Vector3(0.32, 0.24, 0.0)
        root.add_child(wheel_r)
        var frame := box(Vector3(0.7, 0.05, 0.05), Color("#3f4d59"))
        frame.position = Vector3(0, 0.42, 0)
        root.add_child(frame)
    elif kind == "dog_walker":
        var leash := box(Vector3(0.75, 0.025, 0.025), Color("#8b6a43"))
        leash.position = Vector3(0.38, 0.62, 0.0)
        leash.rotation_degrees.z = -18
        root.add_child(leash)
        var dog := box(Vector3(0.38, 0.28, 0.22), Color("#9a6b45"))
        dog.position = Vector3(0.75, 0.28, 0.0)
        root.add_child(dog)
        var dog_head := cylinder(0.12, 0.22, Color("#9a6b45"), 10)
        dog_head.position = Vector3(0.95, 0.43, 0.0)
        root.add_child(dog_head)
    elif kind == "fisher":
        var rod := box(Vector3(0.04, 1.6, 0.04), Color("#5a4934"))
        rod.position = Vector3(0.35, 0.9, 0.0)
        rod.rotation_degrees.z = -18
        root.add_child(rod)
    return root

static func coastal_path_segment(size := Vector3(20, 0.08, 2.2), bike := false) -> Node3D:
    var root := Node3D.new()
    var base := box(size, Color("#b7b0a2") if not bike else Color("#5c777f"))
    base.position.y = 0.04
    root.add_child(base)
    if bike:
        for x in range(-8, 9, 4):
            var mark := box(Vector3(0.08, 0.02, 0.8), Color("#e6d86c"))
            mark.position = Vector3(float(x), 0.1, 0)
            root.add_child(mark)
    return root

static func tree() -> Node3D:
    var root := Node3D.new()
    var trunk := box(Vector3(0.35, 2.0, 0.35), Color("#6b472b"))
    trunk.position.y = 1.0
    root.add_child(trunk)
    var crown := cylinder(1.2, 1.8, Color("#2f733d"))
    crown.position.y = 2.6
    root.add_child(crown)
    return root


static func factory(size := Vector3(11, 8, 11), premium := false) -> Node3D:
    var root := building_shell(size, Color("#777f87") if not premium else Color("#566b84"), Color("#303841"))
    var tower := cylinder(size.x * 0.12, size.y * 1.15, Color("#aeb8bf"), 14)
    tower.position = Vector3(size.x * 0.28, size.y * 0.55, size.z * 0.25)
    root.add_child(tower)
    for x in [-0.28, 0.0, 0.28]:
        var pipe := box(Vector3(0.16, size.y * 0.7, 0.16), Color("#c6ccd1"))
        pipe.position = Vector3(size.x * x, size.y * 0.36, size.z * 0.52)
        root.add_child(pipe)
    return root

static func school(size := Vector3(10, 7, 9), university := false) -> Node3D:
    var root := building_shell(size, Color("#d59b59") if not university else Color("#8e789f"), Color("#4a3b32"))
    var sign := box(Vector3(size.x * 0.5, 0.55, 0.12), Color("#f1df9a"))
    sign.position = Vector3(0, size.y * 0.58, -size.z * 0.52)
    root.add_child(sign)
    var flag := box(Vector3(0.08, 2.0, 0.08), Color("#dddddd"))
    flag.position = Vector3(size.x * 0.36, size.y + 0.9, size.z * 0.2)
    root.add_child(flag)
    return root

static func fire_station(size := Vector3(8, 7, 8), premium := false) -> Node3D:
    var root := building_shell(size, Color("#a9473e") if not premium else Color("#7c2525"), Color("#ece7df"))
    for i in 2:
        var door := box(Vector3(1.7, 2.6, 0.15), Color("#25292d"))
        door.position = Vector3(-1.9 + i * 3.8, 1.3, -size.z * 0.52)
        root.add_child(door)
    return root

static func metro_station(size := Vector3(8, 5, 7), premium := false) -> Node3D:
    var root := building_shell(size, Color("#596f91") if premium else Color("#68757f"), Color("#202b36"))
    var canopy := box(Vector3(size.x * 0.9, 0.25, size.z * 0.5), Color("#b9d4e5"))
    canopy.position.y = size.y + 0.5
    root.add_child(canopy)
    return root

static func train_station(size := Vector3(12, 5, 8), premium := false) -> Node3D:
    var root := building_shell(size, Color("#7a8d9b") if not premium else Color("#4f6686"), Color("#2c3540"))
    var roof := box(Vector3(size.x * 1.05, 0.25, size.z * 0.65), Color("#d7dde2"))
    roof.position.y = size.y + 0.55
    root.add_child(roof)
    return root

static func vehicle(kind := "car", premium := false) -> Node3D:
    var root := Node3D.new()
    var body_size := Vector3(1.2, 0.45, 2.1)
    if kind == "bike":
        var wheel_a := CylinderMesh.new()
        wheel_a.top_radius = 0.28
        wheel_a.bottom_radius = 0.28
        wheel_a.height = 0.08
        var wheel_b := wheel_a.duplicate()
        var wa := MeshInstance3D.new()
        wa.mesh = wheel_a
        wa.rotation.z = PI * 0.5
        wa.position = Vector3(0, 0.3, -0.65)
        root.add_child(wa)
        var wb := MeshInstance3D.new()
        wb.mesh = wheel_b
        wb.rotation.z = PI * 0.5
        wb.position = Vector3(0, 0.3, 0.65)
        root.add_child(wb)
        var frame := box(Vector3(0.08, 0.08, 1.15), Color("#d8a23a"))
        frame.position.y = 0.42
        root.add_child(frame)
        var handle := box(Vector3(0.55, 0.06, 0.06), Color("#444444"))
        handle.position = Vector3(0, 0.68, -0.65)
        root.add_child(handle)
        return root
    if kind == "bus": body_size = Vector3(1.5, 1.0, 4.2)
    elif kind == "truck": body_size = Vector3(1.4, 0.9, 3.4)
    elif kind == "ambulance" or kind == "fire_truck": body_size = Vector3(1.5, 0.9, 3.5)
    var body := box(body_size, Color("#d8d8d8") if not premium else Color("#c6d9f0"))
    root.add_child(body)
    var cabin := box(Vector3(body_size.x * 0.82, body_size.y * 0.85, body_size.z * 0.38), Color("#6d9fc2"))
    cabin.position.z = -body_size.z * 0.12
    cabin.position.y = body_size.y * 0.55
    root.add_child(cabin)
    return root

static func gas_station(size := Vector3(12, 5, 10), premium := false) -> Node3D:
    var root := building_shell(size, Color("#e3e0d2") if not premium else Color("#c9d7e8"), Color("#303943"))
    var canopy := box(Vector3(size.x * 0.82, 0.35, size.z * 0.42), Color("#d34b43") if not premium else Color("#c49b45"))
    canopy.position = Vector3(0, size.y + 1.8, 0.2)
    root.add_child(canopy)
    for x in [-3.0, 3.0]:
        var pillar := box(Vector3(0.25, 1.8, 0.25), Color("#e8ecef"))
        pillar.position = Vector3(x, size.y + 0.9, 0.2)
        root.add_child(pillar)
    for x in [-3.0, 0.0, 3.0]:
        var pump := box(Vector3(0.8, 1.1, 0.6), Color("#59636c"))
        pump.position = Vector3(x, 0.55, 0.2)
        root.add_child(pump)
    var sign := box(Vector3(0.25, 4.0, 0.25), Color("#454b52"))
    sign.position = Vector3(size.x * 0.48, 2.0, size.z * 0.35)
    root.add_child(sign)
    var sign_board := box(Vector3(1.7, 1.2, 0.18), Color("#e0b84f") if premium else Color("#e7e7e7"))
    sign_board.position = Vector3(size.x * 0.48, 3.9, size.z * 0.35)
    root.add_child(sign_board)
    return root

static func automotive_dealership(size := Vector3(15, 8, 12), premium := false) -> Node3D:
    var root := building_shell(size, Color("#d9e1e8") if not premium else Color("#b9cce4"), Color("#283b50"))
    var glass := box(Vector3(size.x * 0.78, size.y * 0.55, 0.16), Color("#9bd2e8"))
    glass.position = Vector3(0, size.y * 0.52, -size.z * 0.52)
    root.add_child(glass)
    for x in [-4.0, 0.0, 4.0]:
        var display_car := vehicle("car", premium)
        display_car.scale = Vector3(1.25, 1.25, 1.25)
        display_car.position = Vector3(x, 0.35, -size.z * 0.15)
        root.add_child(display_car)
    var service_bay := box(Vector3(size.x * 0.65, 0.18, size.z * 0.28), Color("#555d65"))
    service_bay.position = Vector3(0, 0.1, size.z * 0.32)
    root.add_child(service_bay)
    return root

static func service_vehicle(kind := "garbage_truck", premium := false) -> Node3D:
    var root := vehicle("truck", premium)
    var body_color := Color("#65706a")
    if kind == "fuel_tanker": body_color = Color("#d2a74c")
    elif kind == "logistics_truck": body_color = Color("#7890aa")
    elif kind == "construction_truck": body_color = Color("#d08c35")
    elif kind == "municipal_service": body_color = Color("#477a86")
    elif kind == "courier": body_color = Color("#d66a3a")
    elif kind == "cargo_van": body_color = Color("#4d7aa6")
    var cargo := box(Vector3(1.35, 1.15, 1.8), body_color)
    cargo.position = Vector3(0, 0.72, 0.8)
    root.add_child(cargo)
    if kind == "courier":
        var courier_box := box(Vector3(0.85, 0.75, 0.8), Color("#f0b44c"))
        courier_box.position = Vector3(0, 0.65, 0.9)
        root.add_child(courier_box)
    elif kind == "cargo_van":
        var cargo_van := box(Vector3(1.45, 1.25, 1.7), body_color)
        cargo_van.position = Vector3(0, 0.75, 0.8)
        root.add_child(cargo_van)
    elif kind == "garbage_truck":
        var lift := box(Vector3(0.9, 0.8, 0.12), Color("#3d464b"))
        lift.position = Vector3(0, 0.55, 1.75)
        root.add_child(lift)
    elif kind == "fuel_tanker":
        var tank := cylinder(0.55, 1.65, Color("#e5c56c"), 16)
        tank.rotation_degrees.z = 90
        tank.position = Vector3(0, 1.0, 0.8)
        root.add_child(tank)
    return root

static func gas_station_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(14, 0.2, 10), Color("#555b61")))
    var counter := box(Vector3(5.5, 1.2, 1.0), Color("#b78d4a"))
    counter.position = Vector3(-2.5, 0.7, -3.0)
    root.add_child(counter)
    for x in [-4.0, -1.5, 1.0, 3.5]:
        var shelf := box(Vector3(0.7, 2.4, 0.6), Color("#7c8790"))
        shelf.position = Vector3(x, 1.2, 0.5)
        root.add_child(shelf)
    for x in [-3.0, 0.0, 3.0]:
        var pump := box(Vector3(0.8, 1.0, 0.7), Color("#c8a447"))
        pump.position = Vector3(x, 0.5, 3.0)
        root.add_child(pump)
    return root

static func dealership_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(18, 0.2, 12), Color("#e4e6e8")))
    for x in [-5.0, 0.0, 5.0]:
        var car := vehicle("car", false)
        car.scale = Vector3(1.7, 1.7, 1.7)
        car.position = Vector3(x, 0.45, -1.0)
        root.add_child(car)
    var desk := box(Vector3(4.5, 1.1, 1.0), Color("#56616a"))
    desk.position = Vector3(0, 0.65, 4.0)
    root.add_child(desk)
    return root

static func mall_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(22, 0.2, 16), Color("#d7d9dc")))
    for x in [-7.0, 0.0, 7.0]:
        var shop := box(Vector3(5.0, 3.2, 3.0), Color("#7188a1"))
        shop.position = Vector3(x, 1.6, -4.5)
        root.add_child(shop)
    for x in [-3.0, 3.0]:
        var escalator := box(Vector3(1.3, 0.3, 6.0), Color("#9ca5ad"))
        escalator.position = Vector3(x, 0.2, 2.0)
        escalator.rotation_degrees.x = -18.0
        root.add_child(escalator)
    return root

static func stadium_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(28, 0.2, 20), Color("#3e9b52")))
    for side in [-1.0, 1.0]:
        var stand := box(Vector3(25, 4.0, 3.0), Color("#596c9c"))
        stand.position = Vector3(0, 2.0, side * 7.0)
        root.add_child(stand)
    var score := box(Vector3(5.0, 3.0, 0.4), Color("#20252a"))
    score.position = Vector3(0, 4.5, -5.0)
    root.add_child(score)
    return root

static func hospital_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(18, 0.2, 14), Color("#edf2f4")))
    for x in [-5.0, 0.0, 5.0]:
        var bed := box(Vector3(3.0, 0.55, 1.4), Color("#b8c7d2"))
        bed.position = Vector3(x, 0.4, -2.0)
        root.add_child(bed)
        var monitor := box(Vector3(0.7, 1.6, 0.5), Color("#596a77"))
        monitor.position = Vector3(x + 1.5, 0.8, -2.0)
        root.add_child(monitor)
    var desk := box(Vector3(5.0, 1.0, 1.0), Color("#6e8796"))
    desk.position = Vector3(0, 0.5, 4.5)
    root.add_child(desk)
    return root

static func school_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(18, 0.2, 14), Color("#e6dcc6")))
    for x in [-4.0, 0.0, 4.0]:
        var desk := box(Vector3(2.5, 0.6, 1.2), Color("#9b7048"))
        desk.position = Vector3(x, 0.4, 0)
        root.add_child(desk)
    var board := box(Vector3(6.0, 2.4, 0.15), Color("#315a48"))
    board.position = Vector3(0, 1.8, -5.5)
    root.add_child(board)
    return root

static func airport_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(28, 0.2, 16), Color("#d9e0e6")))
    for x in [-9.0, -3.0, 3.0, 9.0]:
        var gate := box(Vector3(3.5, 2.0, 2.0), Color("#6d8ca8"))
        gate.position = Vector3(x, 1.0, -4.5)
        root.add_child(gate)
    var baggage := box(Vector3(14, 0.45, 2.0), Color("#454d54"))
    baggage.position = Vector3(0, 0.3, 3.0)
    root.add_child(baggage)
    return root

static func port_interior() -> Node3D:
    var root := Node3D.new()
    root.add_child(box(Vector3(28, 0.2, 16), Color("#7b9eaa")))
    for x in [-9.0, 0.0, 9.0]:
        var container := box(Vector3(5.0, 2.4, 2.8), Color("#71808a"))
        container.position = Vector3(x, 1.2, 0)
        root.add_child(container)
    for x in [-7.0, 7.0]:
        var crane := box(Vector3(0.5, 7.0, 0.5), Color("#4f5960"))
        crane.position = Vector3(x, 3.5, -4.0)
        root.add_child(crane)
    return root

static func premium_landmark(premium_id: String) -> Node3D:
    var root := Node3D.new()
    var base := box(Vector3(10, 0.3, 10), Color("#34234f"))
    base.position.y = 0.15
    root.add_child(base)
    var tower_height := 5.0
    var body_size := Vector3(6, 4.0, 6)
    var body_color := Color("#6b45a1")
    var accent_color := Color("#e6c76a")
    var title := premium_id.replace("_", " ").to_upper()
    if premium_id in ["mega_bridge", "premium_roundabout"]:
        body_size = Vector3(8, 1.2, 5)
        tower_height = 2.0
        body_color = Color("#536878")
    elif premium_id in ["premium_power", "premium_water", "premium_sewage", "premium_waste", "premium_treatment"]:
        body_size = Vector3(6, 3.2, 6)
        tower_height = 4.5
        body_color = Color("#3f6575")
    elif premium_id in ["mega_airport", "mega_port", "premium_metro", "premium_train_station"]:
        body_size = Vector3(8, 2.5, 6)
        tower_height = 3.0
        body_color = Color("#45627d")
    elif premium_id in ["super_police", "super_fire", "special_hospital", "special_university"]:
        body_size = Vector3(6.5, 4.5, 6.5)
        tower_height = 5.5
        body_color = Color("#4d6fa3")
    elif premium_id in ["premium_mall", "mega_stadium", "grand_hotel"]:
        body_size = Vector3(8, 5.0, 8)
        tower_height = 6.0
        body_color = Color("#73508f")
    elif premium_id in ["premium_gas_station", "premium_automotive_dealership"]:
        body_size = Vector3(8, 2.2, 6)
        tower_height = 3.0
        body_color = Color("#596d7a")
    var body := box(body_size, body_color)
    body.position.y = body_size.y * 0.5 + 0.3
    root.add_child(body)
    var tower := box(Vector3(0.55, tower_height, 0.55), accent_color)
    tower.position = Vector3(0, tower_height * 0.5 + body_size.y + 0.25, 0)
    root.add_child(tower)
    var sign := Label3D.new()
    sign.text = title
    sign.position = Vector3(0, tower_height + body_size.y + 1.2, 0)
    sign.font_size = 22
    sign.outline_size = 5
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    root.add_child(sign)
    return root

static func event_area(size := Vector3(18, 0.3, 14), premium := false, event_kind := "concert") -> Node3D:
    var root := Node3D.new()
    var base := box(Vector3(size.x, 0.25, size.z), Color("#263746") if not premium else Color("#3b285c"))
    base.position.y = 0.12
    root.add_child(base)
    var stage := box(Vector3(size.x * 0.72, 1.2 if not premium else 1.8, 3.0), Color("#485866") if not premium else Color("#6b45a1"))
    stage.position = Vector3(0, 0.75 if not premium else 1.0, -size.z * 0.28)
    root.add_child(stage)
    for x in [-size.x * 0.32, 0.0, size.x * 0.32]:
        var pole := box(Vector3(0.22, 5.0 if premium else 3.5, 0.22), Color("#39434b"))
        pole.position = Vector3(x, pole.scale.y * 0.5, -size.z * 0.22)
        root.add_child(pole)
        if premium:
            var light := OmniLight3D.new()
            light.position = Vector3(x, 4.4, -size.z * 0.18)
            light.omni_range = 14.0
            light.light_energy = 2.2
            light.light_color = Color("#d7b7ff") if event_kind == "concert" else Color("#ffd18a")
            root.add_child(light)
    for x in [-size.x * 0.38, -size.x * 0.19, 0.0, size.x * 0.19, size.x * 0.38]:
        var barrier := box(Vector3(0.8, 0.9, 0.25), Color("#b9a46a"))
        barrier.position = Vector3(x, 0.45, size.z * 0.30)
        root.add_child(barrier)
    var sign := Label3D.new()
    sign.text = ("LUMORIX SÜPER KONSER" if premium and event_kind == "concert" else "LUMORIX SÜPER MİTİNG" if premium else "LUMORIX KONSER ALANI" if event_kind == "concert" else "LUMORIX HALK ALANI")
    sign.position = Vector3(0, 3.0 if premium else 2.4, -size.z * 0.45)
    sign.font_size = 32 if premium else 24
    sign.outline_size = 6
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    root.add_child(sign)
    return root

static func construction_crane(premium := false) -> Node3D:
    var root := Node3D.new()
    var mast := box(Vector3(0.5, 8.0, 0.5), Color("#d08c35"))
    mast.position.y = 4.0
    root.add_child(mast)
    var arm := box(Vector3(7.0 if not premium else 9.0, 0.35, 0.35), Color("#d8a54b"))
    arm.position = Vector3(2.8, 7.8, 0)
    root.add_child(arm)
    var counter := box(Vector3(1.2, 0.6, 0.7), Color("#6f4c2c"))
    counter.position = Vector3(-0.8, 7.5, 0)
    root.add_child(counter)
    var cable := box(Vector3(0.08, 3.4, 0.08), Color("#22272b"))
    cable.position = Vector3(5.5 if not premium else 6.8, 6.0, 0)
    root.add_child(cable)
    var hook := box(Vector3(0.45, 0.25, 0.45), Color("#4c5256"))
    hook.position = Vector3(5.5 if not premium else 6.8, 4.3, 0)
    root.add_child(hook)
    return root


static func street_lamp() -> Node3D:
    var root := Node3D.new()
    var pole := box(Vector3(0.12, 2.8, 0.12), Color("#3d4147"))
    pole.position.y = 1.4
    root.add_child(pole)
    var arm := box(Vector3(0.8, 0.1, 0.1), Color("#3d4147"))
    arm.position = Vector3(0.35, 2.7, 0)
    root.add_child(arm)
    var light := box(Vector3(0.45, 0.12, 0.45), Color("#f5e7a0"))
    light.position = Vector3(0.7, 2.65, 0)
    root.add_child(light)
    return root
