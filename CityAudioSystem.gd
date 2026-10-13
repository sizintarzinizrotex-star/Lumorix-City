extends Node

## Lightweight mobile city ambience. Loops local WAV assets without external dependencies.
@export var player_paths: Array[NodePath] = [
    NodePath("../CityAudio_Ambience"),
    NodePath("../CityAudio_Traffic"),
    NodePath("../CityAudio_Birds"),
    NodePath("../CityAudio_Construction")
]

var _player_callbacks: Dictionary = {}

func _ready() -> void:
    for path in player_paths:
        var player := get_node_or_null(path) as AudioStreamPlayer
        if player != null:
            var callback := _on_player_finished.bind(player)
            _player_callbacks[player.get_instance_id()] = callback
            player.finished.connect(callback)
            if not player.playing:
                player.play()

func _on_player_finished(player: AudioStreamPlayer) -> void:
    if is_instance_valid(player):
        player.play()

func _exit_tree() -> void:
    for path in player_paths:
        var player := get_node_or_null(path) as AudioStreamPlayer
        if player != null:
            var callback: Callable = _player_callbacks.get(player.get_instance_id(), Callable())
            if callback.is_valid() and player.finished.is_connected(callback):
                player.finished.disconnect(callback)
            player.stop()
    _player_callbacks.clear()
