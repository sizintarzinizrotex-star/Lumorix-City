extends CanvasLayer

var state: Node
var info_label: Label
var message_label: Label
var time_label: Label
var stats_label: Label
var toast_timer := 0.0
var overlay: Panel
var overlay_title: Label
var overlay_body: VBoxContainer
var overlay_scroll: ScrollContainer
var selected_building: Node
var interior_system: Node

func _ready() -> void:
    state = get_parent().get_node("GameState")
    interior_system = get_parent().get_node("InteractiveBuildingSystem")
    state.state_changed.connect(_refresh)
    state.city_message.connect(_message)
    _build_ui()
    _refresh()

func _panel(parent: Node, pos: Vector2, size: Vector2, color: Color) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    p.add_theme_stylebox_override("panel", style)
    parent.add_child(p)
    return p

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 40)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _build_ui() -> void:
    var top := _panel(self, Vector2(18, 18), Vector2(760, 108), Color(0.02, 0.08, 0.15, 0.93))
    info_label = Label.new()
    info_label.position = Vector2(16, 12)
    info_label.add_theme_font_size_override("font_size", 18)
    top.add_child(info_label)

    var brand := Label.new()
    brand.text = "LUMORIX\nGAMER STUDIO"
    brand.position = Vector2(1060, 20)
    brand.add_theme_font_size_override("font_size", 20)
    add_child(brand)

    var side := _panel(self, Vector2(1030, 120), Vector2(230, 245), Color(0.02, 0.08, 0.15, 0.88))
    var title := Label.new()
    title.text = "ŞEHİR DURUMU"
    title.position = Vector2(14, 12)
    title.add_theme_font_size_override("font_size", 18)
    side.add_child(title)
    stats_label = Label.new()
    stats_label.position = Vector2(14, 48)
    stats_label.add_theme_font_size_override("font_size", 15)
    side.add_child(stats_label)

    var menu := _panel(self, Vector2(18, 145), Vector2(220, 480), Color(0.02, 0.08, 0.15, 0.88))
    var mt := Label.new()
    mt.text = "OYUN MENÜSÜ"
    mt.position = Vector2(14, 10)
    mt.add_theme_font_size_override("font_size", 18)
    menu.add_child(mt)
    var box := VBoxContainer.new()
    box.position = Vector2(12, 45)
    box.size = Vector2(196, 420)
    box.add_theme_constant_override("separation", 7)
    menu.add_child(box)
    _button(box, "🏭 Üretim / Depo", func(): _open_production())
    _button(box, "🏪 Pazar", func(): _open_market())
    _button(box, "💎 Mağaza", func(): _open_store())
    _button(box, "👥 Arkadaşlar", func(): _open_friends())
    _button(box, "🎯 Görevler / Başarımlar", func(): _open_quests())
    _button(box, "🏙️ Şehir Bilgisi", func(): _open_city_info())
    _button(box, "🪧 İsimler / Adresler", func(): _open_address_editor())
    _button(box, "💰 Vergi / Belediye", func(): _open_tax())
    _button(box, "🌍 Arazi / Genişlet", func(): _open_terrain())
    _button(box, "🔧 Seçili Bina", func(): _open_selected_building())
    _button(box, "❌ Kapat", func(): _close_overlay())

    time_label = Label.new()
    time_label.position = Vector2(260, 650)
    time_label.add_theme_font_size_override("font_size", 18)
    add_child(time_label)

    message_label = Label.new()
    message_label.position = Vector2(260, 680)
    message_label.add_theme_font_size_override("font_size", 16)
    add_child(message_label)

    var hint := Label.new()
    hint.text = "WASD: Kamera   Q/E: Yakınlaş/Uzaklaş   Sol tık: Kamera / bina etkileşimi"
    hint.position = Vector2(260, 710)
    hint.add_theme_font_size_override("font_size", 13)
    add_child(hint)

    overlay = _panel(self, Vector2(260, 120), Vector2(700, 500), Color(0.015, 0.045, 0.08, 0.97))
    overlay.visible = false
    overlay_title = Label.new()
    overlay_title.position = Vector2(24, 18)
    overlay_title.add_theme_font_size_override("font_size", 24)
    overlay.add_child(overlay_title)
    overlay_scroll = ScrollContainer.new()
    overlay_scroll.position = Vector2(24, 62)
    overlay_scroll.size = Vector2(652, 380)
    overlay.add_child(overlay_scroll)
    overlay_body = VBoxContainer.new()
    overlay_body.custom_minimum_size = Vector2(630, 0)
    overlay_body.add_theme_constant_override("separation", 8)
    overlay_scroll.add_child(overlay_body)
    _button(overlay, "Kapat", func(): _close_overlay()).position = Vector2(570, 455)

func _clear_overlay() -> void:
    for child in overlay_body.get_children():
        child.queue_free()

func _label(text: String, size := 16) -> Label:
    var l := Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", size)
    l.custom_minimum_size = Vector2(0, 32)
    overlay_body.add_child(l)
    return l

