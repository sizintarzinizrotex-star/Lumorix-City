class_name LumorixVehicleEconomySystem
extends Node

# Lightweight vehicle economy loop: fuel demand, tanker deliveries and dealership activity.
var state: Node
var elapsed := 0.0
var report_timer := 0.0
var fuel_demand := 0.0
var fuel_deliveries := 0
var dealership_sales := 0
var fuel_income := 0
var dealership_income := 0

func initialize(game_state: Node = null) -> void:
    state = game_state
    fuel_demand = 0.0
    fuel_deliveries = 0
    dealership_sales = 0
    fuel_income = 0
    dealership_income = 0

func _process(delta: float) -> void:
    if state == null:
        return
    elapsed += delta
    report_timer += delta
    _simulate_vehicle_economy(delta)
    if report_timer >= 30.0:
        report_timer = 0.0
        _report_activity()

func _simulate_vehicle_economy(delta: float) -> void:
    var traffic_factor: float = clampf(float(state.traffic_vehicle_count) / 30.0, 0.25, 3.0)
    var population_factor: float = clampf(float(state.population) / 1250.0, 0.5, 4.0)
    fuel_demand = traffic_factor * population_factor
    state.fuel_demand_index = fuel_demand

    # Fuel stations earn LuCB from simulated refuelling activity.
    var fuel_rate: float = 0.16 * fuel_demand
    var fuel_gain := int(fuel_rate * delta)
    if fuel_gain > 0:
        fuel_income += fuel_gain
        state.fuel_income = fuel_income
        state.add_lucb(fuel_gain)

    # Dealership activity follows population, jobs and city happiness.
    var dealership_factor: float = clampf((float(state.population) / 1500.0) + (float(state.jobs) / 1200.0), 0.2, 5.0)
    dealership_factor *= clampf(float(state.happiness) / 75.0, 0.45, 1.5)
    var sale_chance: float = 0.012 * dealership_factor * delta
    if randf() < sale_chance:
        dealership_sales += 1
        var sale_value := 18 + int(dealership_factor * 6.0)
        dealership_income += sale_value
        state.dealership_sales_count = dealership_sales
        state.dealership_income = dealership_income
        state.add_lucb(sale_value)

func register_fuel_delivery() -> void:
    fuel_deliveries += 1
    if state != null:
        state.city_message.emit("⛽ Yakıt tankeri benzin istasyonuna yakıt teslim etti.", "info")

func _report_activity() -> void:
    if state == null:
        return
    if fuel_demand > 1.6:
        state.city_message.emit("⛽ Yakıt talebi arttı; istasyonlarda araç yoğunluğu yükseliyor.", "info")
    if dealership_sales > 0:
        state.city_message.emit("🚗 Otomotiv bayilerinde %d araç satışı gerçekleşti." % dealership_sales, "success")
