extends Node3D

var city_visual_detail_system: Node3D
var city_visual_quality_system: Node3D
var phase2_final_visual_system: Node3D
var phase3_city_life_system: Node3D
var phase4_construction_transport_system: Node3D
var phase5_economy_system: Node
var mobile_optimization_system: Node


func _ready() -> void:
    var game_state := $GameState
    game_state.initialize_new_city()
    $StoreSystem.load_catalog()
    $AccountSystem.initialize(game_state)
    $CityAddressSystem.initialize(game_state)
    $CityWorld.build_world(game_state)
    $CityWorld.building_selected.connect($UI._on_building_selected)
    $RoadNetworkSystem.initialize($CityWorld.world_root)

    city_visual_detail_system = load("res://CityVisualDetailSystem.gd").new()
    city_visual_detail_system.name = "CityVisualDetailSystem"
    add_child(city_visual_detail_system)
    city_visual_detail_system.initialize($CityWorld.world_root, $RoadNetworkSystem, game_state)

    city_visual_quality_system = load("res://CityVisualQualitySystem.gd").new()
    city_visual_quality_system.name = "CityVisualQualitySystem"
    add_child(city_visual_quality_system)
    city_visual_quality_system.initialize($CityWorld.world_root, $RoadNetworkSystem, game_state)

    phase2_final_visual_system = load("res://Phase2FinalVisualSystem.gd").new()
    phase2_final_visual_system.name = "Phase2FinalVisualSystem"
    add_child(phase2_final_visual_system)
    phase2_final_visual_system.initialize($CityWorld.world_root, $RoadNetworkSystem, game_state)

    phase3_city_life_system = load("res://Phase3CityLifeSystem.gd").new()
    phase3_city_life_system.name = "Phase3CityLifeSystem"
    add_child(phase3_city_life_system)
    phase3_city_life_system.initialize($CityWorld.world_root, game_state)

    phase4_construction_transport_system = load("res://Phase4ConstructionTransportSystem.gd").new()
    phase4_construction_transport_system.name = "Phase4ConstructionTransportSystem"
    add_child(phase4_construction_transport_system)
    phase4_construction_transport_system.initialize($CityWorld.world_root, game_state)

    phase5_economy_system = load("res://Phase5EconomySystem.gd").new()
    phase5_economy_system.name = "Phase5EconomySystem"
    add_child(phase5_economy_system)
    mobile_optimization_system = load("res://MobileOptimizationSystem.gd").new()
    mobile_optimization_system.name = "MobileOptimizationSystem"
    add_child(mobile_optimization_system)
    mobile_optimization_system.initialize($CityWorld.world_root, game_state)

    phase5_economy_system.initialize(
        game_state,
        $ProductionSystem,
        $MarketSystem,
        $TaxSystem,
        $StoreSystem,
        $UpgradeSystem,
        $VehicleEconomySystem,
        $TransportEconomySystem
    )


    $CitizenSystem.initialize($CityWorld, game_state)
    $TrafficSystem.initialize(game_state, $RoadNetworkSystem)
    $CitySimulation.initialize(game_state)
    $CitySimulation.simulation_message.connect(_on_simulation_message)
    $CityEvents.initialize(game_state)
    $DayNightSystem.initialize(game_state, $WorldEnvironment, $Sun)
    $WeatherSystem.initialize(game_state)
    $QuestAchievementSystem.initialize(game_state)
    $FriendSystem.initialize(game_state)
    $InfrastructureSystem.initialize(game_state)
    $ProductionSystem.initialize(game_state)
    $MarketSystem.initialize(game_state, $ProductionSystem)
    $TaxSystem.initialize(game_state)
    $TaxSystem.tax_collected.connect(_on_tax_collected)
    $TerrainExpansionSystem.initialize(game_state, $CityWorld)
    $ServiceVehicleSystem.initialize(game_state, $CityWorld)
    $VehicleEconomySystem.initialize(game_state)
    $TransportEconomySystem.initialize(game_state)
    $LumorixDeliverySystem.initialize(game_state)
    $LandValueSystem.initialize(game_state, $CityWorld)
    $TerrainExpansionSystem.parcel_selected.connect($UI._on_terrain_parcel_selected)
    $UpgradeSystem.initialize(game_state, $ProductionSystem)
    $CitizenLifeSystem.initialize(game_state)
    $CitizenLifeSystem.citizen_event.connect(_on_citizen_event)
    $UpgradeSystem.upgrade_completed.connect(_on_upgrade_completed)
    $UpgradeSystem.upgrade_blocked.connect(_on_upgrade_blocked)
    $ProductionSystem.production_completed.connect(_on_production_completed)
    $QuestAchievementSystem.quest_completed.connect(_on_quest_completed)
    $QuestAchievementSystem.achievement_unlocked.connect(_on_achievement_unlocked)
    $WeatherSystem.weather_changed.connect(_on_weather_changed)
    $FriendSystem.friend_message.connect(_on_friend_message)
    $InteractiveBuildingSystem.interaction_info.connect(_on_interaction_info)
    $InteractiveBuildingSystem.setup($CameraController)
    $InteractiveBuildingSystem.interior_opened.connect($UI._on_interior_opened)
    $InteractiveBuildingSystem.interior_closed.connect($UI._on_interior_closed)
    $SaveSystem.load_city(game_state)
    $CityWorld.set_construction_slot_capacity(5 if game_state.premium_owned.has("premium_crane_pack") else 3)
    if game_state.premium_owned.has("premium_concert_area"):
        $CityWorld.activate_premium_event_area("premium_concert_area")
    if game_state.premium_owned.has("premium_rally_area"):
        $CityWorld.activate_premium_event_area("premium_rally_area")
    for premium_id in game_state.premium_owned.keys():
        $CityWorld.activate_premium_catalog_item(str(premium_id))
    $UI.show_opening_speech()

