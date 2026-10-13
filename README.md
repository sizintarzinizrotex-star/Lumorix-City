# Lumorix City

Mobile-first 4.x city-building project foundation for Lumorix Gamer Studio.

## Design rules currently locked
- Normal gameplay content: maximum 10 LWL.
- Selected premium store content: 20 LWL and permanent ownership.
- LuCB: normal city currency; LCB: premium currency.
- Direct LuCB gifting between players is not allowed; player-to-player economic transfer is through market sales.
- First release includes friends, visits, help, gifts/resources and chat.
- Real-time multiplayer is not active in the first release; data architecture is prepared for later activation.
- Interactive buildings such as the mall and stadium are intended to have interior/visitor experiences.
- Citizen satisfaction, public services, crime, environment, traffic, health and education feed back into city life.
- Premium store rotates on a 15-day cadence; high-value LCB packages may receive 10–30% promotional bonus campaigns.

## Current implementation stage
Procedural 3D foundation, city state, citizen markers, interactive building hooks, normal/premium LWL rules, currency package data, and mobile-friendly rendering baseline.

No final release ZIP is declared until the project has gone through the remaining systems, asset pass, static validation, integration checks and packaging pass.


## New systems added in this build
- Service/citizen feedback simulation loop.
- Traffic vehicle prototype system.
- Player/City account identity and permanent premium ownership persistence.
- Interactive building routing for mall, stadium, hospital, school, airport and port.
- 15-day store rotation and high-value LCB campaign framework.
- Procedural 3D asset factory for core building silhouettes and parks.
- Asset manifest for the remaining 3D production pass.
- Economy rules manifest separating normal 10 LWL content from selected premium 20 LWL content.

All currently defined premium landmark/store buildings are locked at 500 LCB and 20 LWL. This includes the Super Police Center, Super Fire Center, Special Hospital, Special University Campus, Grand Hotel, Mega Airport, Mega Port, Premium Metro Station, Premium Train Station, Mega Bridge, Premium Roundabout, Premium Power/Water/Sewage/Waste/Treatment facilities, Premium Mall and Mega Stadium. This 500 LCB price is a project-wide locked baseline unless the user later changes it.


## v0.5 development pass
- 5-level municipal infrastructure runtime: electricity, water, sewage, waste, police, fire, health, education, parks.
- Normal building upgrades now require LuCB plus production materials/equipment through a shared upgrade service up to 10 LWL.
- Citizen life layer tracks protest pressure and move-away pressure from persistent low happiness.
- Interactive interior catalog expanded for mall, stadium, hospital, school, airport and port.
- Premium catalog baseline remains locked at 20 LWL / 500 LCB / permanent ownership for all currently defined premium products.
- Final package is intentionally not generated yet; development continues on the same source project.

## Üretim + Pazar Omurgası
- Hammadde -> işlenmiş ürün -> ekipman üretim zinciri veri tabanlıdır.
- Üretim süreleri ve aktif üretim işleri `ProductionSystem` tarafından yönetilir.
- Yükseltme sistemi malzeme/ekipman envanterini ProductionSystem ile paylaşır.
- Oyuncu pazarı 24 saatlik ilanlar, miktar, birim fiyat ve ürün teslimi mantığını içerir.
- Doğrudan LuCB hediye sistemi yoktur; gerçek oyuncular arası satıcı bakiyesi güvenli sunucu takasına bırakılmıştır.

## Final entegrasyon pass

## Final entegrasyon pass
- Premium mağaza kataloğundaki tüm tanımlı 23 premium ürün UI mağazasına bağlandı; premium ürünler 20 LWL / 500 LCB kilitli fiyat kuralını korur.
- Konser, miting, premium konser ve premium miting alanları etkileşimli katalogda tanımlıdır.
- Başkan konuşması ve inşaat kapasitesi kayıt/yükleme akışına dahildir.
- Normal inşaat kapasitesi 3, premium vinç paketi ile 5; mimari üst sınır 10 slottur.
- Proje statik doğrulamada 33 GDScript ve 18 JSON dosyası için denetlendi; Main.tscn düğümlerinde yinelenen script ataması bulunmuyor.
- Bu çalışma ortamında oyun çalıştırıcısı bulunmadığı için gerçek cihaz/runtime testi yapılamamaktadır; final paketleme öncesi statik ve içerik denetimleri sürdürülecektir.

- Final mağaza bütünlük düzeltmesi: 11 LCB paketi artık UI tarafından kesilmeden tamamı listeleniyor; 23 premium ürün ID listesi elle tekrarlanmak yerine `data/premium_catalog.json` üzerinden okunuyor ve isim/fiyat/LWL değerleri katalogla senkron kalıyor.
