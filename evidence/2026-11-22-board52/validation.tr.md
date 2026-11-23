# 52 çift kart implementation raporu — 22 Kasım 2026

Kullanıcının onayladığı LVDS_CONN2_0…51, fotoğraflardaki paket pinlerine eşlendi. Bank32/33/34 dağılımı 17/11/24; saat AA10/AB10, FPGA_RESET U4. UART/SGMII/kontrol/spare netleri veri çiftlerine dahil edilmedi.

| Kontrol | Sonuç |
|---|---|
| Paket pinleri | 104 veri + 2 saat + 1 reset = 107; tümü atanmış, çakışma yok |
| Saatler / hedef hız | 156,25 MHz → 500/125/200 MHz; aktif çift başına 1 Gbit/s DDR |
| BD ve sentez | PASS; sentezde 0 hata / 0 kritik uyarı |
| Route | 30.032/30.032 routable net tamamlandı; routing hatası 0 |
| Routed setup WNS / TNS | +0,575 ns / 0 |
| Routed hold WHS / THS | +0,038 ns / 0 |
| Pulse-width payı | +0,264 ns |
| Saatsiz register / kısıtsız iç uç | 0 / 0 |
| Bus-skew | 4/4 MET |
| İstisna denetimi | 52/52 aynı-pad yol False Path; 11/11 ikinci CDC kademesi zamanlamalı |
| Son kaynak kullanımı | 13.056 LUT (%12,88), 21.082 register (%10,40) |
| Üç-bank UNISIM seri test | İki yönde 843.024 + 843.024 = 1.686.048 bit; 0 hata |
| Hata enjeksiyonu | Temiz PASS ardından enjekte edilen hata global FAIL üretti |
| Simülasyon zamanı | Temiz PASS 86,8256 µs; negatif test dahil bitiş 95,1944 µs |
| GUI / bitstream | GUI açılmadı; bitstream sonradan üretildi (ek bölüme bakınız) |

52 uç, 26 harici bağlantıyla i↔i+26 (i=0…25), P→P/N→N şeklinde test edilir. CSV beklenen kablo eşlemesidir; takılı kablonun teyidi değildir. Her uç sırayla TX/RX olur. Yeni VHDL üst seviyede reset bırakılması iki saat alanında ayrı senkronize edilir; üç bank RDY sinyali de ayrı senkronize edilir.

## Datasheet ve kalan kart bilgileri

[AMD DS182](https://docs.amd.com/v/u/en-US/ds182_Kintex_7_Data_Sheet), v2.19 sayfa 11 Tablo 13: HP LVDS VCCO min/nominal/max **1,710 / 1,800 / 1,890 V**. Bu, cihaz gereksinimini doğrular; kartın gerçekten 1,8 V ile beslendiğini doğrulamaz. LVDS ve reset için LVCMOS18 seçildi. U4, DCI kullanılmadığında genel I/O olarak kullanılan IO_0_VRN_34 pinidir.

Reset polaritesi fotoğraflarda yoktur: önceki aktif-yüksek varsayımı `RESET_ACTIVE_LOW=false` olarak açık tutulur. Gerçek rail ve reset sürücüsü programlamadan önce teyit edilmelidir. CFGBVS/CONFIG_VOLTAGE, sonlandırma ve gerçek dış gecikmeler de bilinmiyor. 53 giriş/52 çıkış için dış gecikme kısıtları eksiktir; 100 ps input jitter analiz varsayımıdır. Sonuç **iç zamanlama kapanmasıdır; fiziksel kart BER veya tam I/O signoff değildir**.

DRC'deki altı uyarı bastırılmadı: CFGBVS-1 (konfigürasyon gerilimi), LVDS-1 (çift yönlü LVDS sabit empedans/turnaround), vendor debug hub içinde üç PDCN-1569 ve bir RTSTAT-10. CDC'deki 52 CDC-13, kullanılmayan aynı-pad TX→kendi RX yollarıdır ve User Ignored/False Path olarak listelenir; iki CDC-15 RESULT_VIO içindedir. Aktif karşı kablo alıcısı ve payload yolları istisna dışındadır.

## Batch çalışma ve CS2

Tüm Vivado adımları batch, simülasyon komut satırındadır. BelowNormal ve en çok iki thread; 16 mantıksal CPU'lu sistemde affinity 61440 (son dört mantıksal CPU) süreç üzerinden doğrulandı. Vivado peak belleği yaklaşık 2,86 GB, seri simülatör peak belleği yaklaşık 224 MB oldu; eşzamanlı süreçler toplam belleği artırır. CPU/cache/RAM/ısı paylaşımı sürdüğünden CS2 FPS veya frame-time etkisi sıfır garanti edilemez. FPS ölçülmedi. Bu implementation tamamlandığından işlem yükü sona ermiştir.

İlk debug-hub denemesinde Windows geçici yol uzunluğu sınırı görüldü; launcher TEMP/lvds52_batch kullanacak şekilde düzeltildi. Sonuç saat alanındaki reset bırakma senkronizasyonu eklendikten sonra yukarıdaki nihai sentez, route ve simülasyon tekrar alındı.

## Teslim

`board_pins.xdc`, `logic_exceptions.xdc`, pin/kablo CSV'leri, `reports/` ve gerçek tamamlanmış `routed.dcp` sunulur. Vivado ZIP'i kaynak projedir; routed checkpoint ayrıca verilir. Çalıştırma ayrıntıları kaynak paketin board52/README.md dosyasındadır.

52 çift kart varyantı ve bitstream 23 Kasım 2026 yayını için hazırlanmıştır. Önceki 62 çift sonuçları tarihsel örnektir; bu kartın sonucu yerine kullanılmaz.

## Sonraki kullanıcı isteği: bitstream üretimi — 22 Kasım 2026

Kullanıcının açık talebi üzerine mevcut doğrulanmış routed checkpoint'ten
lvds52_board.bit ve eşleşen lvds52_board.ltx batch modunda üretildi.
Vivado sonucu: 0 hata, 0 kritik uyarı; 6 DRC uyarısı korunur.
Bit dosyasının tasarım/part başlığı, konfigürasyon veri uzunluğu ve sync word'u
doğrulandı; SHA256 kayıtları bitstream/BITSTREAM_INFO.json içindedir.
Donanıma bağlantı veya programlama yapılmadı; aktif-yüksek reset varsayımı ve
kart besleme/sonlandırma/konfigürasyon gerilimi teyidi gerekliliği devam eder.
