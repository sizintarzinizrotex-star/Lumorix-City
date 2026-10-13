class_name LumorixUpgradeSystem
extends Node

signal upgrade_completed(building_id: String, new_level: int)
signal upgrade_blocked(building_id: String, reason: String)

var state: Node
var production: Node
var inventory: Dictionary = {
    "cement": 250, "steel": 180, "glass": 100, "electronics": 80,
    "machine": 60, "fuel": 100, "construction_equipment": 40
}

const TYPE_REQUIREMENTS := {
    "metro": {"train_equipment": 1},
    "train_station": {"train_equipment": 1},
    "train": {"train_equipment": 1, "motor_parts": 1},
    "high_speed_train": {"train_equipment": 2, "motor_parts": 2},
    "ship": {"ship_equipment": 1},
    "cargo_ship": {"ship_equipment": 2, "machine": 1},
    "passenger_ship": {"ship_equipment": 1, "motor_parts": 1},
    "airport": {"aircraft_equipment": 1},
    "mega_airport": {"aircraft_equipment": 2, "electronics": 5},
    "aircraft": {"aircraft_equipment": 1, "motor_parts": 1},
    "road": {"construction_equipment": 1, "cement": 10},
    "bridge": {"construction_equipment": 2, "steel": 15, "cement": 20},
    "highway": {"construction_equipment": 3, "steel": 25, "cement": 30},
    "power": {"electronics": 5, "machine": 2},
    "water": {"machine": 2, "construction_equipment": 1},
    "sewage": {"machine": 2, "construction_equipment": 1},
    "waste": {"machine": 2, "construction_equipment": 1},
    "police": {"electronics": 2, "construction_equipment": 1},
    "fire": {"machine": 2, "construction_equipment": 1},
    "hospital": {"electronics": 4, "machine": 2},
    "school": {"electronics": 3, "construction_equipment": 1},
    "factory": {"machine": 2, "electronics": 2, "construction_equipment": 1}
}

const REQUIREMENTS := {
    2: {"lucb":500,"materials":{"cement":20,"steel":10,"glass":5}},
    3: {"lucb":1200,"materials":{"cement":40,"steel":25,"glass":10,"electronics":10,"machine":5}},
    4: {"lucb":2500,"materials":{"steel":50,"electronics":25,"machine":15,"fuel":10,"construction_equipment":5}},
    5: {"lucb":5000,"materials":{"steel":100,"electronics":50,"machine":30,"fuel":20,"construction_equipment":10}},
    6: {"lucb":8500,"materials":{"steel":180,"electronics":60,"machine":45,"fuel":30,"construction_equipment":15}},
    7: {"lucb":14000,"materials":{"steel":260,"electronics":90,"machine":65,"fuel":45,"construction_equipment":25}},
    8: {"lucb":22000,"materials":{"steel":380,"electronics":130,"machine":90,"fuel":65,"construction_equipment":35}},
    9: {"lucb":34000,"materials":{"steel":520,"electronics":180,"machine":125,"fuel":90,"construction_equipment":50}},
    10: {"lucb":52000,"materials":{"steel":700,"electronics":240,"machine":170,"fuel":120,"construction_equipment":70}}
}

func initialize(game_state: Node, production_system: Node = null) -> void:
    state = game_state
    production = production_system
    if production != null:
        inventory = production.get_inventory()

func can_upgrade(building: Dictionary) -> Dictionary:
    if bool(building.get("premium", false)):
        return {"ok":false,"reason":"Premium yapı doğrudan 20 LWL'dir."}
    var current := int(building.get("lwl", 1))
    if current >= 10:
        return {"ok":false,"reason":"Normal yapı maksimum 10 LWL'ye ulaştı."}
    var next := current + 1
    var req: Dictionary = REQUIREMENTS.get(next, {}).duplicate(true)
    var type_key := str(building.get("type", "generic"))
    var type_materials: Dictionary = TYPE_REQUIREMENTS.get(type_key, {})
    if not type_materials.is_empty():
        var materials: Dictionary = req.get("materials", {}).duplicate(true)
        for item in type_materials.keys():
            materials[item] = int(materials.get(item, 0)) + int(type_materials[item]) * max(1, int(ceil(float(next) / 2.0)))
        req["materials"] = materials
    if int(state.lucb) < int(req.get("lucb", 0)):
        return {"ok":false,"reason":"Yetersiz LuCB."}
    if production != null:
        inventory = production.get_inventory()
    var missing: Array[String] = []
    for item in req.get("materials", {}).keys():
        if int(inventory.get(item, 0)) < int(req.get("materials", {}).get(item, 0)):
            missing.append("%s (%d/%d)" % [item, int(inventory.get(item, 0)), int(req.get("materials", {}).get(item, 0))])
    if not missing.is_empty():
        return {"ok":false,"reason":"Eksik ekipman/malzeme: " + ", ".join(missing)}
    return {"ok":true,"next_level":next,"requirements":req}

func get_requirements_for_next_level(building: Dictionary) -> Dictionary:
    var current := int(building.get("lwl", 1))
    var next := current + 1
    var req: Dictionary = REQUIREMENTS.get(next, {}).duplicate(true)
    var type_materials: Dictionary = TYPE_REQUIREMENTS.get(str(building.get("type", "generic")), {})
    if not type_materials.is_empty():
        var materials: Dictionary = req.get("materials", {}).duplicate(true)
        for item in type_materials.keys():
            materials[item] = int(materials.get(item, 0)) + int(type_materials[item]) * max(1, int(ceil(float(next) / 2.0)))
        req["materials"] = materials
    return req

func get_inventory() -> Dictionary:
    return inventory.duplicate(true)

func format_requirements(building: Dictionary) -> Array[String]:
    var req := get_requirements_for_next_level(building)
    var lines: Array[String] = []
    if req.is_empty():
        return lines
    lines.append("LuCB: %s" % _format_number(int(req.get("lucb", 0))))
    for item in req.get("materials", {}).keys():
        lines.append("%s: %d / %d" % [str(item).capitalize(), int(inventory.get(item, 0)), int(req.materials[item])])
    return lines

func _format_number(value: int) -> String:
    var s := str(value)
    var out := ""
    while s.length() > 3:
        out = "." + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return s + out

func upgrade(building: Dictionary) -> bool:
    var friend_system := state.get_parent().get_node_or_null("FriendSystem") if state != null and state.get_parent() != null else null
    if friend_system != null and friend_system.has_method("can_modify_city") and not friend_system.can_modify_city():
        upgrade_blocked.emit(str(building.get("id", "")), "Arkadaş şehrini ziyaret ederken yükseltme yapılamaz.")
        return false
    var check := can_upgrade(building)
    if not bool(check.ok):
        upgrade_blocked.emit(str(building.get("id", "")), str(check.reason))
        return false
    var req: Dictionary = check.requirements
    state.lucb -= int(req.get("lucb", 0))
    for item in req.get("materials", {}).keys():
        if production != null:
            production.remove_item(item, int(req.get("materials", {}).get(item, 0)))
        else:
            inventory[item] = int(inventory.get(item, 0)) - int(req.get("materials", {}).get(item, 0))
    building["lwl"] = int(check.next_level)
    upgrade_completed.emit(str(building.get("id", "")), int(check.next_level))
    state.state_changed.emit()
    return true
