class_name LumorixAccountSystem
extends Node

const ACCOUNT_PATH := "user://lumorix_account.json"
var player_id := ""
var city_id := ""
var purchases: Array = []
var premium_owned: Dictionary = {}
var cloud_sync_ready := false

func initialize(state: Node) -> void:
    if FileAccess.file_exists(ACCOUNT_PATH):
        _load_account()
    else:
        player_id = "PLAYER-%08d" % Time.get_unix_time_from_system()
        city_id = "CITY-%08d" % (Time.get_unix_time_from_system() + 7919)
        save_account()
    state.player_id = player_id
    state.city_id = city_id
    state.premium_owned = premium_owned

func record_purchase(product_id: String, amount: int, currency: String, price_try: int) -> void:
    purchases.append({"product_id":product_id,"amount":amount,"currency":currency,"price_try":price_try,"timestamp":Time.get_unix_time_from_system()})
    save_account()

func own_premium(item_id: String) -> void:
    premium_owned[item_id] = true
    save_account()

func save_account() -> void:
    var f := FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"version":1,"player_id":player_id,"city_id":city_id,"purchases":purchases,"premium_owned":premium_owned}))

func _load_account() -> void:
    var f := FileAccess.open(ACCOUNT_PATH, FileAccess.READ)
    if f == null: return
    var data = JSON.parse_string(f.get_as_text())
    if data is Dictionary:
        player_id = str(data.get("player_id", ""))
        city_id = str(data.get("city_id", ""))
        purchases = data.get("purchases", [])
        premium_owned = data.get("premium_owned", {})
