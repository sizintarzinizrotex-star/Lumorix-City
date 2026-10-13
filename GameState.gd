extends Node

signal state_changed
signal city_message(text: String, severity: String)

var city_name := "Lumorix City"
var player_id := "LOCAL-PLAYER-001"
var city_id := "CITY-001"
var lucb: int = 12450
var market_earnings: int = 0
var lcb: int = 320
var inventory: Dictionary = {
    "cement": 0,
    "steel": 0,
    "glass": 0,
    "electronics": 0,
    "machine": 0,
    "fuel": 0,
    "construction_equipment": 0,
    "ore": 0,
    "sand": 0,
    "oil": 0
}

var population: int = 1250
var jobs: int = 980
var happiness: float = 78.0
var safety: float = 82.0
var health: float = 80.0
var education: float = 76.0
var environment: float = 74.0
var traffic: float = 68.0
var road_condition_average: float = 100.0
var road_maintenance_events: int = 0
var weather := "clear"
var weather_intensity: float = 0.0
var city_level: int = 1
var day_time: float = 8.0
var simulation_speed: float = 1.0
var city_development_lwl: float = 1.0
var tax_last_collection: int = 0
var tax_last_gross: int = 0
var municipal_maintenance: int = 0
var municipal_net: int = 0
var budget_deficit: bool = false
var service_capacity: Dictionary = {}
var service_demand: Dictionary = {}
var service_scores: Dictionary = {}
var service_levels: Dictionary = {}
var service_shortages: Dictionary = {}
var service_outages: Dictionary = {}
var service_coverage: Dictionary = {}
var service_coverage_buildings: Dictionary = {}
var service_uncovered_buildings: Dictionary = {}
var service_spatial_scores: Dictionary = {}
var expansion_population_bonus: int = 0
var expansion_jobs_bonus: int = 0
var expansion_service_bonus: Dictionary = {"safety":0.0,"health":0.0,"education":0.0,"environment":0.0,"traffic":0.0}
var premium_owned: Dictionary = {}
var buildings: Array[Dictionary] = []
var complaints: Array[String] = []
var last_message_key := ""
var protest_count: int = 0
var citizens_moved_away: int = 0
var active_city_risks: Dictionary = {"crime":0.0,"fire":0.0,"disease":0.0,"waste":0.0,"traffic":0.0}
var service_recovery_bonus: float = 0.0
var citizen_routine_phase := "ev"
var citizen_routine_activity := "Ev"
var citizen_mobility_demand: float = 0.0
var citizen_economic_activity: float = 0.0
var citizen_routine_tick: int = 0
var citizen_home_address := ""
var citizen_work_address := ""
var citizen_destination_address := ""
var citizen_destination_type := "ev"
var citizen_active_trip := ""
var citizen_transport_mode := "yaya"
var citizen_trip_time: float = 0.0
var coastal_activity_count: int = 0
var coastal_walkers: int = 0
var coastal_runners: int = 0
var coastal_cyclists: int = 0
var coastal_fishers: int = 0
var coastal_dog_walkers: int = 0
var coastal_children: int = 0
var park_activity_count: int = 0
var park_walkers: int = 0
var park_runners: int = 0
var park_children: int = 0
var park_athletes: int = 0
var park_social_visitors: int = 0
var park_destinations: Array[Dictionary] = []
var event_area_status: Dictionary = {"concert":false,"rally":false,"premium_concert":false,"premium_rally":false}
var president_speech_count: int = 0
var last_president_speech := ""
var construction_slots: int = 3
var construction_slot_capacity: int = 3
var traffic_vehicle_count: int = 0
var traffic_demand_index: float = 0.0
var traffic_road_capacity: float = 70.0
var fuel_demand_index: float = 0.0
var fuel_delivery_count: int = 0
var dealership_sales_count: int = 0
var fuel_income: int = 0
var dealership_income: int = 0
var airport_passenger_count: int = 0
var airport_ticket_income: int = 0
var port_cargo_units: int = 0
var port_trade_income: int = 0
var city_export_units: int = 0
var city_import_units: int = 0
var metro_passenger_count: int = 0
var train_passenger_count: int = 0
var bus_passenger_count: int = 0
var transit_income: int = 0
var transit_transfer_count: int = 0
var transit_waiting_passengers: int = 0
var transit_peak_load: float = 0.0
var transit_station_load: float = 0.0
var transit_service_pressure: float = 0.0
var transit_transfer_pressure: float = 0.0
var land_value_average: float = 50.0
var land_value_factor: float = 1.0
var city_neighborhoods: Array[String] = ["Lumorix Merkez"]
var city_streets: Array[String] = ["Lumorix Sokak"]
var city_avenues: Array[String] = ["Lumorix Bulvarı"]
var lumorix_cargo_deliveries: int = 0
var lumorix_courier_deliveries: int = 0
var lumorix_food_orders: int = 0
var lumorix_cargo_income: int = 0
var lumorix_courier_income: int = 0
var lumorix_cargo_units: int = 0
var lumorix_food_units: int = 0
var lumorix_active_routes: int = 0
var lumorix_logistics_efficiency: float = 1.0
var market_sales_count: int = 0
var market_sales_income: int = 0
var market_units_traded: int = 0
var market_purchase_spend: int = 0
var market_listings_created: int = 0
var market_returned_units: int = 0

