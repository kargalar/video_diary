# Video Diary (Günlük Video)

Kısa günlük videolar kaydet, puanla, ruh halini ekle, takvimde ilerlemeni takip et. Android, iOS, web (kısıtlı) ve masaüstü hedefleri için Flutter ile geliştirilmiştir.

## Özellikler

- Ön kamera ile hızlı video kaydı (Portrait/Yatay mod ayarlanabilir)
- Kayıt sonrası başlık ekleme, 1–5 yıldız puanlama ve çoklu “ruh hali” seçimi
- Kayıt listesi: küçük resim, süre, dosya boyutu; yeniden adlandırma ve silme (kaydırmalı menü)
- Oynatıcı: oynat/duraklat, zaman çizelgesi ve süre gösterimi
- Takvim görünümü: kayıt yapılan günleri, seri (streak), günlük ortalama puanı ve ruh halleri ısı haritasını gösterir
- Günlük bildirim hatırlatıcısı: seçilen saatte bildirim planlama (zaman dilimi desteği)
- Tema: Aydınlık/Karanlık
- Kayıtların kaydedileceği klasörü seçme (varsayılan: uygulama belgeleri altında `video_diary`)

## Hızlı Başlangıç

1) Bağımlılıkları yükleyin

```powershell
flutter pub get
```

2) Uygulamayı çalıştırın (bağlı cihaz/emu üzerinde)

```powershell
flutter run
```

3) Yayın (release) derlemesi (opsiyonel)

```powershell
flutter run --release
```

Not: VS Code içinde hazır görevler de bulunur: “Flutter pub get”, “Flutter analyze”, “Flutter test”.

## Ekranlar ve Akış

- Günlük (ana sayfa):
	- Üstte seri (streak) bandı: mevcut ve en iyi seri
	- Liste: videoların küçük resimleri, süre/boyut ve başlık; öğeyi kaydırarak Yeniden Adlandır/Sil
	- Alt eylemler: Kayıt, Takvim, Ayarlar
- Kayıt: küçük bir FAB ile başlat/durdur, canlı süre sayacı; kayıt bitince başlık, puan ve ruh hali isteği
- Oynatıcı: tam ekran video, üstte geri/başlık, altta kontroller
- Takvim: ay görünümü, kayıt sayacı rozeti, bugünün çerçevesi, seri vurguları, puan yıldızları; güne dokununca o güne ait liste + puan düzenleme paneli
- Ayarlar: kayıt klasörü seçimi, tema, yatay kayıt modu, günlük hatırlatma saati

## İzinler ve Platform Notları

- Android:
	- Kamera ve Mikrofon: video çekimi için gerekiyor
	- Bildirimler ve (Android 13+) “exact alarm” izni: günlük hatırlatma için
	- Depolama: kullanıcı klasörü seçimi için gerekebilir (SAF üzerinden); kayıtlar seçilen klasörde `video_diary/` altına yazılır
	- Bazı cihazlarda “Arka planda tam zamanlı alarm” kısıtları nedeniyle bildirimler yaklaşık zamanlı planlanabilir
- iOS:
	- Kamera/Mikrofon/Bildirim izin açıklamalarını Info.plist’e ekleyin (Privacy – Camera/Microphone Usage Description, Notifications)

Bu repo platform manifestlerini minimal tutar; ihtiyaçlarınıza göre güncelleyin.

## Depolama ve Veri Modeli

- Video dosyaları: Kullanıcının seçtiği taban dizin altında `video_diary/diary_YYYY-MM-DD_HH-mm-ss[_Baslik].mp4`
- Girdi listesi ve öznitelikler: SharedPreferences’ta JSON olarak saklanır
- Günlük veriler (günlük ortalama puan, ruh halleri): Hive kutusu `day_data`
- Küçük resimler: `video_thumbnail` ile oluşturulur ve yol bilgisi girişte tutulur

## Proje Yapısı (özet)

- `lib/main.dart`: uygulama girişi, bildirim/init ve dikey kilit
- `lib/core/app.dart`: tema, rotalar, provider konfigürasyonu
- `lib/features/diary/...`: günlük kayıt listesi, kayıt, oynatıcı, takvim; repository ve model
- `lib/features/settings/...`: ayarlar ekranı, model ve repository
- `lib/services/...`: bildirim, depolama (klasör seçimi/oluşturma), kamera/video servisleri

## Sık Karşılaşılan Sorunlar

- Bildirimler gelmiyor:
	- Uygulama içinden saat seçtikten sonra sistem izinlerini onaylayın
	- Android 13+ için bildirim izni açık olmalı; bazı cihazlarda tam zamanlı alarm izni de gerekir
- Video dosyası adlandırma başarısız:
	- Başlık “güvenli” karakterlere dönüştürülür; dosya açıkken yeniden adlandırma başarısız olabilir
- Dış klasöre yazılamıyor:
	- Android sürümü/cihaz politikasına bağlı olarak sadece seçilen SAF klasörüne yazılabilir; olmazsa uygulama belgeleri klasörünü kullanın
- Kamera yönü/sıkışma:
	- Kayıt sayfasında seçtiğiniz “Yatay Kayıt” ayarı önizleme/kaydı kilitler; çıkınca uygulama tekrar dikeye döner

## Geliştirme

Kod kalitesini kontrol etmek:

```powershell
flutter analyze
```

Testleri çalıştırmak:

```powershell
flutter test -r compact
```

## Kullanılan Paketler (seçme)

- provider, camera, video_player, file_selector, flutter_local_notifications
- permission_handler, path_provider, shared_preferences, intl, timezone, flutter_timezone
- video_thumbnail, flutter_slidable, hive, hive_flutter

---

Sorularınız veya önerileriniz için issue açabilirsiniz.