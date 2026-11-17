# 62 çift, çift yönlü LVDS — VHDL

Hedef: XC7K160T-FBG676-1, HP bank 32/33/34; sırasıyla 20/20/22 diferansiyel çift. Referans saat **156,250 MHz**. Kullanıcı RTL kaynakları, testbench'ler ve Vivado üst sarmalayıcısı VHDL'dir. Önceki Verilog tasarımından bağımsız olarak yeniden yazılmıştır.

`scripts/create_project.tcl`, Vivado 2024.1 içinde gerçek `lvds_vhdl_bd` blok tasarımını oluşturur. Üretilecek proje `build/project/lvds62_vhdl.xpr` konumundadır. Projeyi yeniden üretmek için:

```
vivado -mode batch -source scripts/create_project.tcl
```

## Fiziksel bağlantı ve hız

Her bankta ilk yarıdaki çift, aynı bankta ikinci yarıdaki eşine bağlanır: bank32 ve bank33 için i ↔ i+10 (i=0..9), bank34 için i ↔ i+11 (i=0..10). Toplam 31 harici loopback bağlantısı, P→P ve N→N. Her iki uç gerçek `inout` porttur. İlk testte ilk yarı sürer, ikinci yarı alır; sonraki testte roller tersine döner. Böylece 62 çiftin tamamı hem TX hem RX olarak test edilir. Aynı tel üzerinde eşzamanlı çift yönlü iletim yapılmaz.

MMCM: 156,25 / 5 × 32 = 1000 MHz VCO; çıkışlar 500 MHz seri, 125 MHz paralel, 200 MHz IDELAY referansıdır. 8:1 DDR serileştirme ile her aktif çiftte 1 Gbit/s elde edilir. Aynı anda 31 çift TX ve karşılık gelen 31 çift RX çalışır.

SelectIO Wizard bu cihazda BIDIR+DIFF+LVDS birleşimini kabul etmediğinden, aynı SelectIO yapı taşları VHDL içinde açıkça kullanılır: IOBUFDS, OSERDESE2, ISERDESE2, IDELAYE2 ve her bank için IDELAYCTRL. Gerçekte desteklenmeyen bir Wizard konfigürasyonu kullanılmamıştır.

## İşleyiş

Her yön değişiminde tüm uçlar önce 64 paralel çevrim yüksek empedansa geçer. Alıcı başına 32 IDELAY kademesi taranır; her kademede sekiz DDR BITSLIP konumu denenir. En geniş geçerli pencerenin ortası seçilir ve tekrar doğrulanır. En az üç kademe genişlik gerekir. BITSLIP darbeleri bir CLKDIV çevrimidir ve aralarında bekleme bulunur.

Ardından her bağlantıya, banka, kanala ve yöne özgü PRBS31 verisi gönderilir. Karşılaştırıcı geçmişteki gönderim kelimeleri arasından gecikmeyi bulur; art arda sekiz eşleşmeden sonra kilitlenir. Kilitliyken hatalı veriyi yeniden kilitlenerek gizlemez. XOR, boru hatlı bit sayımı ve ayrı yön sayaçları kullanılır. Son kelimenin hatasını kaybetmemek için 16 çevrim boşaltma vardır. Varsayılan test süresi her yön için 16.777.216 paralel kelimedir (yaklaşık 134 ms + eğitim).

Her iki yön tamamlanmadan PASS üretilmez. Bit hatası, hizalama başarısızlığı, kalibrasyon kaybı ve saat/heartbeat kaybı FAIL üretir. FAIL açıkça temizlenene kadar tutulur. Üst sonuç birimi MMCM çıkışından bağımsız, ham 156,25 MHz referansla çalışır. Referans osilatörünün kendisinin tamamen durmasını FPGA içinden bağımsız saat olmadan saptamak mümkün değildir; bu durum için harici gözlem gerekir.

## VIO / ILA kullanımı

`bankXX_VIO`: çıkış0 run_enable (başlangıç 1), çıkış1 restart, çıkış2 clear_errors, çıkış3 inject_error. Darbe kontrollerini en az bir 125 MHz çevrim etkin tutun; Hardware Manager üzerinden 1 ardından 0 yazmak yeterlidir. `clear_errors`, sayaçları ve sonucu temizleyip testi yeniden başlatır. `restart` tek başına kalıcı hata geçmişini temizlemez.

