class_name LumorixMarketSystem
extends Node

signal market_changed

const LISTING_LIFETIME := 86400.0
const PRICE_FLOOR := 0.5
const PRICE_CEILING := 2.5

var state: Node
var production: Node
var listings: Array[Dictionary] = []
var next_listing_id := 1
var catalog: Dictionary = {}
var market_stats: Dictionary = {}
var elapsed := 0.0
var npc_trade_clock := 0.0

func initialize(game_state: Node, production_system: Node) -> void:
    state = game_state
    production = production_system
    _load_catalog()
    listings = [
        {"id":"demo_1","seller_id":"PLAYER-A","city_id":"CITY-A","item":"cement","name":"Çimento","quantity":100,"unit_price":8,"remaining":43200.0},
        {"id":"demo_2","seller_id":"PLAYER-B","city_id":"CITY-B","item":"steel","name":"Çelik","quantity":50,"unit_price":24,"remaining":72000.0},
        {"id":"demo_3","seller_id":"PLAYER-C","city_id":"CITY-C","item":"electronics","name":"Elektronik","quantity":20,"unit_price":80,"remaining":60000.0}
    ]
    _recalculate_stats()

func _load_catalog() -> void:
    var path := "res://data/market_catalog.json"
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        catalog = parsed.get("items", {})

func _process(delta: float) -> void:
    elapsed += delta
    npc_trade_clock += delta
    if npc_trade_clock >= 12.0:
        npc_trade_clock = 0.0
        _simulate_market_demand()
    var changed := false
    for i in range(listings.size() - 1, -1, -1):
        listings[i].remaining = float(listings[i].remaining) - delta
        if listings[i].remaining <= 0.0:
            # Kendi ilanımız 24 saat içinde satılmazsa ürün depoya geri döner.
            # Başka oyuncunun ilanı ise istemcide silinmez bir bakiye yazmayız;
            # gerçek çevrimiçi sürümde sunucu settlement sistemi bunu yönetecek.
            if state != null and str(listings[i].get("seller_id", "")) == str(state.player_id):
                var returned := int(listings[i].get("quantity", 0))
                if returned > 0:
                    production.add_item(str(listings[i].get("item", "")), returned)
                    state.market_returned_units += returned
                    state.city_message.emit("📦 Satılmayan ilan depoya döndü: %s ×%d" % [str(listings[i].get("name", listings[i].get("item", ""))), returned], "info")
            listings.remove_at(i)
            changed = true
    if changed:
        _recalculate_stats()
        market_changed.emit()

func create_listing(item_id: String, name: String, quantity: int, unit_price: int) -> bool:
    if quantity <= 0 or unit_price <= 0:
        return false
    if not production.remove_item(item_id, quantity):
        if state:
            state.city_message.emit("Satış için yeterli ürün yok.", "warning")
        return false
    listings.append({
        "id":"listing_%d" % next_listing_id,
        "seller_id":state.player_id,
        "city_id":state.city_id,
        "item":item_id,
        "name":name,
        "quantity":quantity,
        "unit_price":unit_price,
        "remaining":LISTING_LIFETIME
    })
    next_listing_id += 1
    state.market_listings_created += 1
    _recalculate_stats()
    market_changed.emit()
    return true

func buy_listing(listing_id: String, quantity: int) -> bool:
    for listing in listings:
        if str(listing.id) != listing_id:
            continue
        if str(listing.seller_id) == str(state.player_id):
            state.city_message.emit("Kendi ilanından satın alamazsın.", "warning")
            return false
        var buy_qty: int = mini(quantity, int(listing.quantity))
        var total: float = buy_qty * int(listing.unit_price)
        if buy_qty <= 0 or int(state.lucb) < total:
            state.city_message.emit("Yetersiz LuCB.", "warning")
            return false
        state.lucb -= total
        state.market_purchase_spend += total
        state.market_units_traded += buy_qty
        production.add_item(str(listing.item), buy_qty)
        listing.quantity = int(listing.quantity) - buy_qty
        # Gerçek oyuncular arası para aktarımı final sunucu ekonomisinde settlement ile yapılacak.
        # Böylece istemci doğrudan başka oyuncunun LuCB bakiyesine yazamaz.
        if int(listing.quantity) <= 0:
            listings.erase(listing)
        _recalculate_stats()
        state.state_changed.emit()
        market_changed.emit()
        return true
    return false

