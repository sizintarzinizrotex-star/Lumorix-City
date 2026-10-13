class_name LumorixInteractiveBuildingSystem
extends Node

signal interior_requested(building_id: String)
signal interaction_info(building_id: String, description: String)
signal interior_opened(building_id: String)
signal interior_closed(building_id: String)
var current_building := ""
var camera: Camera3D
var interior_root: Node3D
var saved_camera_position := Vector3.ZERO
var saved_camera_rotation := Vector3.ZERO
var saved_camera_fov := 70.0

func setup(target_camera: Camera3D) -> void:
    camera = target_camera

func open_building(building_id: String) -> void:
    current_building = building_id
    interior_requested.emit(building_id)
    interaction_info.emit(building_id, get_interaction_description(building_id))
    if building_id in ["mall", "premium_mall", "stadium", "mega_stadium", "hospital", "special_hospital", "school", "special_university", "airport", "mega_airport", "port", "mega_port", "gas_station", "premium_gas_station", "automotive_dealership", "premium_automotive_dealership"]:
        open_interior(building_id)

func open_interior(building_id: String) -> void:
    if camera == null or interior_root != null:
        return
    saved_camera_position = camera.global_position
    saved_camera_rotation = camera.global_rotation
    saved_camera_fov = camera.fov
    interior_root = Node3D.new()
    interior_root.name = "InteriorView"
    get_tree().current_scene.add_child(interior_root)
    var view: Node3D
    if "gas_station" in building_id:
        view = LumorixProceduralAssetFactory.gas_station_interior()
    elif "automotive_dealership" in building_id:
        view = LumorixProceduralAssetFactory.dealership_interior()
    elif "mall" in building_id:
        view = LumorixProceduralAssetFactory.mall_interior()
    elif "stadium" in building_id:
        view = LumorixProceduralAssetFactory.stadium_interior()
    elif "hospital" in building_id:
        view = LumorixProceduralAssetFactory.hospital_interior()
    elif "school" in building_id or "university" in building_id:
        view = LumorixProceduralAssetFactory.school_interior()
    elif "airport" in building_id:
        view = LumorixProceduralAssetFactory.airport_interior()
    else:
        view = LumorixProceduralAssetFactory.port_interior()
    interior_root.add_child(view)
    interior_root.position = Vector3(0, 30, 0)
    camera.global_position = Vector3(0, 35, 16)
    camera.global_rotation_degrees = Vector3(-18, 0, 180)
    camera.fov = 62.0
    interior_opened.emit(building_id)

func close_interior() -> void:
    if camera == null or interior_root == null:
        return
    camera.global_position = saved_camera_position
    camera.global_rotation = saved_camera_rotation
    camera.fov = saved_camera_fov
    interior_root.queue_free()
    interior_root = null
    var old := current_building
    current_building = ""
    interior_closed.emit(old)

func is_inside() -> bool:
    return interior_root != null

func get_interaction_description(building_id: String) -> String:
    match building_id:
        "mall", "premium_mall":
            return "AVM içi: mağazalar, restoranlar, yürüyen merdivenler ve ziyaretçiler."
        "stadium", "mega_stadium":
            return "Stadyum içi: tribünler, seyirciler, skor tabelası ve maç."
        "hospital", "special_hospital":
            return "Hastane içi: hastalar, personel, yataklar ve acil servis."
        "school", "special_university":
            return "Eğitim içi: öğrenciler, öğretmenler ve eğitim hizmetleri."
        "airport", "mega_airport":
            return "Havalimanı: yolcular, kapılar, uçaklar ve uçuş rotaları."
        "port", "mega_port":
            return "Liman: kargo, yolcular, gemiler ve yükleme operasyonları."
        "gas_station", "premium_gas_station":
            return "Benzin istasyonu içi: market, yakıt pompaları, servis alanı ve araç operasyonları."
        "automotive_dealership", "premium_automotive_dealership":
            return "Otomotiv bayisi içi: showroom, araç sergisi, satış masası ve servis alanı."
        "concert_area":
            return "Lumorix Konser Alanı: sahne, seyirciler, etkinlik hazırlığı ve şehir eğlencesi."
        "rally_area":
            return "Lumorix Halk/Miting Alanı: başkan konuşmaları, vatandaş kalabalığı ve şehir duyuruları."
        "premium_concert_area":
            return "Lumorix Süper Konser Alanı: sahne, özel ışık gösterisi, kalabalık ve premium etkinlik."
        "premium_rally_area":
            return "Lumorix Süper Miting Alanı: başkan konuşması, premium etkinlik alanı ve vatandaş buluşması."
        _:
            return "Bu yapı için etkileşimli detaylar hazırlanıyor."
