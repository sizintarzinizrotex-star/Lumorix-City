class_name LumorixPhase5EconomySystem
extends Node

signal economy_changed
signal premium_purchased
signal market_trade_completed
signal production_order_created
signal production_order_completed
signal tax_collected
signal reward_granted

const NORMAL_MAX_LWL := 10
const PREMIUM_LWL := 20
const PREMIUM_PRICE_LCB := 500
const MARKET_AD_REWARD_LUCB := 25
const PREMIUM_ROTATION_DAYS := 15

var game_state: Node
var production_system: Node
var market_system: Node
var tax_system: Node
var store_system: Node
var upgrade_system: Node
var vehicle_economy: Node
var transport_economy: Node

var day_counter := 0
var market_rotation_day := 0
var market_orders: Array = []
var production_orders: Array = []
var completed_trades: Array = []

var premium_catalog := {
	"super_police": {"name":"Süper Polis Merkezi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"super_fire": {"name":"Süper İtfaiye Merkezi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"special_hospital": {"name":"Özel Hastane","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"special_university": {"name":"Özel Üniversite","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"grand_hotel": {"name":"Grand Hotel","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"mega_airport": {"name":"Mega Havalimanı","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"mega_port": {"name":"Mega Liman","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_metro": {"name":"Premium Metro","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_train_station": {"name":"Premium Tren İstasyonu","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"mega_bridge": {"name":"Mega Köprü","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_roundabout": {"name":"Premium Döner Kavşak","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_power": {"name":"Premium Elektrik Tesisi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_water": {"name":"Premium Su Tesisi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_sewage": {"name":"Premium Kanalizasyon","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_waste": {"name":"Premium Atık Tesisi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_treatment": {"name":"Premium Arıtma Tesisi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_mall": {"name":"Premium AVM","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"mega_stadium": {"name":"Mega Stadyum","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_gas_station": {"name":"Premium Akaryakıt İstasyonu","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_automotive_dealership": {"name":"Premium Otomotiv Bayisi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_concert_area": {"name":"Süper Konser Alanı","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_rally_area": {"name":"Süper Miting Alanı","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"},
	"premium_crane_pack": {"name":"Premium Vinç Paketi","lwl":20,"lcb":500,"permanent":true,"price_status":"locked"}
}

var currency_packages := {
	"lcb": [
		{"amount":250,"price_tl":400},
		{"amount":2500,"price_tl":1999},
		{"amount":4500,"price_tl":3599},
		{"amount":7500,"price_tl":6200},
		{"amount":10000,"price_tl":8299},
		{"amount":15000,"price_tl":12400},
		{"amount":25000,"price_tl":19999},
		{"amount":35000,"price_tl":26999},
		{"amount":50000,"price_tl":39999},
		{"amount":80000,"price_tl":64999},
		{"amount":100000,"price_tl":75999}
	],
	"lucb": [
		{"amount":500,"price_tl":199},
		{"amount":2500,"price_tl":999},
		{"amount":5000,"price_tl":1999},
		{"amount":10000,"price_tl":3999},
		{"amount":20000,"price_tl":6999},
		{"amount":40000,"price_tl":14999},
		{"amount":80000,"price_tl":29999},
		{"amount":150000,"price_tl":59999}
	]
}

var production_recipes := {
	"cement": {"input":{},"output":10,"time":30,"storage":500},
	"steel": {"input":{"ore":5},"output":8,"time":45,"storage":400},
	"glass": {"input":{"sand":6},"output":8,"time":40,"storage":400},
	"electronics": {"input":{"steel":2,"glass":2},"output":4,"time":60,"storage":300},
	"machine": {"input":{"steel":4,"electronics":2},"output":2,"time":90,"storage":250},
	"fuel": {"input":{"oil":5},"output":10,"time":50,"storage":500},
	"construction_equipment": {"input":{"steel":8,"machine":3},"output":1,"time":120,"storage":100}
}

var market_base_prices := {
	"cement":40,
	"steel":75,
	"glass":60,
	"electronics":180,
	"machine":350,
	"fuel":55,
	"construction_equipment":900
}

func initialize(
	state: Node,
	production: Node = null,
	market: Node = null,
	tax: Node = null,
	store: Node = null,
	upgrade: Node = null,
	vehicle: Node = null,
	transport: Node = null
) -> void:
	game_state = state
	production_system = production
	market_system = market
	tax_system = tax
	store_system = store
	upgrade_system = upgrade
	vehicle_economy = vehicle
	transport_economy = transport

	_ensure_economy_state()
	_ensure_inventory_state()
	economy_changed.emit()

func _process(delta: float) -> void:
	if game_state == null:
		return
	_process_production_orders(delta)

func _ensure_inventory_state() -> void:
	if game_state == null:
		return

	if game_state.inventory == null:
		game_state.inventory = {}


func _ensure_economy_state() -> void:
	if game_state == null:
		return

	if game_state.lcb < 0:
		game_state.lcb = 0

	if game_state.lucb < 0:
		game_state.lucb = 0

	if game_state.premium_owned == null:
		game_state.premium_owned = {}

func get_lcb() -> int:
	return int(game_state.lcb) if game_state != null else 0

func get_lucb() -> int:
	return int(game_state.lucb) if game_state != null else 0

func add_lcb(amount: int) -> void:
	if game_state == null:
		return
	game_state.lcb = max(0, int(game_state.lcb) + amount)
	economy_changed.emit()

func add_lucb(amount: int) -> void:
	if game_state == null:
		return
	game_state.lucb = max(0, int(game_state.lucb) + amount)
	economy_changed.emit()

func spend_lucb(amount: int) -> bool:
	if game_state == null or amount < 0:
		return false
	if int(game_state.lucb) < amount:
		return false
	game_state.lucb -= amount
	economy_changed.emit()
	return true

func spend_lcb(amount: int) -> bool:
	if game_state == null or amount < 0:
		return false
	if int(game_state.lcb) < amount:
		return false
	game_state.lcb -= amount
	economy_changed.emit()
	return true

func buy_premium(premium_id: String) -> Dictionary:
	if not premium_catalog.has(premium_id):
		return {"ok":false,"reason":"Premium ürün bulunamadı."}

	if game_state.premium_owned.has(premium_id):
		return {"ok":false,"reason":"Bu premium ürün zaten kalıcı olarak satın alındı."}

	var item: Dictionary = premium_catalog[premium_id]
	if not spend_lcb(PREMIUM_PRICE_LCB):
		return {"ok":false,"reason":"Yetersiz LCB."}

	game_state.premium_owned[premium_id] = true
	game_state.city_message.emit(
		"💎 Premium satın alındı: %s — 20 LWL / 500 LCB / Kalıcı" % item.name,
		"success"
	)

	premium_purchased.emit(premium_id)
	economy_changed.emit()

	return {
		"ok":true,
		"id":premium_id,
		"lwl":PREMIUM_LWL,
		"lcb":PREMIUM_PRICE_LCB,
		"permanent":true
	}

func get_premium_catalog() -> Dictionary:
	return premium_catalog.duplicate(true)

func get_currency_packages() -> Dictionary:
	return currency_packages.duplicate(true)

func create_production_order(recipe_id: String, quantity: int = 1) -> Dictionary:
	if not production_recipes.has(recipe_id):
		return {"ok":false,"reason":"Üretim tarifi bulunamadı."}
	if quantity <= 0:
		return {"ok":false,"reason":"Üretim miktarı geçersiz."}
	if game_state == null:
		return {"ok":false,"reason":"Oyun durumu hazır değil."}

	var recipe: Dictionary = production_recipes[recipe_id]
	var inputs: Dictionary = recipe.get("input", {})
	for item_id in inputs:
		var required: int = int(inputs[item_id]) * quantity
		if game_state.get_inventory_item(str(item_id)) < required:
			return {"ok":false,"reason":"Yetersiz malzeme: " + str(item_id)}

	for item_id in inputs:
		var required: int = int(inputs[item_id]) * quantity
		if not game_state.remove_inventory_item(str(item_id), required):
			return {"ok":false,"reason":"Malzeme düşümü başarısız: " + str(item_id)}

	var order: Dictionary = {
		"id":"production_%d" % (production_orders.size() + 1),
		"recipe_id":recipe_id,
		"quantity":quantity,
		"remaining_time":float(recipe.time) * quantity,
		"output":int(recipe.output) * quantity,
		"status":"queued"
	}
	production_orders.append(order)
	production_order_created.emit(order)
	return {"ok":true,"order":order}

func _process_production_orders(delta: float) -> void:
	if production_orders.is_empty():
		return

	for i in range(production_orders.size() - 1, -1, -1):
		var order: Dictionary = production_orders[i]
		if order.status == "completed":
			continue

		order.remaining_time = max(0.0, float(order.remaining_time) - delta)
		order.status = "processing"

		if order.remaining_time <= 0.0:
			var recipe_id: String = str(order.get("recipe_id", ""))
			var output_amount: int = int(order.get("output", 0))
			if game_state != null and output_amount > 0:
				game_state.add_inventory_item(recipe_id, output_amount)
			order.status = "completed"
			production_order_completed.emit(order)
			production_orders.remove_at(i)

func create_market_listing(item_id: String, quantity: int, price_per_unit: int) -> Dictionary:
	if not market_base_prices.has(item_id):
		return {"ok":false,"reason":"Bu ürün pazarda desteklenmiyor."}
	if quantity <= 0 or price_per_unit <= 0:
		return {"ok":false,"reason":"Miktar veya fiyat geçersiz."}
	if game_state == null:
		return {"ok":false,"reason":"Oyun durumu hazır değil."}
	if game_state.get_inventory_item(item_id) < quantity:
		return {"ok":false,"reason":"Envanterde yeterli ürün yok."}
	if not game_state.remove_inventory_item(item_id, quantity):
		return {"ok":false,"reason":"Ürün envanterden düşürülemedi."}
	var order := {
		"id":"market_%d" % (market_orders.size() + 1),
		"item_id":item_id,
		"quantity":quantity,
		"remaining":quantity,
		"price_per_unit":price_per_unit,
		"status":"active",
		"supply_factor":get_supply_factor(item_id),
		"demand_factor":get_demand_factor(item_id)
	}
	market_orders.append(order)
	return {"ok":true,"order":order}

func buy_market_listing(order_id: String, quantity: int) -> Dictionary:
	for order in market_orders:
		if str(order.id) != order_id:
			continue

		if str(order.status) != "active":
			return {"ok":false,"reason":"İlan aktif değil."}

		var amount: int = mini(quantity, int(order.remaining))
		if amount <= 0:
			return {"ok":false,"reason":"Satın alınacak miktar yok."}

		var total: int = amount * int(order.price_per_unit)
		if not spend_lucb(total):
			return {"ok":false,"reason":"Yetersiz LuCB."}

		order.remaining -= amount
		if order.remaining <= 0:
			order.status = "sold"

		game_state.add_inventory_item(str(order.item_id), amount)

		var trade := {
			"order_id":order_id,
			"item_id":order.item_id,
			"quantity":amount,
			"total_lucb":total
		}
		completed_trades.append(trade)
		market_trade_completed.emit(trade)
		return {"ok":true,"trade":trade}

	return {"ok":false,"reason":"Pazar ilanı bulunamadı."}

func get_supply_factor(item_id: String) -> float:
	var base := float(market_base_prices.get(item_id, 100))
	var active := 0
	for order in market_orders:
		if str(order.item_id) == item_id and str(order.status) == "active":
			active += int(order.remaining)

	return clamp(1.0 + (float(active) / max(base * 5.0, 1.0)), 0.70, 2.50)

func get_demand_factor(item_id: String) -> float:
	var base := float(market_base_prices.get(item_id, 100))
	var recent := 0
	for trade in completed_trades:
		if str(trade.item_id) == item_id:
			recent += int(trade.quantity)

	return clamp(1.0 + (float(recent) / max(base * 3.0, 1.0)), 0.70, 2.50)

func get_dynamic_market_price(item_id: String) -> int:
	var base := int(market_base_prices.get(item_id, 100))
	var supply := get_supply_factor(item_id)
	var demand := get_demand_factor(item_id)
	return max(1, int(round(float(base) * demand / max(supply, 0.1))))

func grant_market_ad_reward() -> int:
	add_lucb(MARKET_AD_REWARD_LUCB)
	reward_granted.emit("market_ad", MARKET_AD_REWARD_LUCB)
	return MARKET_AD_REWARD_LUCB

func calculate_tax_rate(development_lwl: float) -> float:
	if development_lwl <= 20.0:
		return 5.0
	if development_lwl <= 25.0:
		return 5.0 + ((development_lwl - 20.0) * 0.4)
	return min(12.0, 7.0 + ((development_lwl - 25.0) * 0.25))

func calculate_tax(population: int, development_lwl: float, transport_score: float = 1.0) -> Dictionary:
	var safe_population: int = maxi(0, population)
	var base_income: float = float(safe_population) * 2.0
	var infrastructure_factor: float = clampf(transport_score, 0.5, 2.0)
	var rate: float = calculate_tax_rate(development_lwl)
	var amount: int = maxi(0, int(round(base_income * infrastructure_factor * rate / 100.0 * 10.0)))

	return {
		"amount":amount,
		"rate_percent":rate,
		"development_lwl":development_lwl,
		"population":safe_population,
		"transport_factor":infrastructure_factor
	}

func collect_progressive_tax(population: int, development_lwl: float, transport_score: float = 1.0) -> Dictionary:
	var result := calculate_tax(population, development_lwl, transport_score)
	if int(result.amount) > 0:
		add_lucb(int(result.amount))
		tax_collected.emit(int(result.amount), result)
	return result

func validate_building_level(building: Dictionary) -> Dictionary:
	var premium := bool(building.get("premium", false))
	var level := int(building.get("lwl", 1))

	if premium:
		return {
			"valid":level == PREMIUM_LWL,
			"max_lwl":PREMIUM_LWL,
			"premium":true
		}

	return {
		"valid":level <= NORMAL_MAX_LWL,
		"max_lwl":NORMAL_MAX_LWL,
		"premium":false
	}

func get_production_status() -> Dictionary:
	return {
		"active_orders":production_orders.size(),
		"recipes":production_recipes.size(),
		"storage_items":production_recipes.size()
	}

func get_market_status() -> Dictionary:
	return {
		"active_listings":market_orders.size(),
		"completed_trades":completed_trades.size(),
		"dynamic_pricing":true,
		"ad_reward_lucb":MARKET_AD_REWARD_LUCB
	}

func get_tax_status() -> Dictionary:
	return {
		"progressive":true,
		"start_lwl":20.0,
		"full_progression_lwl":25.0,
		"max_rate_percent":12.0
	}

func get_status() -> Dictionary:
	return {
		"lcb":get_lcb(),
		"lucb":get_lucb(),
		"premium_count":premium_catalog.size(),
		"premium_price_lcb":PREMIUM_PRICE_LCB,
		"premium_lwl":PREMIUM_LWL,
		"normal_max_lwl":NORMAL_MAX_LWL,
		"premium_rotation_days":PREMIUM_ROTATION_DAYS,
		"production":get_production_status(),
		"market":get_market_status(),
		"tax":get_tax_status()
	}
