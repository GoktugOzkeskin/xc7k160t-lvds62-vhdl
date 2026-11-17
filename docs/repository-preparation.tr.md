# GitHub hazırlığı

17 Kasım 2026 tarihinde doğrulanmış VHDL çalışmasından bağımsız kaynak deposu hazırlandı.

- Yedi RTL ve altı testbench dosyası korundu; yalnızca satır sonları/son boşluklar normalize edildi.
- Proje oluşturma ve kontrol scriptleri depo kökünü kendi konumlarından bulur. Makineye özel masaüstü yolu yoktur.
- Vivado yolu `VIVADO_BIN`, `-VivadoBin` veya PATH üzerinden seçilir.
- Üretilen proje, IP, checkpoint, waveform ve loglar `build/` altında tutulur; Git'e eklenmez.
- Tarihsel doğrulama kayıtlarından yerel kullanıcı ve host yolları temizlendi; sayısal sonuçlar ve araç telif bildirimleri korundu.
- İlk hazırlıkta yerel `main` dalı ve ilk commit için stage edilmiş içerik oluşturuldu. Ardından proje sahibinin talebiyle `GoktugOzkeskin/xc7k160t-lvds62-vhdl` private GitHub deposuna yayınlama akışı başlatıldı. Açık kaynak lisansı seçilmedi.

Yeni depo konumundan Vivado 2024.1 ile `create` adımı tekrar çalıştırıldı ve blok tasarımı PASS verdi. PowerShell scriptlerinin sözdizimi, kaynak paketinin kişisel yol/üretilen dosya denetimi ve Git whitespace kontrolü geçti. `run_simulations.ps1` yeni depo konumundan yedi VHDL testini tekrar çalıştırdı ve tamamı PASS verdi. 62 çiftlik tam seri test 87,280 µs simülasyon zamanında genel PASS üretti. Yeni simülasyon kanıtları evidence altına kaydedildi; önceki routed zamanlama raporları tarihsel sonuç olarak korundu.

İçerik denetimi: `python scripts/check_repository.py`. Yayınlama adımları: [github.tr.md](github.tr.md).
