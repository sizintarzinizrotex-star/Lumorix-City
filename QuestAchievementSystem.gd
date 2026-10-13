class_name LumorixQuestAchievementSystem
extends Node

signal quest_completed(id: String, title: String)
signal achievement_unlocked(id: String, title: String)

var state: Node
var quests := {
    "first_city": {"title":"İlk Şehir", "done":false},
    "market_sale": {"title":"İlk Pazar Satışı", "done":false},
    "population_5000": {"title":"Büyüyen Şehir", "done":false},
    "happiness_85": {"title":"Mutlu Şehir", "done":false}
}
var achievements := {
    "builder": {"title":"Şehir Kurucusu", "done":false},
    "transport": {"title":"Ulaşım Ustası", "done":false},
    "premium_owner": {"title":"Premium Koleksiyoner", "done":false}
}
var tick := 0.0

func initialize(game_state: Node) -> void:
    state = game_state

func _process(delta: float) -> void:
    if state == null:
        return
    tick += delta
    if tick < 5.0:
        return
    tick = 0.0
    _evaluate()

func _evaluate() -> void:
    if not quests.first_city.done and state.buildings.size() >= 1:
        _complete_quest("first_city")
    if not quests.population_5000.done and state.population >= 5000:
        _complete_quest("population_5000")
    if not quests.happiness_85.done and state.happiness >= 85:
        _complete_quest("happiness_85")
    if not achievements.builder.done and state.buildings.size() >= 10:
        _unlock("builder")
    if not achievements.transport.done and state.traffic >= 80:
        _unlock("transport")
    if not achievements.premium_owner.done and state.premium_owned.size() > 0:
        _unlock("premium_owner")

func _complete_quest(id: String) -> void:
    quests[id].done = true
    quest_completed.emit(id, quests[id].title)

func _unlock(id: String) -> void:
    achievements[id].done = true
    achievement_unlocked.emit(id, achievements[id].title)
