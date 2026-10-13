class_name LumorixTaxSystem
extends Node

signal tax_collected(amount: int, breakdown: Dictionary)

var state: Node
var interval := 10.0
var accumulator := 0.0
var last_breakdown: Dictionary = {}
var last_budget: Dictionary = {}
var rules := {
    "brackets": [
        {"max":20, "rate":1.5, "mult":1.0},
        {"max":25, "rate":2.0, "mult":1.15},
        {"max":35, "rate":2.5, "mult":1.35},
        {"max":999, "rate":3.0, "mult":1.6}
    ]
}

func initialize(game_state: Node) -> void:
    state = game_state
    interval = 10.0

func _process(delta: float) -> void:
    if state == null:
        return
    accumulator += delta
    if accumulator >= interval:
        accumulator = 0.0
        collect_taxes()

func get_development_lwl() -> float:
    if state == null:
        return 1.0
    var total_lwl := 0.0
    var count := 0
    for b in state.buildings:
        if b is Dictionary:
            total_lwl += float(b.get("lwl", 1))
            count += 1
    var avg_lwl: float = total_lwl / max(1, count)
    var population_component: float = float(state.population) / 500.0
    var transport_component: float = float(state.traffic) / 20.0
    var service_component: float = (float(state.health) + float(state.education) + float(state.safety)) / 60.0
    return clamp(avg_lwl * 1.8 + population_component + transport_component + service_component, 1.0, 60.0)

func get_tax_bracket() -> Dictionary:
    var development := get_development_lwl()
    for bracket in rules.brackets:
        if development <= float(bracket.max):
            return {"development_lwl": development, "rate_percent": bracket.rate, "multiplier": bracket.mult, "max": bracket.max}
    return rules.brackets[-1]

func calculate_tax_breakdown() -> Dictionary:
    if state == null:
        return {}
    var bracket := get_tax_bracket()
    var population := float(state.population)
    var jobs := float(state.jobs)
    var happiness_factor: float = 0.65 + float(state.happiness) / 200.0
    var safety_factor: float = 0.85 + float(state.safety) / 400.0
    var environment_factor: float = 0.85 + float(state.environment) / 500.0
    var service_factor: float = 0.75 + (float(state.health) + float(state.education)) / 400.0
    var base := population * 4.2 + jobs * 1.35
    var economic_activity: float = base * (float(bracket.rate_percent) / 1.5) * bracket.multiplier * happiness_factor * safety_factor * environment_factor * service_factor
    var transport_income: float = maxf(0.0, population * maxf(0.0, float(state.traffic)) * 0.055)
    var tourism_income: float = maxf(0.0, population * maxf(0.0, float(state.happiness) - 55.0) * 0.018)
    var gross := int(max(1.0, economic_activity + transport_income + tourism_income))
    var infra := state.get_parent().get_node_or_null("InfrastructureSystem")
    var maintenance := 0
    if infra != null:
        maintenance = int(infra.get_budget_snapshot().get("maintenance", 0)) * 2
    var transport_cost := int(max(0.0, population * max(0.0, 100.0 - float(state.traffic)) * 0.012))
    var municipal_cost := maintenance + transport_cost
    var net := gross - municipal_cost
    return {
        "total": net,
        "gross": gross,
        "maintenance": maintenance,
        "transport_cost": transport_cost,
        "development_lwl": float(bracket.development_lwl),
        "rate_percent": float(bracket.rate_percent),
        "residential": int(gross * 0.42),
        "commercial": int(gross * 0.24),
        "industrial": int(gross * 0.20),
        "transport": int(transport_income),
        "tourism": int(tourism_income)
    }

func collect_taxes() -> int:
    var breakdown := calculate_tax_breakdown()
    if breakdown.is_empty():
        return 0
    var amount := int(breakdown.get("total", 0))
    state.tax_last_gross = int(breakdown.get("gross", amount))
    state.municipal_maintenance = int(breakdown.get("maintenance", 0))
    state.municipal_net = amount
    state.budget_deficit = amount < 0
    if amount >= 0:
        state.add_lucb(amount)
    else:
        state.lucb = max(0, state.lucb + amount)
        state.state_changed.emit()
        state.city_message.emit("⚠️ Belediye bütçesi açık verdi: %s LuCB" % str(abs(amount)), "danger")
    state.city_development_lwl = float(breakdown.get("development_lwl", 1.0))
    state.tax_last_collection = amount
    last_breakdown = breakdown
    tax_collected.emit(amount, breakdown)
    return amount
