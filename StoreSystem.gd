class_name LumorixStoreSystem
extends Node

const ROTATION_DAYS := 15
var current_rotation_day := 1
var campaign_bonus_percent := 0
var catalog: Dictionary = {}
var rotation_seed := 0
var currency_packages: Dictionary = {}
var catalog_validation: Dictionary = {"valid":false,"premium_count":0,"lcb_count":0,"lucb_count":0,"errors":[]}

func load_catalog(path: String = "res://data/premium_catalog.json") -> void:
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        catalog = parsed
    var currency_path := "res://data/currency_packages.json"
    if FileAccess.file_exists(currency_path):
        var currency_file := FileAccess.open(currency_path, FileAccess.READ)
        var currency_parsed = JSON.parse_string(currency_file.get_as_text())
        if currency_parsed is Dictionary:
            currency_packages = currency_parsed
    _validate_catalog()

func _validate_catalog() -> void:
    var errors: Array[String] = []
    var premium_items := get_premium_items()
    var ids: Dictionary = {}
    for item in premium_items:
        if not item is Dictionary:
            errors.append("premium_item_dictionary")
            continue
        var id := str(item.get("id", ""))
        if id.is_empty():
            errors.append("premium_id_empty")
        elif ids.has(id):
            errors.append("premium_id_duplicate:%s" % id)
        else:
            ids[id] = true
        if int(item.get("price_lcb", -1)) != 500:
            errors.append("premium_price:%s" % id)
        if int(item.get("level", -1)) != 20:
            errors.append("premium_level:%s" % id)
        if str(item.get("price_status", "")) != "locked":
            errors.append("premium_price_status:%s" % id)
    var lcb_items := get_currency_packages("lcb")
    var lucb_items := get_currency_packages("lucb")
    for item in lcb_items:
        if not item is Dictionary or int(item.get("amount", 0)) <= 0 or int(item.get("price_try", 0)) <= 0:
            errors.append("invalid_lcb_package")
    for item in lucb_items:
        if not item is Dictionary or int(item.get("amount", 0)) <= 0 or int(item.get("price_try", 0)) <= 0:
            errors.append("invalid_lucb_package")
    catalog_validation = {"valid":errors.is_empty(),"premium_count":premium_items.size(),"lcb_count":lcb_items.size(),"lucb_count":lucb_items.size(),"errors":errors}

func get_catalog_validation() -> Dictionary:
    return catalog_validation.duplicate(true)

func get_premium_items() -> Array:
    var items = catalog.get("premium_items", [])
    return items if items is Array else []

func get_premium_item(id: String) -> Dictionary:
    for item in get_premium_items():
        if str(item.get("id", "")) == id:
            return item
    return {}

func get_currency_packages(currency: String) -> Array:
    var items = currency_packages.get(currency.to_lower(), [])
    return items if items is Array else []

func set_rotation_day(day: int) -> void:
    current_rotation_day = clamp(day, 1, ROTATION_DAYS)

func advance_rotation() -> void:
    current_rotation_day += 1
    if current_rotation_day > ROTATION_DAYS:
        current_rotation_day = 1
        rotation_seed += 1

func is_rotation_change(day: int) -> bool:
    return day > 0 and day % ROTATION_DAYS == 0

func set_high_value_campaign(percent: int) -> void:
    campaign_bonus_percent = clamp(percent, 0, 30)

func get_campaign_amount(base_amount: int) -> int:
    return base_amount + int(round(float(base_amount) * float(campaign_bonus_percent) / 100.0))

func get_rotation_info() -> Dictionary:
    return {"day":current_rotation_day,"rotation_days":ROTATION_DAYS,"campaign_bonus_percent":campaign_bonus_percent,"seed":rotation_seed}
