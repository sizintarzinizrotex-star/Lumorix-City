class_name LumorixSaveSystem
extends Node

const SAVE_PATH := "user://lumorix_city_save.json"

func save_city(state: Node) -> bool:
    var payload := {
        "version": 2,
        "player_id": state.player_id,
        "city_id": state.city_id,
        "city_name": state.city_name,
        "lucb": state.lucb,
        "lcb": state.lcb,
        "population": state.population,
        "jobs": state.jobs,
        "happiness": state.happiness,
        "safety": state.safety,
        "health": state.health,
        "education": state.education,
        "environment": state.environment,
        "traffic": state.traffic,
        "city_level": state.city_level,
        "day_time": state.day_time,
        "city_development_lwl": state.city_development_lwl,
        "tax_last_collection": state.tax_last_collection,
        "tax_last_gross": state.tax_last_gross,
        "municipal_maintenance": state.municipal_maintenance,
        "municipal_net": state.municipal_net,
        "budget_deficit": state.budget_deficit,
        "road_condition_average": state.road_condition_average,
        "road_maintenance_events": state.road_maintenance_events,
        "president_speech_count": state.president_speech_count,
        "last_president_speech": state.last_president_speech,
        "construction_slot_capacity": state.construction_slot_capacity,
        "market_sales_count": state.market_sales_count,
        "market_sales_income": state.market_sales_income,
        "market_units_traded": state.market_units_traded,
        "market_purchase_spend": state.market_purchase_spend,
        "market_listings_created": state.market_listings_created,
        "market_returned_units": state.market_returned_units,
        "market": state.get_parent().get_node("MarketSystem").export_data(),
        "premium_owned": state.premium_owned,
        "friends": state.get_parent().get_node("FriendSystem").export_data(),
        "addresses": state.get_parent().get_node("CityAddressSystem").export_data(),
        "citizen_routes": {"home": state.citizen_home_address, "work": state.citizen_work_address, "destination": state.citizen_destination_address, "type": state.citizen_destination_type, "transport": state.citizen_transport_mode, "trip_time": state.citizen_trip_time}
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    return true

func load_city(state: Node) -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return false
    state.player_id = str(data.get("player_id", state.player_id))
    state.city_id = str(data.get("city_id", state.city_id))
    state.city_name = str(data.get("city_name", state.city_name))
    state.lucb = int(data.get("lucb", state.lucb))
    state.lcb = int(data.get("lcb", state.lcb))
    state.population = int(data.get("population", state.population))
    state.jobs = int(data.get("jobs", state.jobs))
    state.happiness = float(data.get("happiness", state.happiness))
    state.safety = float(data.get("safety", state.safety))
    state.health = float(data.get("health", state.health))
    state.education = float(data.get("education", state.education))
    state.environment = float(data.get("environment", state.environment))
    state.traffic = float(data.get("traffic", state.traffic))
    state.city_level = int(data.get("city_level", state.city_level))
    state.day_time = float(data.get("day_time", state.day_time))
    state.city_development_lwl = float(data.get("city_development_lwl", state.city_development_lwl))
    state.tax_last_collection = int(data.get("tax_last_collection", state.tax_last_collection))
    state.tax_last_gross = int(data.get("tax_last_gross", state.tax_last_gross))
    state.municipal_maintenance = int(data.get("municipal_maintenance", state.municipal_maintenance))
    state.municipal_net = int(data.get("municipal_net", state.municipal_net))
    state.budget_deficit = bool(data.get("budget_deficit", state.budget_deficit))
    state.road_condition_average = float(data.get("road_condition_average", state.road_condition_average))
    state.road_maintenance_events = int(data.get("road_maintenance_events", state.road_maintenance_events))
    state.president_speech_count = int(data.get("president_speech_count", state.president_speech_count))
    state.last_president_speech = str(data.get("last_president_speech", state.last_president_speech))
    state.construction_slot_capacity = clampi(int(data.get("construction_slot_capacity", state.construction_slot_capacity)), 3, 10)
    state.construction_slots = min(state.construction_slots, state.construction_slot_capacity)
    state.market_sales_count = int(data.get("market_sales_count", state.market_sales_count))
    state.market_sales_income = int(data.get("market_sales_income", state.market_sales_income))
    state.market_units_traded = int(data.get("market_units_traded", state.market_units_traded))
    state.market_purchase_spend = int(data.get("market_purchase_spend", state.market_purchase_spend))
    state.market_listings_created = int(data.get("market_listings_created", state.market_listings_created))
    state.market_returned_units = int(data.get("market_returned_units", state.market_returned_units))
    var routes: Dictionary = data.get("citizen_routes", {})
    state.citizen_home_address = str(routes.get("home", state.citizen_home_address))
    state.citizen_work_address = str(routes.get("work", state.citizen_work_address))
    state.citizen_destination_address = str(routes.get("destination", state.citizen_destination_address))
    state.citizen_destination_type = str(routes.get("type", state.citizen_destination_type))
    state.citizen_transport_mode = str(routes.get("transport", state.citizen_transport_mode))
    state.citizen_trip_time = float(routes.get("trip_time", state.citizen_trip_time))
    state.premium_owned = data.get("premium_owned", {})
    var market_system := state.get_parent().get_node_or_null("MarketSystem")
    if market_system != null:
        market_system.restore_data(data.get("market", {}))
    var address_system := state.get_parent().get_node_or_null("CityAddressSystem")
    if address_system != null:
        address_system.restore_data(data.get("addresses", {}))
    var friend_system := state.get_parent().get_node_or_null("FriendSystem")
    if friend_system != null:
        friend_system.restore_data(data.get("friends", {}))
    state.state_changed.emit()
    return true