func _open_production() -> void:
    overlay.visible = true
    overlay_title.text = "🏭 ÜRETİM / DEPO"
    _clear_overlay()
    var production := state.get_parent().get_node("ProductionSystem")
    _label("Hammadde → işlenmiş ürün → ekipman zinciri. Üretim tamamlandığında ürün depoya eklenir.")
    _label("DEPO", 18)
    var inv: Dictionary = production.get_inventory()
    for item in ["cement","steel","glass","electronics","machine","fuel","construction_equipment","motor_parts","train_equipment","ship_equipment","aircraft_equipment"]:
        _label("%s: %d" % [_item_name(item), int(inv.get(item, 0))], 14)
    _label("ÜRETİM", 18)
    for recipe_id in production.recipes.keys():
        var recipe: Dictionary = production.recipes[recipe_id]
        _button(overlay_body, "Üret: %s ×%d" % [str(recipe.name), int(recipe.output_quantity)], func():
            if production.start_production(str(recipe_id), 1):
                _message("Üretim başladı: %s" % str(recipe.name), "success")
        )
    if not production.get_active_jobs().is_empty():
        _label("Aktif üretimler: %d" % production.get_active_jobs().size(), 15)

func _open_market() -> void:
    overlay.visible = true
    overlay_title.text = "🏪 LUMORIX PAZAR"
    _clear_overlay()
    var market := state.get_parent().get_node("MarketSystem")
    var production := state.get_parent().get_node("ProductionSystem")
    _label("Üret → pazara koy → başka oyuncu satın alsın. Doğrudan LuCB hediye edilmez.")
    _label("📢 SABİT REKLAM ALANI — küçük LuCB ödülü", 15)
    _button(overlay_body, "📺 Reklam izle → +25 LuCB", func(): state.add_lucb(25); _message("Reklam ödülü: +25 LuCB", "success"))
    _label("İLAN OLUŞTUR", 18)
    var item_box := OptionButton.new()
    for item in ["cement","steel","glass","electronics","machine","fuel","construction_equipment","motor_parts","train_equipment","ship_equipment","aircraft_equipment"]:
        item_box.add_item(_item_name(item))
        item_box.set_item_metadata(item_box.item_count - 1, item)
    overlay_body.add_child(item_box)
    var qty := SpinBox.new()
    qty.min_value = 1
    qty.max_value = 5000
    qty.value = 10
    qty.step = 1
    overlay_body.add_child(qty)
    var price := SpinBox.new()
    price.min_value = 1
    price.max_value = 1000000
    price.value = 10
    price.step = 1
    overlay_body.add_child(price)
    _button(overlay_body, "📦 İlanı Pazara Koy", func():
        var item_id := str(item_box.get_selected_metadata())
        if market.create_listing(item_id, _item_name(item_id), int(qty.value), int(price.value)):
            _message("İlan 24 saatliğine pazara konuldu.", "success")
            _open_market()
    )
    var selected_item := str(item_box.get_selected_metadata())
    var price_range: Dictionary = market.get_price_range(selected_item)
    _label("📈 Dinamik referans fiyat: %s LuCB | Önerilen aralık: %s–%s LuCB" % [_num(int(price_range.get("reference", 0))), _num(int(price_range.get("min", 0))), _num(int(price_range.get("max", 0)))], 14)
    var stats: Dictionary = market.get_market_stats(selected_item)
    _label("Arz: %d | Hedef talep: %d | Talep endeksi: %.2f" % [int(stats.get("supply", 0)), int(stats.get("target_demand", 0)), float(stats.get("demand_index", 0.0))], 14)
    _label("AKTİF İLANLAR", 18)
    for listing in market.get_listings():
        var total: float = int(listing.quantity) * int(listing.unit_price)
        _button(overlay_body, "%s ×%d — %d LuCB toplam — satın al" % [str(listing.name), int(listing.quantity), total], func():
            if market.buy_listing(str(listing.id), int(listing.quantity)):
                _message("Pazar alışverişi tamamlandı.", "success")
                _open_market()
        )
    _label("İlan süresi 24 saat. Süresi dolan ilanlar otomatik kaldırılır.", 14)

func _item_name(item_id: String) -> String:
    var names := {"cement":"Çimento","steel":"Çelik","glass":"Cam","electronics":"Elektronik","machine":"Makine","fuel":"Yakıt","construction_equipment":"İnşaat Ekipmanı","motor_parts":"Motor Parçası","train_equipment":"Tren Ekipmanı","ship_equipment":"Gemi Ekipmanı","aircraft_equipment":"Uçak Ekipmanı"}
    return str(names.get(item_id, item_id))

