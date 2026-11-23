# GitHub kullanımı

Public depo: https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl
Ana dal: main. Güncel kart varyantı: board52.

```text
git clone https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl.git
cd xc7k160t-lvds62-vhdl
```

Hazır bitstream, probe, proje ve routed checkpoint dosyaları [BOARD52 ön sürümünde](https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl/releases/tag/board52-2026-11-23) bulunur. Dosya bütünlüğünü Release SHA256SUMS.txt manifestiyle kontrol edin. Kartın beslemesi, reset polaritesi, sonlandırması ve harici zamanlaması teyit edilmeden fiziksel başarı varsayılmamalıdır.

Kaynak değişikliklerini gözden geçirip ilgili testleri çalıştırdıktan sonra:

```text
git status
git diff
git add --all
git commit -m "Describe the change"
git push origin main
```

Git kimlik doğrulaması Git Credential Manager ile yapılabilir. Erişim anahtarlarını kaynaklara yazmayın. Git global kimliği bu hazırlıkta değiştirilmedi. ZIP paketleri .git veritabanını içermez; sürüm geçmişi için klonlama kullanılır.

Vivado kurulu/lisanslı bir runner yapılandırılmadı; GitHub-hosted HDL CI başarısı veya rozeti yoktur. Windows/Vivado 2024.1 yerel çalıştırma komutları README'dedir. Üretilen büyük dosyalar kaynak geçmişine eklenmez, Release eki olarak yayımlanır. Açık kaynak lisansı seçilmedi; NOTICE.md durumu açıklar.