Girişler: monitor128, ileri/geri hata bitleri (64'er), ileri/geri kontrol edilen bitler (64'er), tamamlanan ileri/geri test sayısı (32'şer), kanal hata maskesi. Üç ILA; TX/RX kelimelerini, tristate, BITSLIP, durum, hizalama, gecikme ve karşılaştırma kilidini gösterir.

`RESULT_VIO` giriş0 16-bit sonuçtur: bit0 genel PASS, bit1 genel FAIL, bit2 tüm bank sonuçları geçerli, bit5..3 bank PASS, bit8..6 bank FAIL, bit11..9 geçerlilik, bit12 MMCM lock. Çıkış0 üst watchdog hata temizlemesidir; bank hatalarını temizlemek için ilgili bank clear_errors kontrolünü de kullanın. PASS=0 ve FAIL=0, testin henüz tamamlanmadığını gösterir.

Bank monitor düşük baytı: bit3..0 FSM (STOP=0, GUARD=1, TRAINING=2, RUN=3, SWAP=4, FAULT=5, DRAIN=6), bit4 yön, bit5 fault, bit6 valid, bit7 pass.

## Simülasyonlar

`scripts/run_simulations.ps1` yedi VHDL testini xvhdl/xelab/xsim ile derler ve çalıştırır. RTL VHDL-93, testbench'ler VHDL-2008 kullanır. Vendor UNISIM modelleri gerçektir; seri PHY davranışsal bir serileştiriciyle değiştirilmemiştir. Simülasyonda yalnızca test süresi/heartbeat sayaçları kısaltılır.

| Test | Doğrulanan davranış | Sonuç |
|---|---|---|
| compare | Farklı kanal gecikmeleri, tek bit, X/Z, son kelime, sayım korunumu | PASS; 4896 bit, beklenen 50 hata |
| align | Ayrık göz pencereleri, en geniş pencere merkezi, DDR BITSLIP, dar/boş göz reddi | PASS |
| bank | İleri/geri yön, hata enjeksiyonu, son kelime hatası, temizleme, temiz PASS, RDY kaybı, kopuk kablo | PASS |
| ready | IDELAYCTRL hiç hazır olmazsa zaman aşımı ve yüksek empedans | PASS |
| result | Bekleme/PASS/FAIL, heartbeat ve MMCM kaybı, temizleme | PASS |
| phy | Üç bank, gerçek MMCM ve UNISIM seri primitive zinciri | PASS |
| system | 62 çift, 31 kablo, iki yön, gerçek MMCM/SerDes, tüm sonuç zinciri | PASS; 2.010.272 bit, 0 hata |

Son sistem simülasyonu 87,280 µs'de genel PASS üretmiştir. Bank32/33 her yönde 324.240, bank34 her yönde 356.656 bit karşılaştırmıştır. Bu dijital işlev doğrulamasıdır; kart üzerinde BER ölçümü değildir.

## Kart verisi olmadan kalan sınırlar

`constraints/timing.xdc` yalnızca bilinen 156,25 MHz saat ve LVDS standardını içerir. Gerçek pin/net listesi, saat girişi pini, reset pini/gerilimi, VCCO, sonlandırma, harici gecikmeler ve PCB/kablo bilgisi verilmedi. Bunlar uydurulmamıştır. Bir aday pin dizilimiyle yapılan yerleştirme/yönlendirme raporları varsa yalnızca FPGA kaynak/zamanlama araştırmasıdır; kart pin onayı değildir.

Saat kısıtındaki 100 ps giriş jitter değeri bir doğrulama varsayımıdır; gerçek osilatörün jitter bilgisi sağlanınca değiştirilmelidir. Aday pin dosyasındaki reset pini/standardı da yalnızca yerleştirme deneyi içindir.

`constraints/logic_exceptions.xdc` yalnızca 13 senkronizatör ilk kademesi ve 62 aynı fiziksel pad üzerindeki kullanılmayan TX→kendi RX yolunu kapsar. İkinci senkronizatör kademesi ve karşı kablo ucundaki aktif alıcı bunun dışındadır. Aday pin dosyası normal proje kısıtlarına eklenmez; yalnızca `route_candidate.tcl` tarafından açıkça yüklenir. `verify_implementation.tcl` sentez raporlarını, `route_candidate.tcl` aday yerleştirme/yönlendirme raporlarını üretir. Harici giriş/çıkış gecikmeleri bilinmediğinden tam I/O zamanlama kapanışı iddia edilemez.

HP LVDS çift yönlü IOBUFDS yapısında Vivado'nun LVDS-1 sonlandırma uyarısı ayrıca değerlendirilmelidir. Yön değişimindeki elektriksel sonlandırma davranışı ve 1,8 V bank beslemesi gerçek şemayla doğrulanmalıdır. Dijital simülasyon analog göz açıklığını garanti etmez. Bitstream istenmediği için üretilmez.

Kaynaklar: AMD [UG471 SelectIO](https://docs.amd.com/v/u/en-US/ug471_7Series_SelectIO), [DS182 Kintex-7](https://docs.amd.com/v/u/en-US/ds182_Kintex_7_Data_Sheet), [UG475 package/pinout](https://docs.amd.com/v/u/en-US/ug475_7Series_Pkg_Pinout). Bu cihazın HP -1 hız sınıfında veri sayfası DDR LVDS sınırı 1250 Mb/s'dir; 1 Gb/s hedefi bu sınır içindedir.