func _open_store() -> void:
    overlay.visible = true
    overlay_title.text = "💎 LUMORIX MAĞAZA"
    _clear_overlay()
    _label("Premium içerikler kalıcıdır. Seçili premium yapılar doğrudan 20 LWL ve 500 LCB'dir.")
    _label("LCB/LuCB gerçek para satın alımları final mobil sürümde Google Play / App Store IAP üzerinden bağlanacaktır.", 14)
    var store := get_parent().get_node("StoreSystem")
    var catalog_status: Dictionary = store.get_catalog_validation()
    _label("🛡️ Mağaza veri doğrulaması: %s • Premium %d/%d • LCB %d • LuCB %d" % ["OK" if bool(catalog_status.get("valid", false)) else "HATA", int(catalog_status.get("premium_count", 0)), int(store.get_premium_items().size()), int(catalog_status.get("lcb_count", 0)), int(catalog_status.get("lucb_count", 0))], 13)
    _label("LCB Paketleri", 18)
    for item in store.get_currency_packages("lcb"):
        var amount := int(item.get("amount", 0))
        var price_try := int(item.get("price_try", 0))
        _button(overlay_body, "%s LCB — %s TL" % [_num(amount), _num(price_try)], func(): _message("Bu paket final mobil sürümde Google Play / App Store IAP'sine bağlanacak.", "info"))
    _label("LuCB Paketleri", 18)
    for item in store.get_currency_packages("lucb"):
        var amount := int(item.get("amount", 0))
        var price_try := int(item.get("price_try", 0))
        _button(overlay_body, "%s LuCB — %s TL" % [_num(amount), _num(price_try)], func(): _message("Bu paket final mobil sürümde Google Play / App Store IAP'sine bağlanacak.", "info"))
    _label("Premium katalog — seçili ürünler 20 LWL / 500 LCB", 18)
    var premium_items: Array = store.get_premium_items()
    for item in premium_items:
        var id := str(item.get("id", ""))
        var name := str(item.get("name", id))
        var price_lcb := int(item.get("price_lcb", 500))
        var level := int(item.get("level", 20))
        var locked := str(item.get("price_status", "locked")) == "locked"
        if id.is_empty():
            continue
        var price_text := "%d LCB / %d LWL" % [price_lcb, level]
        if locked:
            price_text += " 🔒"
        _button(overlay_body, "%s — %s" % [name, price_text], func(): _buy_premium(id))

func _buy_premium(id: String) -> void:
    var store := get_parent().get_node("StoreSystem")
    var catalog_status: Dictionary = store.get_catalog_validation()
    if not bool(catalog_status.get("valid", false)):
        _message("Mağaza kataloğu doğrulanamadı; satın alma güvenlik nedeniyle durduruldu.", "warning")
        return
    var item: Dictionary = store.get_premium_item(id)
    if item.is_empty():
        _message("Premium ürün kataloğunda bulunamadı.", "warning")
        return
    var price_lcb := int(item.get("price_lcb", 500))
    var price_status := str(item.get("price_status", "locked"))
    if price_status != "locked":
        _message("Bu premium ürünün fiyatı kilitli değil; mağaza güvenliği nedeniyle satın alma durduruldu.", "warning")
        return
    if state.buy_premium(id, price_lcb):
        get_parent().get_node("CityWorld").activate_premium_catalog_item(id)
        if id == "premium_crane_pack":
            _message("🏗️ Premium vinç paketi aktif: aynı anda 5 inşaat slotu kullanılabilir.", "success")
            return
        _message("💎 %s kalıcı premium olarak hesabına eklendi ve şehirde aktif edildi." % str(item.get("name", id)), "success")
    else:
        _message("Premium satın alma tamamlanamadı veya ürün zaten sende." , "warning")

func _on_interior_opened(building_id: String) -> void:
    overlay.visible = true
    overlay_title.text = "🏢 %s İÇİ" % building_id
    _clear_overlay()
    _label("İç mekân görünümündesin. Burada yapının özel alanlarını inceleyebilirsin.", 17)
    if building_id in ["gas_station", "premium_gas_station"]:
        _label("⛽ Market • Yakıt pompaları • Servis alanı • Araç operasyonları", 16)
    else:
        _label("🚗 Showroom • Araç sergisi • Satış masası • Servis alanı", 16)
    _button(overlay_body, "↩️ Şehre dön", func(): interior_system.close_interior())

func _on_interior_closed(_building_id: String) -> void:
    overlay.visible = false