func _simulate_market_demand() -> void:
    # Tek oyunculu sürümde pazarın boş kalmaması için NPC/şehir dışı alıcılar
    # oyuncunun ilanlarından küçük miktarlarda satın alabilir. Gerçek online
    # sürümde aynı akış sunucu settlement sistemiyle değiştirilecektir.
    if state == null or listings.is_empty():
        return
    for listing in listings:
        if str(listing.get("seller_id", "")) != str(state.player_id):
            continue
        var item_id := str(listing.get("item", ""))
        var stats: Dictionary = market_stats.get(item_id, {})
        var demand := float(stats.get("demand_index", 1.0))
        var chance: float = clampf(0.18 + demand * 0.08, 0.18, 0.45)
        if randf() > chance:
            continue
        var available: int = int(listing.get("quantity", 0))
        if available <= 0:
            continue
        var qty: int = mini(available, maxi(1, int(ceil(float(available) * 0.15))))
        var revenue: float = qty * int(listing.get("unit_price", 0))
        listing.quantity = available - qty
        state.add_lucb(revenue)
        state.market_sales_count += 1
        state.market_sales_income += revenue
        state.market_units_traded += qty
        state.city_message.emit("🛒 Pazar satışı: %s ×%d → +%d LuCB" % [str(listing.get("name", item_id)), qty, revenue], "success")
        if int(listing.quantity) <= 0:
            listings.erase(listing)
        _recalculate_stats()
        market_changed.emit()
        break

func get_listings() -> Array[Dictionary]:
    return listings.duplicate(true)

func export_data() -> Dictionary:
    return {
        "next_listing_id": next_listing_id,
        "listings": listings.duplicate(true)
    }

func restore_data(data: Dictionary) -> void:
    if data.is_empty():
        return
    var saved_listings = data.get("listings", [])
    if saved_listings is Array:
        listings.clear()
        for item in saved_listings:
            if item is Dictionary:
                listings.append(item.duplicate(true))
    next_listing_id = max(1, int(data.get("next_listing_id", next_listing_id)))
    _recalculate_stats()
    market_changed.emit()

func get_market_stats(item_id: String = "") -> Dictionary:
    if item_id == "":
        return market_stats.duplicate(true)
    return Dictionary(market_stats.get(item_id, {})).duplicate(true)

func get_reference_price(item_id: String) -> int:
    var entry: Dictionary = catalog.get(item_id, {})
    var base := int(entry.get("base_price", 10))
    var stats: Dictionary = market_stats.get(item_id, {})
    var multiplier := float(stats.get("price_multiplier", 1.0))
    return max(1, int(round(base * multiplier)))

func get_price_range(item_id: String) -> Dictionary:
    var reference := get_reference_price(item_id)
    return {"min":max(1, int(reference * PRICE_FLOOR)), "max":max(1, int(reference * PRICE_CEILING)), "reference":reference}

func _recalculate_stats() -> void:
    market_stats.clear()
    for item_id in catalog.keys():
        var entry: Dictionary = catalog[item_id]
        var supply := 0
        var listed_value := 0
        for listing in listings:
            if str(listing.item) == str(item_id):
                supply += int(listing.quantity)
                listed_value += int(listing.quantity) * int(listing.unit_price)
        var target_demand := float(entry.get("target_demand", 100))
        var scarcity: float = clampf(target_demand / float(maxi(1, supply)), 0.55, 1.9)
        var activity := 1.0
        if state != null:
            activity += clamp(float(state.population) / 5000.0, 0.0, 0.7)
            activity += clamp(float(state.traffic_vehicle_count) / 120.0, 0.0, 0.35)
        var multiplier: float = clampf(scarcity * activity, PRICE_FLOOR, PRICE_CEILING)
        market_stats[item_id] = {
            "supply": supply,
            "target_demand": int(target_demand),
            "demand_index": target_demand / float(max(1, supply)),
            "price_multiplier": multiplier,
            "reference_price": max(1, int(round(int(entry.get("base_price", 10)) * multiplier))),
            "listed_value": listed_value
        }
