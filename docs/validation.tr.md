# VHDL doğrulama raporu

Vivado 2024.1 / XC7K160T-FBG676-1 / 156,250 MHz referans.

| Kontrol | Sonuç |
|---|---|
| Kullanıcı RTL ve testbench dili | VHDL, baştan yazıldı |
| Blok tasarımı | lvds_vhdl_bd; doğrulama PASS |
| Fiziksel kullanıcı portu | 62 diferansiyel inout çift; bank32/33/34: 20/20/22 |
| Saatler | 500/125/200 MHz; MMCM ve frekans kontrolü PASS |
| VHDL simülasyonları | 7/7 PASS |
| 62 çift seri UNISIM sistem testi | İki yönde toplam 2.010.272 kontrol edilen bit, 0 hata |
| Hata senaryoları | Enjeksiyon, X/Z, son kelime, RDY/saat/heartbeat kaybı, dar/boş göz, kopuk kablo algılandı |
| Sentez | 0 hata / 0 kritik uyarı |
| Aday pinlerle tam yönlendirme | Tamamlandı |
| Routed setup WNS / TNS | +1,834 ns / 0 |
| Routed hold WHS / THS | +0,042 ns / 0 |
| Pulse width WPWS | +0,264 ns |
| Saatsiz register / kısıtsız iç uç | 0 / 0 |
| Son LUT / register | 19.921 (%19,65) / 31.779 (%15,67) |
| Bus-skew | PASS |
| İstisna kapsamı denetimi | 62 aynı-pad yol False Path; 13 ikinci senkronizatör kademesi zamanlamalı: PASS |
| Bitstream | Kullanıcı isteğiyle üretilmedi |

Kaydedilen son geçerli zamanlama raporu `evidence/2026-11-17/timing_routed_candidate.txt` dosyasıdır. Yeni çalıştırmalarda raporlar `build/reports/` altında oluşur. Önceki tasarımdaki ara tanı raporları bu kaynak paketine alınmadı.

Zamanlama istisnası: yalnızca 13 gerçek iki-kademeli senkronizatörün ilk D girişi ve aynı fiziksel IOBUFDS'nin sürücüsünden kendi ISERDES DDLY girişine giden 62 kullanılmayan geri okuma yolu. OBUFTDS O/OB üzerinden kapsam hem veri hem tristate kaynaklarını içerir. Karşı kablo ucundaki aktif alıcı ve veri karşılaştırma mantığı kapsam dışındadır.

DRC'de altı uyarı korunmuştur: CFGBVS-1 (şema/konfigürasyon gerilimi bilinmiyor), LVDS-1 (çift yönlü LVDS sabit 100 ohm yapı ve yön değiştirme/sonlandırma konusu), debug hub içinde üç PDCN-1569 ve bir RTSTAT-10. CDC raporu, 62 kullanılmayan aynı-pad yolunu CDC-13 Critical/User Ignored/False Path olarak listeler; iki CDC-15 vendor RESULT_VIO içindedir. Kullanıcı sonuç sinyallerinin iki-kademeli ASYNC_REG senkronizasyonu CDC-3 olarak tanınmıştır.

Bu rapor **kart üzerinde 1 Gb/s çalıştığı** sonucunu vermez. 31 kablo için P/N eşlemesi, gerçek paket pinleri, HP bankların VCCO/sonlandırması, osilatör kalitesi, harici gecikmeler ve konfigürasyon gerilimi bilinmiyor. Yerleştirmede kullanılan pinler yalnızca paket kaynaklarını ve iç zamanlamayı denemek için seçildi; normal projede aktif kart XDC'si olarak eklenmedi. 63 giriş ve 62 çıkışın harici gecikme kısıtları eksiktir.