func _open_friends() -> void:
    overlay.visible = true
    overlay_title.text = "👥 ARKADAŞLAR"
    _clear_overlay()
    _label("Arkadaş ziyareti salt-okunur güvenli moddur. Ziyaretçi şehir sahibinin ekonomisini veya binalarını değiştiremez.")
    var id_edit := LineEdit.new()
    id_edit.placeholder_text = "Oyuncu ID"
    overlay_body.add_child(id_edit)
    var city_edit := LineEdit.new()
    city_edit.placeholder_text = "Şehir ID"
    overlay_body.add_child(city_edit)
    var name_edit := LineEdit.new()
    name_edit.placeholder_text = "Görünen ad"
    overlay_body.add_child(name_edit)
    _button(overlay_body, "➕ Arkadaş ekle", func():
        if state.get_parent().get_node("FriendSystem").add_friend(id_edit.text, city_edit.text, name_edit.text):
            _message("Arkadaş eklendi.", "success")
    )
    var friend_system := state.get_parent().get_node("FriendSystem")
    _label("Arkadaş sistemi: güvenli ziyaret, yardım, kaynak hediyesi ve sohbet.", 15)
    _label("ARKADAŞLAR", 18)
    for friend in friend_system.get_friends():
        var pid := str(friend.get("player_id", ""))
        var display := str(friend.get("display_name", pid))
        _label("👤 %s  •  %s" % [display, pid], 14)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        overlay_body.add_child(row)
        var visit_id := pid
        _button(row, "🏙️ Ziyaret", func():
            if friend_system.visit_friend(visit_id):
                _message("Güvenli arkadaş ziyareti başladı.", "info")
        )
        _button(row, "🤝 Yardım", func():
            friend_system.send_help(visit_id, "Şehir desteği")
        )
        _button(row, "🎁 10 Çimento", func():
            friend_system.send_resource_gift(visit_id, "cement", 10)
        )
        var chat_id := pid
        var chat_edit := LineEdit.new()
        chat_edit.placeholder_text = "Mesaj"
        row.add_child(chat_edit)
        _button(row, "💬 Gönder", func():
            friend_system.send_chat(chat_id, chat_edit.text)
            chat_edit.clear()
        )
    if friend_system.is_visiting_friend():
        _label("🔒 ZİYARET MODU AKTİF — Şehir değiştirilemez.", 15)
        _button(overlay_body, "🚪 Ziyaretten çık", func():
            friend_system.leave_friend_visit()
            _open_friends()
        )

func _open_quests() -> void:
    overlay.visible = true
    overlay_title.text = "🎯 GÖREVLER / BAŞARIMLAR"
    _clear_overlay()
    var qs = state.get_parent().get_node("QuestAchievementSystem").quests
    _label("Görevler", 18)
    for id in qs:
        _label("%s  %s" % ["✅" if qs[id].done else "⬜", qs[id].title], 15)
    var ach = state.get_parent().get_node("QuestAchievementSystem").achievements
    _label("Başarımlar", 18)
    for id in ach:
        _label("%s  %s" % ["🏆" if ach[id].done else "⬜", ach[id].title], 15)

func _open_terrain() -> void:
    overlay.visible = true
    overlay_title.text = "🌍 ARAZİ GENİŞLETME / DÜZENLEME"
    _clear_overlay()
    var terrain := state.get_parent().get_node("TerrainExpansionSystem")
    _label("Yeni bölgelerde dağ, orman, kaya ve taş engelleri olabilir. Önce araziyi aç, sonra üzerine tıklayıp Araziyi Düzenle işlemini başlat.", 15)
    for id in terrain.get_parcels().keys():
        var parcel: Dictionary = terrain.get_parcels()[id]
        var status := "AÇIK" if bool(parcel.unlocked) else "KİLİTLİ"
        if bool(parcel.buildable):
            status = "HAZIR"
        _label("%s — %s — %s" % [id, str(parcel.terrain).capitalize(), status], 14)
        if not bool(parcel.unlocked):
            var parcel_id := str(id)
            _button(overlay_body, "🔓 %s aç" % parcel_id, func():
                if terrain.unlock_parcel(parcel_id):
                    _open_terrain()
            )
        elif not bool(parcel.buildable):
            var parcel_id2 := str(id)
            _button(overlay_body, "🚜 %s — Makine Seç / Düzenle" % parcel_id2, func():
                _open_terrain_parcel(parcel_id2)
            )
    _label("Düzenleme sırasında makine, yakıt ve LuCB tüketilir; işlem küçük bir süreli simülasyon olarak çalışır.", 14)

func _on_terrain_parcel_selected(parcel_id: String) -> void:
    _open_terrain_parcel(parcel_id)