func initialize_new_city() -> void:
    buildings.clear()
    premium_owned.clear()
    complaints.clear()
    protest_count = 0
    citizens_moved_away = 0
    active_city_risks = {"crime":0.0,"fire":0.0,"disease":0.0,"waste":0.0,"traffic":0.0}
    service_recovery_bonus = 0.0
    citizen_routine_phase = "ev"
    citizen_routine_activity = "Ev"
    citizen_mobility_demand = 0.0
    citizen_economic_activity = 0.0
    citizen_routine_tick = 0
    citizen_home_address = ""
    citizen_work_address = ""
    citizen_destination_address = ""
    citizen_destination_type = "ev"
    citizen_active_trip = ""
    citizen_transport_mode = "yaya"
    citizen_trip_time = 0.0
    coastal_activity_count = 0
    coastal_walkers = 0
    coastal_runners = 0
    coastal_cyclists = 0
    coastal_fishers = 0
    coastal_dog_walkers = 0
    coastal_children = 0
    park_activity_count = 0
    park_walkers = 0
    park_runners = 0
    park_children = 0
    park_athletes = 0
    park_social_visitors = 0
    park_destinations = []
    market_sales_count = 0
    market_sales_income = 0
    market_units_traded = 0
    market_purchase_spend = 0
    market_listings_created = 0
    market_returned_units = 0
    traffic_vehicle_count = 0
    traffic_demand_index = 0.0
    traffic_road_capacity = 70.0
    fuel_demand_index = 0.0
    fuel_delivery_count = 0
    dealership_sales_count = 0
    fuel_income = 0
    dealership_income = 0
    airport_passenger_count = 0
    airport_ticket_income = 0
    port_cargo_units = 0
    port_trade_income = 0
    city_export_units = 0
    city_import_units = 0
    metro_passenger_count = 0
    train_passenger_count = 0
    bus_passenger_count = 0
    transit_income = 0
    transit_transfer_count = 0
    transit_waiting_passengers = 0
    transit_peak_load = 0.0
    transit_station_load = 0.0
    transit_service_pressure = 0.0
    transit_transfer_pressure = 0.0
    land_value_average = 50.0
    land_value_factor = 1.0
    state_changed.emit()

func add_inventory_item(item_id: String, amount: int) -> void:
    if amount <= 0:
        return

    if not inventory.has(item_id):
        inventory[item_id] = 0

    inventory[item_id] += amount
    state_changed.emit()

func remove_inventory_item(item_id: String, amount: int) -> bool:
    if amount <= 0:
        return true

    if not inventory.has(item_id):
        return false

    if inventory[item_id] < amount:
        return false

    inventory[item_id] -= amount
    state_changed.emit()
    return true

func get_inventory_item(item_id: String) -> int:
    if not inventory.has(item_id):
        return 0

    return int(inventory[item_id])


func add_market_earnings(amount: int) -> void:
    if amount <= 0:
        return
    market_earnings += amount

func add_lucb(amount: int) -> void:
    lucb += max(amount, 0)
    state_changed.emit()

func spend_lucb(amount: int) -> bool:
    if amount <= lucb:
        lucb -= amount
        state_changed.emit()
        return true
    city_message.emit("Yetersiz LuCB.", "warning")
    return false

func spend_lcb(amount: int) -> bool:
    if amount <= lcb:
        lcb -= amount
        state_changed.emit()
        return true
    city_message.emit("Yetersiz LCB.", "warning")
    return false

