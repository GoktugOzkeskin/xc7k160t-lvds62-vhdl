# Kart fotoğraflarına göre 52 çift varyantı — 22 Kasım 2026

Bu varyant, kullanıcının IMG_2375…2379 şema fotoğrafları ve 52 çiftle devam etme talebi içindir. Önceki 62 çiftlik örnek korunur; kart varyantı bağımsız `build/board52/` altında üretilir. GUI kullanılmaz. Bitstream, tamamlanmış routed checkpoint'ten isteğe bağlı ayrı adımla üretilir.

| Bağlantı | Bank | Paket çiftleri |
|---|---|---|
| LVDS_CONN2_0…23 | 34 | L1…L24 |
| LVDS_CONN2_24…28 | 33 | L1…L5 |
| LVDS_CONN2_29 | 33 | L13 MRCC |
| LVDS_CONN2_30…32 | 33 | L7…L9 |
| LVDS_CONN2_33 | 33 | L11 SRCC |
| LVDS_CONN2_34 | 33 | L12 MRCC |
| LVDS_CONN2_35…51 | 32 | L8…L24 |
| SYSCLK_156M25_P/N | 33 | AA10 / AB10, L14 SRCC |
| FPGA_RESET | 34 | U4, IO_0_VRN_34 |

Tam eşleme: `pin_map.csv`; etkin paket/saat kısıtları: `board_pins.xdc`. UART, SGMII, DSA, HUZME, TX_ON_OFF ve LVDS_SPARE netleri bu 52 veri çiftine dahil edilmez.

## Elektriksel teyit ve açık varsayımlar

AMD DS182 v2.19, sayfa 11 Tablo 13: HP banklardaki LVDS için VCCO min/nominal/max 1,710/1,800/1,890 V. Dolayısıyla `IOSTANDARD LVDS` ve reset için `LVCMOS18` kullanılır. Bu bir **cihaz gereksinimidir**; kartın gerçekten 1,8 V ile beslendiği fotoğraflardan doğrulanamaz. Kaynak: https://docs.amd.com/v/u/en-US/ds182_Kintex_7_Data_Sheet

U4, VRN işlevli genel I/O'dur. Bu tasarım DCI kullanmaz; reset girişine atanır. Reset polaritesi fotoğraflarda yoktur ve cihaz datasheet'i karttaki polariteyi belirleyemez. Önceki aktif-yüksek varsayımı, `CORE52.RESET_ACTIVE_LOW=false` olarak açık tutulmuştur; VHDL generic'i ters polariteyi destekler. Bitstream veya kart testi öncesinde reset sürücüsü/şeması teyit edilmelidir. CFGBVS/CONFIG_VOLTAGE, gerçek dış gecikmeler ve kartın sonlandırma topolojisi hâlâ bilinmiyor; uydurma değer atanmaz.

156,250 MHz referans için 6,400 ns period kullanılır. 100 ps input jitter bir analiz varsayımıdır, osilatör ölçümü değildir. Sabit empedanslı çift yönlü LVDS için Vivado LVDS-1 uyarısı bastırılmaz.

## Veri akışı ve loopback

17/11/24 fiziksel çift sayıları nedeniyle eski bank başına eşit yarı bölme kullanılamaz. 26 bağlantılı tek test denetleyicisi ve bank başına ayrı PHY/IDELAYCTRL kullanılır. VHDL port indeksi şemadaki konektör numarasıyla aynıdır.

Varsayılan harici kablo eşlemesi `i ↔ i+26`, i=0…25; P→P, N→N. Bütün 52 çift sırayla TX ve RX olur. `loopback_map.csv` paket pinlerini de listeler. Bu eşleme kartın mevcut kablosunun teyidi değildir; testin beklediği bağlantıdır.

Hizalama, BITSLIP, PRBS karşılaştırması ve hata sayaçları önceki doğrulanmış VHDL bloklarından kullanılır. Yeni üst seviye üç PHY'nin RDY sinyallerini ayrı ayrı senkronize eder; global PASS/FAIL ve saat/heartbeat watchdog'u ham 156,25 MHz domaininde değerlendirir.

TEST_VIO: çıkış0 run_enable (1), çıkış1 restart, çıkış2 clear_errors, çıkış3 inject_error. Girişler monitor128, ileri/geri hata bitleri, ileri/geri kontrol edilen bitler, ileri/geri tamamlanan tur sayıları ve 26-bit compare_locked. RESULT_VIO: status16, çıkış0 clear_watchdog. Status bit0 PASS, bit1 FAIL, bit2 valid, bit3 heartbeat görüldü, bit4 MMCM locked, bit7..5 bank32/33/34 RDY. DATA_ILA tüm veri ve hizalama yollarını izler.

## Batch komutları

```powershell
./board52/run_low_impact.ps1 -Step create -VivadoBin '<Vivado bin dizini>'
./board52/run_low_impact.ps1 -Step implement -VivadoBin '<Vivado bin dizini>'
./board52/run_low_impact.ps1 -Step sim -VivadoBin '<Vivado bin dizini>'
./board52/run_low_impact.ps1 -Step audit -VivadoBin '<Vivado bin dizini>'
./board52/run_low_impact.ps1 -Step archive -VivadoBin '<Vivado bin dizini>'
./board52/run_low_impact.ps1 -Step bitstream -VivadoBin '<Vivado bin dizini>'
```

Launcher BelowNormal öncelik ve 16 mantıksal işlemcili bu sistemde son dört mantıksal işlemciye affinity uygular. Vivado/elaborasyon en fazla iki thread kullanır. CS2 ile CPU/cache/RAM paylaşımı devam eder; FPS ve frame-time etkisinin sıfır olması garanti edilmez. Daha düşük etki karşılığında işlem daha uzun sürebilir.

Çıktılar: `build/board52/project/lvds52.xpr`, `reports/`, `sim/`. Kaynak scriptleri bu README'nin yanındadır. En son sonuç ve kalan kısıtlar kullanıcıya verilen implementation raporunda kaydedilir.

Windows debug-hub ekleme işleminde 146 karakterlik geçici yol sınırı olduğundan batch launcher araç çalışma dizinini sistem TEMP altında kısa `lvds52_batch` klasörüne alır. Proje/log/rapor hedefleri yine `build/board52/` altındadır. Gerekirse `-Step resume`, mevcut sentez checkpoint'inden implementation'a devam eder. Aynı anda iki implementation veya archive adımı çalıştırmayın.

## Bitstream

Kullanıcının sonraki isteğiyle 22 Kasım 2026'da `build/board52/bitstream/lvds52_board.bit` ve eşleşen `lvds52_board.ltx` üretildi. Üretim 0 hata, 0 kritik uyarıyla tamamlandı; altı DRC uyarısı korunur. Hardware Manager bağlantısı veya kart programlama yapılmadı. Bitstream üretimi; kart rail'i, reset polaritesi, sonlandırma, CFGBVS veya harici zamanlama teyidi yerine geçmez. Aktif-yüksek reset varsayımı korunur.

## GitHub sürümü

Kaynaklar main dalında; hazır .bit/.ltx, proje ve DCP dosyaları [BOARD52 ön sürümünde](https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl/releases/tag/board52-2026-11-23) sunulur. SHA256 manifesti Release ekidir. Kart üzerinde doğrulama beklemektedir.