func _open_terrain_parcel(parcel_id: String) -> void:
    var terrain := state.get_parent().get_node("TerrainExpansionSystem")
    var parcels: Dictionary = terrain.get_parcels()
    if not parcels.has(parcel_id):
        return
    var parcel: Dictionary = parcels[parcel_id]
    overlay.visible = true
    overlay_title.text = "🌍 %s" % parcel_id
    _clear_overlay()
    _label("Arazi türü: %s\nEngeller: %d\nDurum: %s" % [str(parcel.terrain).capitalize(), parcel.obstacles.size(), "Yapılaşmaya hazır" if parcel.buildable else ("Açık" if parcel.unlocked else "Kilitli")], 17)
    if not parcel.unlocked:
        _button(overlay_body, "🔓 Araziyi Aç", func():
            if terrain.unlock_parcel(parcel_id):
                _open_terrain_parcel(parcel_id)
        )
    elif not parcel.buildable:
        var active_job: Dictionary = terrain.get_active_job(parcel_id)
        if not active_job.is_empty():
            var progress: float = terrain.get_job_progress(parcel_id) * 100.0
            _label("🚧 Çalışma sürüyor: %s\nİlerleme: %.0f%%" % [str(active_job.get("machine", "machine")).capitalize(), progress], 16)
        else:
            _label("Bu bölgede doğal engeller var. Uygun iş makinesini seç ve Araziyi Düzenle işlemini başlat.", 15)
            _label("Makine seçenekleri: buldozer, ekskavatör, grader, damper, vinç, asfalt makinesi.", 14)
            for machine in terrain.get_machine_names():
                var machine_id := str(machine)
                var cost: Dictionary = terrain.get_machine_cost(machine_id)
                var title := "%s — %s LuCB + %s yakıt / %.0fs" % [machine_id.capitalize(), _num(int(cost.get("lucb", 0))), int(cost.get("fuel", 0)), float(cost.get("time", 0.0))]
                _button(overlay_body, "🚜 " + title, func():
                    if terrain.begin_terrain_edit(parcel_id, machine_id):
                        _message("%s çalışmaya başladı." % machine_id.capitalize(), "info")
                        _open_terrain_parcel(parcel_id)
        )
    else:
        _label("✅ Arazi düzenlendi. Şimdi yol ve bina yerleşimine hazır.", 16)
        _label("Yapılaşma kapasitesi: %d parsel" % terrain.get_building_slots(parcel_id), 15)
        if not bool(parcel.get("road_connected", false)):
            _button(overlay_body, "🛣️ 2 Şerit Yol Bağlantısı — 650 LuCB + çimento", func():
                if terrain.connect_parcel_road(parcel_id, 2):
                    _open_terrain_parcel(parcel_id)
            )
            _button(overlay_body, "🛣️ 4 Şerit Yol Bağlantısı — 950 LuCB + çimento", func():
                if terrain.connect_parcel_road(parcel_id, 4):
                    _open_terrain_parcel(parcel_id)
            )
        else:
            _label("🛣️ Yol bağlantısı aktif. Bu arazi şehir yol ağına bağlı.", 16)
            _label("🏗️ Bina yerleşimi", 18)
            _label("Bina maliyeti LuCB + üretim malzemelerinden oluşur. Her yapı bir arazi slotu kullanır.", 14)
            for building_type in ["residential", "commercial", "factory", "public"]:
                var type_id := str(building_type)
                var cost: Dictionary = terrain.get_building_cost(type_id)
                var materials: Dictionary = cost.get("materials", {})
                var material_text := ""
                for item in materials.keys():
                    material_text += "%s %d  " % [str(item), int(materials[item])]
                _button(overlay_body, "🏗️ %s — %s LuCB | %s" % [type_id.capitalize(), _num(int(cost.get("lucb", 0))), material_text], func():
                    if terrain.place_building(parcel_id, type_id):
                        _open_terrain_parcel(parcel_id)
                )

