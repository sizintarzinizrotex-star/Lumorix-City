class_name LumorixProductionSystem
extends Node

signal production_started(recipe_id: String)
signal production_completed(recipe_id: String, item_id: String, quantity: int)
signal inventory_changed

var state: Node
var inventory: Dictionary = {
    "iron_ore": 500, "stone": 500, "sand": 300, "oil": 250,
    "cement": 250, "steel": 180, "glass": 100, "electronics": 80,
    "machine": 60, "fuel": 100, "construction_equipment": 40,
    "food": 200, "motor_parts": 30, "train_equipment": 15,
    "ship_equipment": 10, "aircraft_equipment": 8
}
var recipes: Dictionary = {}
var active_jobs: Array[Dictionary] = []

func initialize(game_state: Node) -> void:
    state = game_state
    _load_recipes()

func _load_recipes() -> void:
    var path := "res://data/production_catalog.json"
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        recipes = parsed.get("recipes", {})

func has_items(cost: Dictionary) -> bool:
    for item in cost.keys():
        if int(inventory.get(item, 0)) < int(cost[item]):
            return false
    return true

func start_production(recipe_id: String, amount: int = 1) -> bool:
    if not recipes.has(recipe_id) or amount <= 0:
        return false
    var recipe: Dictionary = recipes[recipe_id]
    var cost: Dictionary = {}
    for item in recipe.get("inputs", {}).keys():
        cost[item] = int(recipe.inputs[item]) * amount
    if not has_items(cost):
        if state:
            state.city_message.emit("Üretim için yeterli hammadde yok.", "warning")
        return false
    for item in cost.keys():
        inventory[item] = int(inventory[item]) - int(cost[item])
    active_jobs.append({"recipe":recipe_id, "remaining":float(recipe.get("time_seconds", 30)) * amount, "amount":amount})
    production_started.emit(recipe_id)
    inventory_changed.emit()
    return true

func _process(delta: float) -> void:
    if active_jobs.is_empty():
        return
    for i in range(active_jobs.size() - 1, -1, -1):
        active_jobs[i].remaining -= delta
        if active_jobs[i].remaining <= 0.0:
            var job: Dictionary = active_jobs[i]
            var recipe: Dictionary = recipes.get(str(job.recipe), {})
            var item_id := str(recipe.get("output", ""))
            var qty := int(recipe.get("output_quantity", 1)) * int(job.amount)
            if item_id != "":
                inventory[item_id] = int(inventory.get(item_id, 0)) + qty
                production_completed.emit(str(job.recipe), item_id, qty)
            active_jobs.remove_at(i)
            inventory_changed.emit()

func add_item(item_id: String, quantity: int) -> void:
    if quantity <= 0:
        return
    inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
    inventory_changed.emit()

func remove_item(item_id: String, quantity: int) -> bool:
    if quantity <= 0 or int(inventory.get(item_id, 0)) < quantity:
        return false
    inventory[item_id] -= quantity
    inventory_changed.emit()
    return true

func get_inventory() -> Dictionary:
    return inventory.duplicate(true)

func get_active_jobs() -> Array[Dictionary]:
    return active_jobs.duplicate(true)
