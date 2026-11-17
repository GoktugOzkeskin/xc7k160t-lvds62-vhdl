# XC7K160T — 62 çift çift yönlü LVDS loopback

XC7K160T-FBG676-1 üzerinde HP bank 32/33/34 için VHDL ile yazılmış otomatik loopback test tasarımı. 156,250 MHz referanstan 500/125/200 MHz saatler üretilir. Her aktif diferansiyel çift 1 Gbit/s DDR veri taşır.

**Doğrulanan kapsam:** yedi VHDL simülasyonu, Vivado blok tasarım doğrulaması, sentez ve aday paket pinleriyle iç setup/hold zamanlaması. **Kart üzerinde doğrulanmadı:** gerçek kart XDC'si ve elektriksel sonlandırma bilgisi sağlanmadı. Bitstream üretilmez.

## Özellikler

- Gerçek 62 diferansiyel `inout` çift: bank32/33/34 için 20/20/22.
- 31 harici loopback bağlantısı; her test turunda TX/RX rolleri değiştirilir.
- Kanal başına otomatik IDELAY göz taraması ve DDR BITSLIP hizalama.
- PRBS31 üretimi, gönderilen/alınan veri karşılaştırması, kanal hata maskeleri ve yön başına sayaçlar.
- İki yön tamamlandığında PASS; hata, hizalama/kalibrasyon kaybı ve watchdog için kalıcı FAIL.
- Üç ILA, dört VIO ve gerçek Vivado IP Integrator blok tasarımı.

SelectIO Wizard'ın bu cihazdaki BIDIR+DIFF+LVDS birleşimi desteklenmediğinden PHY, VHDL içinde IOBUFDS/OSERDESE2/ISERDESE2/IDELAYE2 primitive'leriyle kurulur. Aynı tel üzerinde eşzamanlı full duplex iletişim yapılmaz.

## Gereksinimler

- Vivado **2024.1**, Kintex-7 cihaz desteği ve sentez/implementation için uygun lisans.
- Windows PowerShell veya PowerShell 7. Windows üzerinde doğrulanmıştır.
- `VIVADO_BIN`: Vivado kurulumunun `bin` dizini; alternatif olarak her komuta `-VivadoBin` verilebilir. Vivado araçları PATH'te ise otomatik bulunur.

## Çalıştırma

Depo kökünde, Vivado 2024.1 ortamı etkin bir PowerShell oturumunda:

```powershell
# Alternatif: $env:VIVADO_BIN = '<Vivado-2024.1-bin-dizini>'
./scripts/run_vivado.ps1 -Step create
./scripts/run_simulations.ps1
./scripts/run_vivado.ps1 -Step synth
./scripts/run_vivado.ps1 -Step route
./scripts/run_vivado.ps1 -Step audit
./scripts/run_vivado.ps1 -Step open
```

Proje `build/project/lvds62_vhdl.xpr`, yeni raporlar `build/reports/`, simülasyon çıktıları `build/sim/` altında oluşur. `create`, mevcut üretilmiş projeyi yeniden oluşturur. `route`, yalnızca **aday** pin dosyasını yükler; normal proje kısıtları gerçek kart pinlerini içermez. `audit`, routed checkpoint gerektirir. İsteğe bağlı `-Step archive`, Vivado proje ZIP'ini `build/` altında üretir.

Tcl scriptleri doğrudan da çalıştırılabilir:

```text
vivado -mode batch -source scripts/create_project.tcl
vivado -mode batch -source scripts/verify_implementation.tcl
vivado -mode batch -source scripts/route_candidate.tcl
vivado -mode batch -source scripts/audit_routed.tcl
vivado -mode gui -source scripts/open_design.tcl
```

## Loopback bağlantısı

Her bankta ilk yarıdaki çift ikinci yarıdaki eşiyle P→P, N→N bağlanır. Bank32/33: `i ↔ i+10`, i=0..9. Bank34: `i ↔ i+11`, i=0..10. Ayrıntı: [mantıksal bağlantı tablosu](hardware/LOOPBACK_BAGLANTILARI.csv). [Paket envanteri](hardware/PIN_ENVANTERI.csv), kart şemasının yerini tutmaz.

## Kaydedilen doğrulama

| Kontrol | 17 Kasım 2026 sonucu |
|---|---|
| VHDL testleri | 7/7 PASS |
| Gerçek UNISIM seri sistem testi | 62 çift, iki yönde 2.010.272 kontrol edilen bit, 0 hata |
| Sentez / GUI Validate Design | PASS |
| Aday routed setup / hold payı | +1,834 ns / +0,042 ns |
| TNS / THS | 0 / 0 |
| İstisna denetimi | 62 aynı-pad yol; 13 ikinci senkronizatör kademesi zamanlamalı |

Tarihsel log ve raporlar [evidence/2026-11-17](evidence/2026-11-17/) altındadır. Bunlar önceki yerel çalıştırmanın sonuçlarıdır; her yeni klonun otomatik olarak doğrulandığı anlamına gelmez. Yerel kullanıcı/host yolları `<LOCAL_PATH>`, `<PROJECT>` ve `<HOST>` işaretleriyle temizlenmiştir. RTL/testbench içerikleri değiştirilmemiştir.

GitHub hazırlığı sırasında bu depo konumundan proje yeniden oluşturuldu ve `scripts/run_simulations.ps1` ile **yedi test tekrar PASS** verdi. Simülasyon kanıtları bu yeni çalıştırmayla güncellendi; routed zamanlama kanıtı önceki doğrulanmış VHDL çalışmasına aittir. Scriptlerin taşınabilirliği için yapılan değişiklikler HDL mantığını değiştirmez.

Vivado DRC'deki LVDS-1, çift yönlü LVDS'nin sabit empedans/sonlandırma ve turnaround koşullarıyla ilgilidir. CFGBVS-1 kart konfigürasyon geriliminin bilinmemesinden kaynaklanır. Harici giriş/çıkış gecikmeleri de bilinmiyor. Bu yüzden iç zamanlama sonucu kart üzerindeki 1 Gbit/s BER başarısı olarak yorumlanamaz. Ayrıntılar: [tasarım ve VIO kullanımı](docs/design.tr.md), [doğrulama raporu](docs/validation.tr.md).

## Depo düzeni

```text
rtl/          Kullanıcı VHDL RTL kaynakları
sim/          VHDL testbench'leri
constraints/  Saat/istisnalar ve yalnızca aday pin eşlemesi
scripts/      Proje, simülasyon, sentez, route ve audit komutları
hardware/     Mantıksal loopback eşlemesi ve paket pin envanteri
docs/         Tasarım, doğrulama ve GitHub aktarım bilgileri
evidence/     Yerel yolları temizlenmiş tarihsel doğrulama kayıtları
build/        Yeniden üretilen dosyalar; Git dışında
```

GitHub deposu: [GoktugOzkeskin/xc7k160t-lvds62-vhdl](https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl), private. Klonlama ve aktarım bilgileri [GitHub rehberinde](docs/github.tr.md); lisans durumu [NOTICE.md](NOTICE.md) içindedir.

Depo içeriği denetimi (Python 3 ve Git): `python scripts/check_repository.py`. Bu komut paketleme, yerel yol ve üretilen dosya kontrollerini yapar; HDL simülasyonunun yerine geçmez.