func _open_tax() -> void:
    var tax := state.get_parent().get_node_or_null("TaxSystem")
    if tax == null:
        _message("Vergi sistemi henüz hazır değil.", "warning")
        return
    overlay.visible = true
    overlay_title.text = "💰 VERGİ / BELEDİYE BÜTÇESİ"
    _clear_overlay()
    var bracket: Dictionary = tax.get_tax_bracket()
    var breakdown: Dictionary = tax.last_breakdown
    _label("Şehir Gelişim: %.1f LWL\nMevcut vergi oranı: %.1f%%\nSon tahsilat: %s LuCB" % [float(bracket.get("development_lwl", 1.0)), float(bracket.get("rate_percent", 1.5)), _num(int(state.tax_last_collection))], 18)
    var next_max := int(bracket.get("max", 35))
    if next_max < 999:
        _label("Sonraki kademe: %.0f LWL üzeri → bir sonraki oran" % float(next_max), 15)
    else:
        _label("En üst mevcut vergi kademesi: %.1f%%" % float(bracket.get("rate_percent", 3.0)), 15)
    _label("Nüfus ve ulaşım doğrudan gelir hesabına katkı sağlar. Vergi kademeleri şehir geliştikçe kademeli artar.", 15)
    _label("Belediye giderleri: %s LuCB\nNet bütçe: %s LuCB\nDurum: %s" % [_num(int(state.municipal_maintenance)), _num(int(state.municipal_net)), "AÇIK ⚠️" if state.budget_deficit else "FAZLA ✅"], 17)
    _label("🛣️ Yol durumu: %.0f%% | Bakım olayları: %d" % [float(state.road_condition_average), int(state.road_maintenance_events)], 15)
    _label("🏗️ Aktif inşaat kapasitesi: %d vinç | 👥 Başkan konuşmaları: %d" % [int(state.construction_slot_capacity), int(state.president_speech_count)], 15)
    if not str(state.last_president_speech).is_empty():
        _label("🎤 Son başkan konuşması: %s" % str(state.last_president_speech), 14)
    var infra := state.get_parent().get_node_or_null("InfrastructureSystem")
    if infra != null:
        var weak: Array[String] = infra.get_weak_services()
        if weak.is_empty():
            _label("🏛️ Belediye hizmetleri yeterli kapasitede.", 15)
        else:
            _label("⚠️ Yetersiz hizmetler: %s" % ", ".join(PackedStringArray(weak)), 15)
        var infra_names := {"electricity":"⚡ Elektrik", "water":"💧 Su", "sewage":"🚰 Kanalizasyon", "waste":"🗑️ Atık", "police":"👮 Polis", "fire":"🚒 İtfaiye", "health":"🏥 Sağlık", "education":"🏫 Eğitim", "parks":"🌳 Park"}
        var infra_lines: Array[String] = []
        for id in infra_names.keys():
            var detail: Dictionary = infra.get_service_detail(str(id))
            var level := int(detail.get("level", 0))
            var cap := int(detail.get("capacity", 0))
            var dem := int(detail.get("demand", 0))
            var score := float(detail.get("score", 0.0))
            var maintenance := int(detail.get("maintenance", 0))
            var outage: float = bool(detail.get("outage", false))
            var radius: float = int(detail.get("coverage_radius", 0))
            var status_text := "KESİNTİ ⚠️" if outage else ("AÇIK ⚠️" if score < 100.0 else "OK ✅")
            var covered: int = int(state.service_coverage_buildings.get(id, 0))
            var spatial_score: float = float(state.service_spatial_scores.get(id, 0.0))
            var uncovered: Array = state.service_uncovered_buildings.get(id, [])
            var uncovered_text := ""
            if not uncovered.is_empty():
                var preview: Array[String] = []
                for item in uncovered:
                    if preview.size() >= 3:
                        break
                    preview.append(str(item))
                uncovered_text = " | Açıkta: %s" % ", ".join(preview)
            infra_lines.append("%s Lv.%d — %s | %d/%d | %.0f%% | Alan %dm | Kapsama %d bina (%.0f%%) | Bakım %s | %s%s" % [infra_names[id], level, str(detail.get("name", "Kurulu değil")), cap, dem, score, radius, covered, spatial_score, _num(maintenance), status_text, uncovered_text])
        _label("🏛️ 5 KADEMELİ BELEDİYE HİZMETLERİ\n" + "\n".join(infra_lines), 13)
        _label("ℹ️ Kapasite nüfus/talebe göre hesaplanır. Yükseltmeler LuCB yanında üretim malzemeleri ve ekipman gerektirir.", 13)
    _label("Son tahsilat dağılımı", 18)
    if breakdown.is_empty():
        _label("İlk vergi tahsilatı henüz yapılmadı.", 15)
    else:
        _label("🏠 Konut: %s LuCB\n🏪 Ticaret: %s LuCB\n🏭 Sanayi: %s LuCB\n🚌 Ulaşım: %s LuCB\n🏨 Turizm: %s LuCB" % [_num(int(breakdown.get("residential", 0))), _num(int(breakdown.get("commercial", 0))), _num(int(breakdown.get("industrial", 0))), _num(int(breakdown.get("transport", 0))), _num(int(breakdown.get("tourism", 0)))], 16)

func _open_address_editor() -> void:
    overlay.visible = true
    overlay_title.text = "🪧 ŞEHİR İSİMLERİ / ADRESLER"
    _clear_overlay()
    var addresses := state.get_parent().get_node("CityAddressSystem")
    _label("Şehrini kurarken şehir adı, mahalle, sokak ve cadde/bulvar isimlerini kendin belirleyebilirsin.", 15)
    var city := LineEdit.new()
    city.placeholder_text = "Şehir adı"
    city.text = state.city_name
    overlay_body.add_child(city)
    _button(overlay_body, "🏙️ Şehir adını kaydet", func():
        if addresses.set_city_name(city.text):
            _message("Şehir adı güncellendi.", "success")
            _open_address_editor()
    )
    var neighborhood := LineEdit.new()
    neighborhood.placeholder_text = "Yeni mahalle adı"
    overlay_body.add_child(neighborhood)
    _button(overlay_body, "🏘️ Mahalle ekle", func():
        if addresses.add_neighborhood(neighborhood.text):
            _message("Mahalle eklendi.", "success")
            _open_address_editor()
    )
    var street := LineEdit.new()
    street.placeholder_text = "Yeni sokak adı"
    overlay_body.add_child(street)
    _button(overlay_body, "🛣️ Sokak ekle", func():
        if addresses.add_street(street.text):
            _message("Sokak eklendi.", "success")
            _open_address_editor()
    )
    var avenue := LineEdit.new()
    avenue.placeholder_text = "Yeni cadde / bulvar adı"
    overlay_body.add_child(avenue)
    _button(overlay_body, "🏙️ Cadde / bulvar ekle", func():
        if addresses.add_avenue(avenue.text):
            _message("Cadde/bulvar eklendi.", "success")
            _open_address_editor()
    )
    var catalog: Dictionary = addresses.get_address_catalog()
    _label("🏘️ Mahalleler: " + ", ".join(catalog.neighborhoods), 14)
    _label("🛣️ Sokaklar: " + ", ".join(catalog.streets), 14)
    _label("🏙️ Caddeler/Bulvarlar: " + ", ".join(catalog.avenues), 14)

