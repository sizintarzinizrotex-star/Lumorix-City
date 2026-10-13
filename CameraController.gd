extends Camera3D

# ============================================================
# LUMORIX CITY - 3D MOBILE CITY CAMERA
# ============================================================
# Mobil:
#   1 parmak  -> şehir üzerinde hareket
#   2 parmak  -> pinch zoom + kamera hareketi
#
# PC:
#   Sol mouse -> şehir üzerinde hareket
#   Mouse wheel -> zoom
#
# Zoom:
#   Minimum 12
#   Maksimum 125
#
# Kamera oyuncu istemediği sürece otomatik olarak uzaklaşmaz.
# ============================================================

@export var move_speed: float = 28.0
@export var zoom_speed: float = 9.0

@export var min_height: float = 12.0
@export var max_height: float = 125.0

@export var touch_pan_speed: float = 0.75
@export var pinch_zoom_scale: float = 0.16

@export var min_x: float = -150.0
@export var max_x: float = 150.0
@export var min_z: float = -145.0
@export var max_z: float = 145.0

var dragging := false
var touch_points: Dictionary = {}

var last_pinch_distance := -1.0
var last_touch_midpoint := Vector2.ZERO


func _ready() -> void:
    _clamp_camera_position()


func _process(delta: float) -> void:
    _keyboard_movement(delta)
    _keyboard_zoom(delta)
    _clamp_camera_position()


# ============================================================
# KLAVYE
# ============================================================

func _keyboard_movement(delta: float) -> void:
    var direction := Vector3.ZERO

    if Input.is_key_pressed(KEY_A):
        direction.x -= 1.0

    if Input.is_key_pressed(KEY_D):
        direction.x += 1.0

    if Input.is_key_pressed(KEY_W):
        direction.z -= 1.0

    if Input.is_key_pressed(KEY_S):
        direction.z += 1.0

    if direction.length_squared() > 0.0:
        global_position += (
            direction.normalized()
            * move_speed
            * delta
        )


func _keyboard_zoom(delta: float) -> void:
    if Input.is_key_pressed(KEY_Q):
        _apply_zoom(
            -zoom_speed
            * delta
            * 4.0
        )

    if Input.is_key_pressed(KEY_E):
        _apply_zoom(
            zoom_speed
            * delta
            * 4.0
        )


# ============================================================
# ZOOM
# ============================================================

func _apply_zoom(amount: float) -> void:
    global_position.y = clamp(
        global_position.y + amount,
        min_height,
        max_height
    )


# ============================================================
# ŞEHİRDE HAREKET
# ============================================================

func _pan_from_screen_delta(
    delta: Vector2,
    scale: float = 1.0
) -> void:

    var right := global_transform.basis.x
    var forward := -global_transform.basis.z

    right.y = 0.0
    forward.y = 0.0

    right = right.normalized()
    forward = forward.normalized()

    # Kamera yaklaştığında daha hassas hareket.
    var height_factor: float = maxf(
        global_position.y / 45.0,
        0.25
    )

    var world_delta: Vector3 = (
        -right * delta.x
        + forward * delta.y
    ) * scale * height_factor

    global_position += world_delta

    _clamp_camera_position()


# ============================================================
# PINCH DURUMU
# ============================================================

func _reset_pinch_baseline() -> void:

    if touch_points.size() >= 2:

        var ids := touch_points.keys()

        var first_point: Vector2 = touch_points[ids[0]]
        var second_point: Vector2 = touch_points[ids[1]]

        last_pinch_distance = (
            first_point.distance_to(second_point)
        )

        last_touch_midpoint = (
            first_point
            + second_point
        ) * 0.5

    else:

        last_pinch_distance = -1.0
        last_touch_midpoint = Vector2.ZERO


# ============================================================
# MOBİL DOKUNMA
# ============================================================

func _handle_touch(
    event: InputEventScreenTouch
) -> void:

    if event.pressed:

        touch_points[event.index] = event.position
        _reset_pinch_baseline()

    else:

        touch_points.erase(event.index)
        _reset_pinch_baseline()


func _handle_touch_drag(
    event: InputEventScreenDrag
) -> void:

    touch_points[event.index] = event.position

    # --------------------------------------------------------
    # İKİ PARMAK
    # --------------------------------------------------------

    if touch_points.size() >= 2:

        var ids := touch_points.keys()

        var first_point: Vector2 = touch_points[ids[0]]
        var second_point: Vector2 = touch_points[ids[1]]

        var midpoint := (
            first_point
            + second_point
        ) * 0.5

        var distance := (
            first_point.distance_to(second_point)
        )

        # Pinch zoom
        if last_pinch_distance > 0.0:

            var pinch_delta := (
                distance
                - last_pinch_distance
            )

            _apply_zoom(
                -pinch_delta
                * pinch_zoom_scale
            )

        # İki parmakla kamera hareketi
        if last_touch_midpoint != Vector2.ZERO:

            var midpoint_delta := (
                midpoint
                - last_touch_midpoint
            )

            _pan_from_screen_delta(
                midpoint_delta,
                touch_pan_speed
            )

        last_pinch_distance = distance
        last_touch_midpoint = midpoint

    # --------------------------------------------------------
    # TEK PARMAK
    # --------------------------------------------------------

    elif touch_points.size() == 1:

        _pan_from_screen_delta(
            event.relative,
            touch_pan_speed
        )


# ============================================================
# KAMERA SINIRLARI
# ============================================================

func _clamp_camera_position() -> void:

    global_position.x = clamp(
        global_position.x,
        min_x,
        max_x
    )

    global_position.z = clamp(
        global_position.z,
        min_z,
        max_z
    )

    global_position.y = clamp(
        global_position.y,
        min_height,
        max_height
    )


# ============================================================
# MOUSE / PC
# ============================================================

func _unhandled_input(
    event: InputEvent
) -> void:

    # Mobil dokunma
    if event is InputEventScreenTouch:

        _handle_touch(event)
        return

    # Mobil sürükleme / pinch
    if event is InputEventScreenDrag:

        _handle_touch_drag(event)
        return

    # Mouse
    if event is InputEventMouseButton:

        # Şehir sürükleme
        if event.button_index == MOUSE_BUTTON_LEFT:

            dragging = event.pressed
            return

        # Yakınlaş
        if (
            event.pressed
            and event.button_index
            == MOUSE_BUTTON_WHEEL_UP
        ):

            _apply_zoom(-8.0)
            return

        # Uzaklaş
        if (
            event.pressed
            and event.button_index
            == MOUSE_BUTTON_WHEEL_DOWN
        ):

            _apply_zoom(8.0)
            return

    # Mouse hareketi
    if (
        event is InputEventMouseMotion
        and dragging
    ):

        _pan_from_screen_delta(
            event.relative,
            0.8
        )