func buy_premium(id: String, price_lcb: int) -> bool:
    if premium_owned.has(id):
        city_message.emit("Bu premium içerik zaten sende.", "info")
        return false
    if spend_lcb(price_lcb):
        premium_owned[id] = {"purchase_price": price_lcb, "level": 20, "owned_forever": true}
        city_message.emit("Premium içerik kalıcı olarak hesabına eklendi.", "success")
        return true
    return false

func recalculate_expansion_impact() -> void:
    expansion_population_bonus = 0
    expansion_jobs_bonus = 0
    expansion_service_bonus = {"safety":0.0,"health":0.0,"education":0.0,"environment":0.0,"traffic":0.0}
    for building in buildings:
        if not bool(building.get("expansion", false)):
            continue
        var level := int(building.get("lwl", 1))
        var scale := 1.0 + float(max(level - 1, 0)) * 0.12
        match str(building.get("type", "")):
            "residential":
                expansion_population_bonus += int(120.0 * scale)
            "commercial":
                expansion_jobs_bonus += int(70.0 * scale)
                expansion_service_bonus.traffic += 0.8 * scale
            "factory":
                expansion_jobs_bonus += int(95.0 * scale)
                expansion_service_bonus.environment -= 0.7 * scale
            "public":
                expansion_service_bonus.safety += 1.2 * scale
                expansion_service_bonus.health += 1.0 * scale
                expansion_service_bonus.education += 0.9 * scale
                expansion_service_bonus.environment += 0.5 * scale
    population = 1250 + expansion_population_bonus
    jobs = 980 + expansion_jobs_bonus
    safety = clamp(82.0 + float(expansion_service_bonus.safety), 0.0, 100.0)
    health = clamp(80.0 + float(expansion_service_bonus.health), 0.0, 100.0)
    education = clamp(76.0 + float(expansion_service_bonus.education), 0.0, 100.0)
    environment = clamp(74.0 + float(expansion_service_bonus.environment), 0.0, 100.0)
    traffic = clamp(68.0 - float(expansion_service_bonus.traffic), 0.0, 100.0)
    state_changed.emit()

func apply_citizen_departure(amount: int, reason: String) -> void:
    var leaving: int = clampi(amount, 0, maxi(0, population - 100))
    if leaving <= 0:
        return
    population -= leaving
    citizens_moved_away += leaving
    city_message.emit("🏠 %d vatandaş şehirden ayrıldı: %s" % [leaving, reason], "danger")
    state_changed.emit()

func register_protest(reason: String) -> void:
    protest_count += 1
    city_message.emit("📢 Protesto başladı: %s" % reason, "danger")
    state_changed.emit()

func set_city_risk(risk_id: String, value: float) -> void:
    active_city_risks[risk_id] = clamp(value, 0.0, 100.0)

func simulate_economy(delta: float) -> void:
    var net_income := int((population * 0.35 + jobs * 0.15) * delta)
    var service_cost := int((population * 0.12 + buildings.size() * 0.6) * delta)
    lucb += net_income - service_cost
    var average := (environment + safety + health + education + (100.0 - traffic)) / 5.0
    happiness = clamp(average, 0.0, 100.0)
    _evaluate_city_feedback()
    state_changed.emit()

func tick_day(delta: float) -> void:
    day_time += delta * simulation_speed
    if day_time >= 24.0:
        day_time -= 24.0
    simulate_economy(delta)

func _evaluate_city_feedback() -> void:
    if environment < 35.0:
        _complain_once("Çevre", "Vatandaşlar şehirdeki çevre sorunlarından şikâyet ediyor.")
    elif safety < 35.0:
        _complain_once("Güvenlik", "Suç oranı yükseldi. Vatandaşlar güvenlik istiyor.")
    elif health < 35.0:
        _complain_once("Sağlık", "Sağlık hizmetleri yetersiz. Vatandaşların şikâyetleri arttı.")
    elif education < 35.0:
        _complain_once("Eğitim", "Okul kapasitesi yetersiz. Vatandaşlar daha fazla eğitim hizmeti istiyor.")
    elif traffic < 25.0:
        _complain_once("Trafik", "Trafik yoğunluğu nedeniyle vatandaşların yolculuk süresi arttı.")
    elif happiness >= 85.0:
        _complain_once("Mutluluk", "Vatandaşlar Lumorix City'de yaşamaktan çok memnun.")

func _complain_once(key: String, message: String) -> void:
    if last_message_key == key:
        return
    last_message_key = key
    complaints.append(message)
    if complaints.size() > 12:
        complaints.pop_front()
    city_message.emit(message, "danger" if happiness < 40.0 else "info")