func _open_city_info() -> void:
    overlay.visible = true
    overlay_title.text = "🏙️ ŞEHİR BİLGİSİ"
    _clear_overlay()
    _label("%s\nPlayer ID: %s\nCity ID: %s" % [state.city_name, state.player_id, state.city_id], 18)
    _label("Nüfus: %d\nİş: %d\nBina: %d\nŞehir seviyesi: %d\nGelişim: %.1f LWL\nSon vergi: %s LuCB\nGünlük yaşam: %s\nEv adresi: %s\nİş adresi: %s\nHedef: %s\nRota: %s\nUlaşım modu: %s | Tahmini süre: %.0f dk\nSahil: 🚶 %d | 🏃 %d | 🚲 %d | 🎣 %d | 🐕 %d | 🧒 %d\nPark: 🚶 %d | 🏃 %d | 🧒 %d | 🏀 %d | ☕ %d\nHareketlilik: %.2f\nEkonomik aktivite: %.2f\nProtesto: %d\nŞehirden ayrılan: %d\n🛣️ Yol durumu: %.0f%% | Bakım: %d\nMutluluk: %d%%\nGüvenlik: %d%%\nSağlık: %d%%\nEğitim: %d%%\nÇevre: %d%%\nTrafik: %d%%\nAraç: %d\nYol kapasitesi: %.0f\nUlaşım talebi: %.2f\nKoridor kullanımı: Yerel %.0f%% | Arter %.0f%% | Ekspres %.0f%% | Otoyol %.0f%%" % [state.population, state.jobs, state.buildings.size(), state.city_level, state.city_development_lwl, _num(state.tax_last_collection), state.citizen_routine_activity, state.citizen_home_address, state.citizen_work_address, state.citizen_destination_address, state.citizen_active_trip, state.citizen_transport_mode, float(state.citizen_trip_time), state.coastal_walkers, state.coastal_runners, state.coastal_cyclists, state.coastal_fishers, state.coastal_dog_walkers, state.coastal_children, state.park_walkers, state.park_runners, state.park_children, state.park_athletes, state.park_social_visitors, float(state.citizen_mobility_demand), float(state.citizen_economic_activity), state.protest_count, state.citizens_moved_away, float(state.road_condition_average), int(state.road_maintenance_events), int(state.happiness), int(state.safety), int(state.health), int(state.education), int(state.environment), int(state.traffic), int(state.traffic_vehicle_count), float(state.traffic_road_capacity), float(state.traffic_demand_index), float(state.traffic_local_usage) * 100.0, float(state.traffic_arterial_usage) * 100.0, float(state.traffic_express_usage) * 100.0, float(state.traffic_highway_usage) * 100.0])
    _label("Protesto: %d | Taşınan vatandaş: %d" % [int(state.protest_count), int(state.citizens_moved_away)], 16)
    _label("🪧 Mahalle: %d | Sokak: %d | Cadde/Bulvar: %d" % [state.city_neighborhoods.size(), state.city_streets.size(), state.city_avenues.size()], 15)
    _label("📦 Lumorix Kargo: %d teslimat | 🛵 Lumorix Kurye: %d | 🍔 Yemek siparişi: %d\nLojistik yük: 📦 %d birim | 🍔 %d birim | Aktif rota: %d | Verim: %.0f%%" % [state.lumorix_cargo_deliveries, state.lumorix_courier_deliveries, state.lumorix_food_orders, state.lumorix_cargo_units, state.lumorix_food_units, state.lumorix_active_routes, float(state.lumorix_logistics_efficiency) * 100.0], 15)
    _label("🛒 Pazar: %d satış | %d LuCB gelir | %d birim ürün" % [state.market_sales_count, state.market_sales_income, state.market_units_traded], 15)
    _label("Son vatandaş geri bildirimleri", 18)
    for complaint in state.complaints.slice(max(0, state.complaints.size() - 5), state.complaints.size()):
        _label("• " + complaint, 14)

func _on_building_selected(building: Node) -> void:
    selected_building = building
    _open_selected_building()

