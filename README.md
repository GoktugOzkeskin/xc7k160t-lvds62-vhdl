# XC7K160T — 52 çift çift yönlü LVDS kart testi

XC7K160T-FBG676-1 üzerinde fotoğraflardan çıkarılan **52 diferansiyel çift** için VHDL loopback tasarımı. 156,250 MHz referanstan 500/125/200 MHz saatler üretilir; aktif çift başına hız **1 Gbit/s DDR**'dır. Her çift sırayla TX ve RX olur.

**Doğrulanan:** Vivado BD, sentez, gerçek paket pinleriyle tam yönlendirme/iç zamanlama ve UNISIM seri simülasyonu. **Kart üzerinde doğrulanmadı:** gerçek besleme, reset polaritesi, sonlandırma ve harici gecikmeler teyit bekliyor. Bitstream üretimi tamamlandı; donanıma programlama yapılmadı.

## Hazır dosyalar

[BOARD52 sürümü](https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl/releases/tag/board52-2026-11-23) `.bit`, eşleşen `.ltx`, Vivado proje ZIP'i, kaynak ZIP'i, routed DCP, rapor paketi ve SHA256 manifestini içerir. Kart doğrulaması beklediğinden **ön sürümdür**. Kaynak kod için ana dal `main` kullanılır; depo public olarak kullanılmaktadır.

## Kart bağlantıları

| Bağlantı | Bank / pin |
|---|---|
| LVDS_CONN2_0…23 | Bank34, 24 çift |
| LVDS_CONN2_24…34 | Bank33, 11 çift |
| LVDS_CONN2_35…51 | Bank32, 17 çift |
| SYSCLK_156M25_P/N | AA10 / AB10, bank33 SRCC |
| FPGA_RESET | U4, bank34 IO_0_VRN |

Etkin kısıtlar: [board_pins.xdc](board52/board_pins.xdc), [pin tablosu](board52/pin_map.csv), [loopback kablolaması](board52/loopback_map.csv). Varsayılan test kablosu `i ↔ i+26`, i=0…25; P→P, N→N. Bu eşleme takılı kablonun teyidi değildir.

## Davranış

- Bank başına PHY/IDELAYCTRL ve 26 bağlantılı ortak test denetleyicisi.
- Otomatik IDELAY göz taraması, DDR BITSLIP, PRBS31 karşılaştırma ve yön başına hata/bit sayaçları.
- İki yön tamamlandıktan sonra PASS; enjeksiyon, hizalama/kalibrasyon kaybı ve watchdog için FAIL.
- 125 MHz ve ham referans saat alanında ayrı reset bırakma senkronizasyonu.
- Bir DATA_ILA, TEST_VIO ve RESULT_VIO. Kontroller ve status bitleri [board52/README.md](board52/README.md) içindedir.

PHY, VHDL içinde IOBUFDS/OSERDESE2/ISERDESE2/IDELAYE2 primitive'leri kullanır. SelectIO Wizard'ın BIDIR+DIFF+LVDS birleşimi bu cihazda kabul edilmediği için desteklenmeyen bir Wizard ayarı kullanılmaz.

## Yeniden üretim — Vivado 2024.1 / Windows PowerShell

Vivado 2024.1, Kintex-7 desteği ve uygun sentez/implementation lisansı gerekir. Araçlar PATH'te olabilir veya `VIVADO_BIN` / `-VivadoBin` ile bin dizini verilebilir.

```powershell
./board52/run_low_impact.ps1 -Step create
./board52/run_low_impact.ps1 -Step implement
./board52/run_low_impact.ps1 -Step sim
./board52/run_low_impact.ps1 -Step audit
./board52/run_low_impact.ps1 -Step bitstream
./board52/run_low_impact.ps1 -Step archive
```

GUI açılmaz. Çıktılar `build/board52/`, raporlar `reports/`, bitstream/probe dosyaları `bitstream/` altında üretilir. Varsayılan launcher düşük CPU önceliği, en çok iki thread ve uygun sistemde CPU affinity kısıtı uygular. Windows debug-hub geçici yol sınırı için kısa TEMP çalışma dizini kullanılır. Checkpoint'ten devam etmek için `-Step resume` vardır.

## BOARD52 sonuçları — 22 Kasım 2026 çalıştırması

| Kontrol | Sonuç |
|---|---|
| Fiziksel pin denetimi | 107 port: 104 veri + 2 saat + 1 reset |
| Sentez | 0 hata / 0 kritik uyarı |
| Tam route | 30.032/30.032 net; routing hatası 0 |
| Setup WNS / hold WHS | +0,575 ns / +0,038 ns |
| TNS / THS | 0 / 0 |
| Bus-skew | 4/4 MET |
| Seri UNISIM loopback | İki yönde 1.686.048 bit, 0 hata |
| Negatif test | Enjekte edilen hata global FAIL üretti |
| Bitstream | Üretildi; 0 hata / 0 kritik uyarı, 6 uyarı |

[Kanıtlar ve rapor](evidence/2026-11-22-board52/) yerel yolları temizlenmiş kayıtlardır. Sayısal sonuçlar korunmuştur. Bunlar kart BER ölçümü veya her yeni klonun test edildiği anlamına gelmez. GitHub-hosted Vivado CI başarısı iddia edilmez.

## Açık varsayımlar

DS182 Tablo 13, HP LVDS için nominal 1,8 V gerektirir; bu bilgi kartın gerçek rail bağlantısını doğrulamaz. Reset varsayılanı `RESET_ACTIVE_LOW=false` (aktif-yüksek). Konfigürasyon bankının CFGBVS/CONFIG_VOLTAGE bilgisi, sonlandırma ve gerçek harici gecikmeler bilinmiyor; 100 ps input jitter analiz varsayımıdır.

DRC'deki CFGBVS-1 ve LVDS-1 ile vendor debug uyarıları bastırılmadı. CDC'deki 52 kullanılmayan aynı-pad geri okuma yolu dar kapsamlı False Path'tir; 11 ikinci senkronizatör kademesi zamanlamalı kalır. Ayrıntılar [kart dokümanında](board52/README.md) ve [doğrulama raporunda](evidence/2026-11-22-board52/validation.tr.md).

## Önceki 62 çift örneği

17 Kasım 2026'daki 62 çift genel örneği `rtl/`, `sim/`, `scripts/`, `constraints/` ve [tarihsel dokümanlarında](docs/design.tr.md) korunur. Bu eski örnek 20/20/22 varsayımı ve aday pinlerle çalışır; gerçek 52 çift kart için **board52 akışı** kullanılmalıdır. Eski yedi test `scripts/run_simulations.ps1` ile çalıştırılır; bu sonuçlar yeni kartın yerine geçmez.

Kaynaklar ve raporlar Git'te; üretilen proje/IP/checkpoint/bitstream/waveform dosyaları `build/` altında ve Git dışındadır. Büyük hazır dosyalar Release ekidir. Depo kontrolü: `python scripts/check_repository.py`. [Lisans durumu](NOTICE.md), [GitHub kullanımı](docs/github.tr.md).
