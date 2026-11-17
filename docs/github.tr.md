# GitHub'a aktarım

Yayınlama hedefi: [GoktugOzkeskin/xc7k160t-lvds62-vhdl](https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl), private, ana dal `main`. Klonlamak için `git clone https://github.com/GoktugOzkeskin/xc7k160t-lvds62-vhdl.git` kullanılır. İlk commit hesabın GitHub noreply adresini kullanır; global Git kimliği değiştirilmez.

Aşağıdaki adımlar ilk yerel hazırlığın kayıtları ve yeni bir hedefe aktarım örneğidir. İlk hazırlıkta kaynaklar commit için stage edildi; üretilen Vivado dosyaları `.gitignore` kapsamındadır.

Bu açıklama hazırlanmış yerel klasör için geçerlidir. Kaynak ZIP'ini başka yere çıkardıysanız önce `git init --initial-branch=main` ve `git add --all` çalıştırın; ZIP, `.git` veritabanını içermez.

1. GitHub hesabınızda boş bir depo oluşturun. Önerilen ad: `xc7k160t-lvds62-vhdl`. README veya lisansı GitHub tarafından ayrıca oluşturmayın; ilk yüklemeden sonra lisans eklenebilir.
2. Yerel depo klasöründe `git status` ve `git diff --cached --stat` ile içeriği gözden geçirin.
3. Git kimliği ayarlı değilse kendi adınız/e-postanızla ayarlayın. Ardından:

```text
git commit -m "Add VHDL LVDS62 loopback design and validation evidence"
git remote add origin https://github.com/OWNER/REPOSITORY.git
git push -u origin main
```

`OWNER/REPOSITORY` gerçek hedefle değiştirilmelidir. Kimlik doğrulama GitHub'ın normal Git akışıyla yapılır; erişim anahtarını kaynak dosyalarına yazmayın.

GitHub'ın barındırdığı standart runner'larda lisanslı Vivado/UNISIM ortamı bulunmadığından doğrulanmamış HDL CI sonucu veya başarı rozeti eklenmedi. HDL doğrulaması README'deki Vivado komutlarıyla çalıştırılır. Araç/lisans sağlanan bir self-hosted runner daha sonra eklenebilir.

Proje ZIP'i, checkpoint ve waveform gibi yeniden üretilebilen büyük dosyaları Git'e eklemeyin. Gerekirse ayrı bir GitHub Release eki olarak paylaşılabilir; kaynak deposu bunlara bağımlı değildir.
