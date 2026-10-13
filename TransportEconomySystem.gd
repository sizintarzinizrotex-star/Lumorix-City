class_name LumorixTransportEconomySystem
extends Node

# Lightweight airport/port/intercity trade loop. Designed for mobile-first simulation;
# detailed vehicles can later be layered on top without changing the economy API.
var state: Node
var elapsed := 0.0
var report_timer := 0.0
var airport_passengers := 0
var airport_ticket_income := 0
var port_cargo_units := 0
var port_trade_income := 0
var export_units := 0
var import_units := 0
var metro_passengers := 0
var train_passengers := 0
var bus_passengers := 0
var transit_income := 0
var transit_timer := 0.0
var transfer_count := 0
var waiting_passengers := 0
var peak_load := 0.0

func initialize(game_state: Node = null) -> void:
    state = game_state
    airport_passengers = 0
    airport_ticket_income = 0
    port_cargo_units = 0
    port_trade_income = 0
    export_units = 0
    import_units = 0
    if state != null:
        state.airport_passenger_count = 0
        state.airport_ticket_income = 0
        state.port_cargo_units = 0
        state.port_trade_income = 0
        state.city_export_units = 0
        state.city_import_units = 0
        state.metro_passenger_count = 0
        state.train_passenger_count = 0
        state.bus_passenger_count = 0
        state.transit_income = 0

func _process(delta: float) -> void:
    if state == null:
        return
    elapsed += delta
    report_timer += delta
    _simulate_public_transport(delta)
    _simulate_airport(delta)
    _simulate_port_trade(delta)
    if report_timer >= 30.0:
        report_timer = 0.0
        _report_activity()


func _simulate_public_transport(delta: float) -> void:
    # Grouped passenger simulation keeps mobile performance predictable.
    var mobility: float = clampf((float(state.population) / 1200.0) * (float(state.citizen_mobility_demand) + 0.45), 0.15, 8.0)
    var metro_capacity: float = _building_capacity(["metro", "premium_metro_station"], 50.0)
    var train_capacity: float = _building_capacity(["train_station", "premium_train_station"], 80.0)
    var bus_capacity: float = clampf(float(state.traffic_vehicle_count) * 0.08 + float(state.population) * 0.018, 15.0, 600.0)
    var metro: int = int(minf(metro_capacity, mobility * 0.65) * delta * 0.08)
    var train: int = int(minf(train_capacity, mobility * 0.42) * delta * 0.045)
    var bus: int = int(minf(bus_capacity, mobility * 0.55) * delta * 0.11)
    var transfer_candidates: int = int(minf(float(metro + train), mobility * 0.08) * delta * 0.35)
    var waiting: int = int(maxf(0.0, mobility * 1.8 - float(metro + train + bus)) * delta)
    transfer_count += max(transfer_candidates, 0)
    waiting_passengers = clamp(waiting, 0, 9999)
    peak_load = max(peak_load, float(metro + train + bus))
    var total_capacity: float = maxf(1.0, metro_capacity + train_capacity + bus_capacity)
    var station_load: float = clampf(float(metro + train + bus) / total_capacity, 0.0, 1.5)
    var service_pressure: float = clampf(float(waiting_passengers) / maxf(1.0, mobility * 2.0), 0.0, 3.0)
    var transfer_pressure: float = clampf(float(transfer_candidates) / maxf(1.0, float(metro + train)), 0.0, 1.0)
    metro_passengers += max(metro, 0)
    train_passengers += max(train, 0)
    bus_passengers += max(bus, 0)
    var income: int = maxi(metro, 0) * 2 + maxi(train, 0) * 4 + maxi(bus, 0)
    transit_income += income
    if income > 0:
        state.add_lucb(income)
    state.metro_passenger_count = metro_passengers
    state.train_passenger_count = train_passengers
    state.bus_passenger_count = bus_passengers
    state.transit_income = transit_income
    state.transit_transfer_count = transfer_count
    state.transit_waiting_passengers = waiting_passengers
    state.transit_peak_load = peak_load
    state.transit_station_load = station_load
    state.transit_service_pressure = service_pressure
    state.transit_transfer_pressure = transfer_pressure

func _building_capacity(types: Array[String], base_capacity: float) -> float:
    var capacity := 0.0
    for building in state.buildings:
        var kind := str(building.get("type", ""))
        if types.has(kind):
            var level: int = clampi(int(building.get("lwl", 1)), 1, 20)
            capacity += base_capacity * (1.0 + float(level - 1) * 0.25)
    return capacity

func _simulate_airport(delta: float) -> void:
    var airport_factor := _building_factor(["airport", "mega_airport"])
    if airport_factor <= 0.0:
        return
    var demand: float = clampf((float(state.population) / 1200.0) * (float(state.happiness) / 75.0), 0.15, 6.0)
    var passenger_rate: float = 0.10 * demand * airport_factor
    var passengers := int(passenger_rate * delta)
    if passengers <= 0:
        return
    airport_passengers += passengers
    var ticket_income := passengers * (3 + int(airport_factor * 2.0))
    airport_ticket_income += ticket_income
    state.add_lucb(ticket_income)
    state.airport_passenger_count = airport_passengers
    state.airport_ticket_income = airport_ticket_income

func _simulate_port_trade(delta: float) -> void:
    var port_factor: float = _building_factor(["port", "mega_port"])
    if port_factor <= 0.0:
        return
    var industrial: float = clampf(float(state.jobs) / 900.0, 0.25, 6.0)
    var demand: float = clampf((float(state.population) / 1250.0) * 0.65 + industrial * 0.9, 0.25, 8.0)
    var cargo := int(0.08 * demand * port_factor * delta)
    if cargo <= 0:
        return
    port_cargo_units += cargo
    var imports: int = maxi(1, int(ceil(float(cargo) * 0.55)))
    var exports: int = maxi(0, cargo - imports)
    import_units += imports
    export_units += exports
    # Trade value scales with city production and transport demand without creating runaway income.
    var trade_income := cargo * (4 + int(port_factor * 2.0))
    port_trade_income += trade_income
    state.add_lucb(trade_income)
    state.port_cargo_units = port_cargo_units
    state.port_trade_income = port_trade_income
    state.city_import_units = import_units
    state.city_export_units = export_units

func _building_factor(types: Array[String]) -> float:
    if state == null:
        return 0.0
    var factor: float = 0.0
    for building in state.buildings:
        var kind := str(building.get("type", ""))
        if types.has(kind):
            var level: int = clampi(int(building.get("lwl", 1)), 1, 20)
            factor += 0.5 + float(level) * 0.12
    return factor

func _report_activity() -> void:
    if state == null:
        return
    if airport_passengers > 0:
        state.city_message.emit("✈️ Şehir hava yollarında %d yolcu taşındı." % airport_passengers, "info")
    if port_cargo_units > 0:
        state.city_message.emit("🚢 Liman ticaretinde %d kargo birimi işlendi." % port_cargo_units, "info")