func _open_selected_building() -> void:
    if selected_building == null:
        _message("Önce şehirde bir bina seç.", "info")
        return
    overlay.visible = true
    overlay_title.text = "🔧 %s" % selected_building.display_name
    _clear_overlay()
    _label("Tür: %s\nMevcut seviye: %d LWL\nNormal maksimum: %d LWL" % [selected_building.building_type, selected_building.lwl, selected_building.normal_max_lwl], 18)
    if selected_building.premium:
        _label("💎 PREMIUM — 20 LWL\nBu yapı doğrudan premium olarak açılır ve normal yükseltme zincirine girmez.", 16)
        return
    var gs := state
    var upgrade_system := gs.get_parent().get_node("UpgradeSystem")
    var data := {"id":selected_building.building_id, "type":selected_building.building_type, "lwl":selected_building.lwl, "premium":selected_building.premium}
    var check: Dictionary = upgrade_system.can_upgrade(data)
    if selected_building.lwl >= 10:
        _label("🏆 Maksimum normal seviye: 10 LWL", 17)
        return
    var req: Dictionary = upgrade_system.get_requirements_for_next_level(data)
    _label("Sonraki seviye: %d LWL" % int(selected_building.lwl + 1), 18)
    _label("Yükseltme maliyeti: %s LuCB" % _num(int(req.get("lucb", 0))))
    for line in upgrade_system.format_requirements(data):
        if line.begins_with("LuCB"):
            continue
        _label("🔩 " + line, 15)
    if bool(check.ok):
        _button(overlay_body, "⬆️ LWL %d → %d yükselt" % [selected_building.lwl, selected_building.lwl + 1], func(): _upgrade_selected_building(upgrade_system))
        _label("Yükseltme: LuCB + fabrika üretimi malzeme/ekipman birlikte tüketilir.", 14)
    else:
        _label("⛔ %s" % str(check.reason), 15)
        _button(overlay_body, "Yetersiz kaynakları göster", func(): _message(str(check.reason), "warning"))

func _upgrade_selected_building(upgrade_system: Node) -> void:
    if selected_building == null:
        return
    var data := {"id":selected_building.building_id, "type":selected_building.building_type, "lwl":selected_building.lwl, "premium":selected_building.premium}
    if upgrade_system.upgrade(data):
        selected_building.lwl = int(data.lwl)
        selected_building._update_visual_scale()
        for item in state.buildings:
            if str(item.get("id", "")) == selected_building.building_id:
                item["lwl"] = selected_building.lwl
                break
        if state.has_method("recalculate_expansion_impact"):
            state.recalculate_expansion_impact()
        else:
            state.state_changed.emit()
        _open_selected_building()

func _close_overlay() -> void:
    if overlay:
        overlay.visible = false

func show_opening_speech() -> void:
    var intro := ColorRect.new()
    intro.name = "PresidentOpening"
    intro.color = Color(0.01, 0.025, 0.06, 0.96)
    intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(intro)
    var title := Label.new()
    title.text = "LUMORIX\nGAMER STUDIO"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(350, 145)
    title.size = Vector2(580, 90)
    title.add_theme_font_size_override("font_size", 34)
    intro.add_child(title)
    var speech: Label = Label.new()
    speech.text = "Yeni başkanınız geliyor!\n\n\"Oylarınızı ve desteğinizi bekliyorum.\nBu şehri sizinle yeniden inşa edeceğiz!\""
    speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    speech.position = Vector2(270, 270)
    speech.size = Vector2(740, 190)
    speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    speech.add_theme_font_size_override("font_size", 25)
    intro.add_child(speech)
    var slogan := Label.new()
    slogan.text = "LUMORIX CITY — ŞEHRİNİ KUR, HALKINLA BÜYÜT"
    slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    slogan.position = Vector2(300, 505)
    slogan.size = Vector2(680, 45)
    slogan.add_theme_font_size_override("font_size", 18)
    intro.add_child(slogan)
    var timer := get_tree().create_timer(4.5)
    timer.timeout.connect(_close_opening_speech.bind(intro))

func _close_opening_speech(intro: Node) -> void:
    if is_instance_valid(intro):
        intro.queue_free()

func _process(delta: float) -> void:
    toast_timer = max(toast_timer - delta, 0.0)
    if state and time_label:
        var h := int(state.day_time)
        var m := int((state.day_time - h) * 60.0)
        time_label.text = "Saat %02d:%02d" % [h, m]
        if toast_timer <= 0.0:
            message_label.text = ""

func _refresh() -> void:
    if info_label == null or state == null:
        return
    info_label.text = "🏙️ %s    👥 %d    🏗️ %d bina\n💰 LuCB: %s    💎 LCB: %s\n😊 Mutluluk: %d%%    🛡️ Güvenlik: %d%%    🌳 Çevre: %d%%" % [state.city_name, state.population, state.buildings.size(), _num(state.lucb), _num(state.lcb), int(state.happiness), int(state.safety), int(state.environment)]
    if stats_label:
        stats_label.text = "❤️ Sağlık: %d%%\n🎓 Eğitim: %d%%\n🚗 Trafik: %d%%\n💼 İş: %d\n🏙️ Şehir Seviyesi: %d" % [int(state.health), int(state.education), int(state.traffic), state.jobs, state.city_level]

func _num(value: int) -> String:
    var s := str(value)
    var out := ""
    while s.length() > 3:
        out = "." + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return s + out

func _message(text: String, severity: String) -> void:
    if message_label:
        message_label.text = "[%s] %s" % [severity.to_upper(), text]
        toast_timer = 4.0