func _process(delta: float) -> void:
    $GameState.tick_day(delta)
    if Engine.get_process_frames() % 600 == 0:
        $SaveSystem.save_city($GameState)
        $AccountSystem.save_account()

func _on_simulation_message(message: String, severity: String) -> void:
    $GameState.city_message.emit(message, severity)

func _on_quest_completed(_id: String, title: String) -> void:
    $GameState.city_message.emit("🎯 Görev tamamlandı: %s" % title, "success")

func _on_achievement_unlocked(_id: String, title: String) -> void:
    $GameState.city_message.emit("🏆 Başarım açıldı: %s" % title, "success")

func _on_weather_changed(weather_name: String, _intensity: float) -> void:
    var labels := {"clear":"Açık hava", "cloudy":"Bulutlu hava", "rain":"Yağmur başladı", "storm":"Fırtına başladı"}
    $GameState.city_message.emit("🌦️ %s" % labels.get(weather_name, weather_name), "info")

func _on_friend_message(message: String, severity: String) -> void:
    $GameState.city_message.emit(message, severity)


func _on_citizen_event(message: String, severity: String) -> void:
    $GameState.city_message.emit(message, severity)

func _on_upgrade_completed(building_id: String, new_level: int) -> void:
    $CityWorld.apply_building_upgrade_visual(building_id, new_level)
    $GameState.city_message.emit("🔧 %s yükseltildi: LWL %d — şehirde yapı seviyesi görsel olarak yenilendi." % [building_id, new_level], "success")

func _on_production_completed(_recipe_id: String, item_id: String, quantity: int) -> void:
    $GameState.city_message.emit("🏭 Üretim tamamlandı: %s ×%d" % [item_id, quantity], "success")

func _on_upgrade_blocked(building_id: String, reason: String) -> void:
    $GameState.city_message.emit("%s yükseltilemedi: %s" % [building_id, reason], "warning")

func _on_interaction_info(building_id: String, description: String) -> void:
    $GameState.city_message.emit("🏢 %s — %s" % [building_id, description], "info")

func _on_tax_collected(amount: int, breakdown: Dictionary) -> void:
    $GameState.city_message.emit("💰 Vergi toplandı: +%s LuCB | Gelişim %.1f LWL | Oran %.1f%%" % [str(amount), float(breakdown.get("development_lwl", 0.0)), float(breakdown.get("rate_percent", 0.0))], "success")
