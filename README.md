# Kasa+

**Günlük gelir/gider takibi — iOS (SwiftUI, offline-first).**

Kasa+, gün içindeki harcamalarınızı ve gelirlerinizi saniyeler içinde
kaydetmek, kategorilere ayırmak ve zaman içindeki finansal durumu grafiklerle
takip etmek için tasarlandı. Uygulama **internetsiz tam fonksiyoneldir**;
bağlantı geldiğinde veriler arka planda iCloud'a yedeklenir.

---

## 1. Hızlı başlangıç (2 dakika)

1. `KasaPlus.xcodeproj` dosyasına çift tıklayın (Xcode 16 veya üzeri).
2. Üst çubukta hedef olarak **KasaPlus** + bir **iPhone simülatörü** seçin.
3. **⌘R** ile çalıştırın.

Giriş ekranında, Apple Developer hesabı henüz bağlı değilken denemek için
**"Geliştirme modunda devam et"** bağlantısını kullanabilirsiniz
(bu buton yalnızca Debug derlemelerinde görünür, App Store sürümünde yer almaz).

> Uygulama bu haliyle Firebase olmadan da eksiksiz çalışır: tüm veriler
> cihazda SwiftData ile saklanır. Firebase eklendiğinde bulut yedekleme
> otomatik olarak devreye girer (Adım 3).

---

## 2. Adım 1 — Sign in with Apple (gerçek giriş için)

Sign in with Apple, ücretli bir **Apple Developer Program** üyeliği gerektirir.

1. Xcode → sol panelde **KasaPlus** projesi → **TARGETS ▸ KasaPlus**
2. **Signing & Capabilities** sekmesi
3. **Team**: kendi geliştirici ekibinizi seçin
4. **Bundle Identifier**: `com.kasaplus.app` yerine size ait benzersiz bir kimlik
   yazın (örn. `com.eczanem.kasaplus`)
5. **+ Capability** → **Sign in with Apple** ekleyin

Xcode gerekli entitlement dosyasını kendisi oluşturur. Depoda hazır bir örnek de
var: `KasaPlus.entitlements` (varsayılan olarak projeye bağlı değildir, böylece
hesap tanımlamadan da derleme yapılabilir).

### Neye ihtiyacım var?
| Bilgi | Nereden | Ne zaman |
|---|---|---|
| Apple Developer hesabı | developer.apple.com | Adım 1 |
| Benzersiz Bundle ID | Kendiniz belirlersiniz | Adım 1 |
| `GoogleService-Info.plist` | Firebase Console | Adım 3 |

---

## 3. Adım 2 — Firebase projesi oluşturma

1. [Firebase Console](https://console.firebase.google.com) → **Add project**
   (Spark / ücretsiz plan yeterlidir).
2. Sol menü → **Build ▸ Authentication** → **Get started** →
   **Sign-in method** → **Apple** sağlayıcısını etkinleştirin.
   - Servis kimliği ve anahtar bilgileri Apple Developer hesabınızdan gelir;
     Firebase ekranındaki yönergeleri izleyin.
3. Sol menü → **Build ▸ Firestore Database** → **Create database**
   → **Production mode** → bölge olarak `eur3` veya `europe-west` önerilir.
4. **Rules** sekmesine bu depodaki [`firestore.rules`](firestore.rules)
   dosyasının içeriğini yapıştırıp **Publish** deyin.
   Kurallar, her kullanıcının yalnızca kendi verisine erişmesini sağlar.
5. **Project settings ▸ General ▸ Your apps ▸ iOS** → uygulamanızı ekleyin
   (Bundle ID = Adım 1'de belirlediğiniz kimlik) →
   **GoogleService-Info.plist** dosyasını indirin.

---

## 4. Adım 3 — Firebase'i uygulamaya bağlama

1. İndirdiğiniz **`GoogleService-Info.plist`** dosyasını Xcode'da
   `KasaPlus/Resources/` klasörüne sürükleyin.
   Açılan pencerede **"Copy items if needed"** işaretli olsun ve
   **Target: KasaPlus** seçili olsun.
2. Xcode → **File ▸ Add Package Dependencies…**
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Dependency Rule: **Up to Next Major Version**
   - Eklenecek ürünler: **FirebaseAuth** ve **FirebaseFirestore**
     (diğerlerini seçmeyin — derleme süresi uzar)
3. **⌘R**. Başka hiçbir kod değişikliği gerekmez.

**Nasıl çalışıyor?** Senkronizasyon katmanı `RemoteDataSource` protokolünün
arkasına alınmıştır. Firebase SDK yokken `DisabledRemoteDataSource` kullanılır ve
uygulama tamamen yerel çalışır. SDK eklendiği anda `#if canImport(FirebaseFirestore)`
koşulu sağlanır ve `FirestoreRemoteDataSource` otomatik devreye girer
(`Core/Sync/RemoteDataSource.swift`).

Ayarlar ▸ **Bulut Yedekleme** bölümünde durumu ve son yedekleme zamanını
görebilir, **"Şimdi Yedekle"** ile elle senkronizasyon tetikleyebilirsiniz.

---

## 5. Mimari

```
KasaPlus/
├── App/                      Uygulama girişi ve oturum kabı
│   ├── KasaPlusApp.swift     @main — Firebase/arka plan görevi kurulumu
│   ├── RootView.swift        Oturum + uygulama kilidi yönlendirmesi
│   ├── MainTabView.swift     Sekmeler
│   └── AppSession.swift      Composition root (repository'ler + sync)
├── Core/
│   ├── Models/               SwiftData modelleri ve enum'lar
│   ├── Persistence/          ModelContainer, hazır kategoriler, veri taşıma
│   ├── Repositories/         Repository protokolleri + SwiftData uygulamaları
│   ├── Sync/                 RemoteDataSource, Firestore, SyncService, BGTask
│   ├── Auth/                 Sign in with Apple, Keychain, Face ID kilidi
│   ├── Currency/             Kur servisi (frankfurter.app) + dönüştürücü
│   ├── Notifications/        Yerel bildirimler, aksiyonlar, yönlendirme
│   ├── Reporting/            Saf hesaplama katmanı (özet, dağılım, trend)
│   └── Utils/                Tema, biçimlendiriciler, tarih yardımcıları, ayarlar
├── Features/
│   ├── Auth/                 Giriş ve kilit ekranları
│   ├── Transactions/         Liste, editör, filtre (MVVM)
│   ├── PlannedPayments/      Planlı ödemeler, editör, erteleme yaprağı
│   ├── Dashboard/            Özet ekranı
│   ├── Reports/              Donut + trend + dönem karşılaştırma
│   ├── Categories/           Kategori yönetimi ve editörü
│   ├── Banks/                Banka yönetimi
│   ├── Settings/             Ayarlar
│   └── Components/           Paylaşılan görünümler
└── Resources/                Assets.xcassets (ikon, renkler)
```

**Katmanlar (MVVM + Repository):**

```
View  →  ViewModel  →  Repository protokolü  →  SwiftData (yerel)
                                              ↘  RemoteDataSource (Firestore)
```

- ViewModel'ler SwiftData'yı doğrudan bilmez; yalnızca protokolleri kullanır.
- `AppSession` her yazma işleminden sonra `dataVersion` sayacını artırır;
  ekranlar bu değişimi izleyerek kendini tazeler.
- Rapor hesaplamaları (`Core/Reporting/ReportBuilder.swift`) tamamen saf
  fonksiyonlardır — UI'dan bağımsız olarak test edilebilir.

### Genişletilebilirlik (PRD Bölüm 7)
| Gereksinim | Nasıl karşılandı |
|---|---|
| Çoklu kullanıcıya geçiş | Tüm modellerde `userID` alanı baştan var; repository'ler kullanıcıya göre filtreler. Kimlik değişiminde `OwnershipMigrator` verileri taşır. |
| Yeni kategori / ödeme yöntemi | `PaymentMethod` ve `Currency` enum'larına case eklemek yeterli; veritabanında `rawValue` saklandığı için göç gerekmez. |
| Veri kaynağı değişimi | `TransactionRepositoryProtocol` / `CategoryRepositoryProtocol` / `RemoteDataSource` soyutlamaları. |
| Ek Firebase modülleri | `FirebaseApp.configure()` tek noktada; yeni ürünler SPM'den eklenebilir. |

---

## 6. Planlı Ödemeler ve hatırlatmalar

Gelir/gider gibi ayrı bir sekmedir (**Planlı**). Kira, fatura, çek, tedarikçi
ödemesi gibi ileri tarihli ödemeleri buraya kaydedersiniz.

**Bildirimler (tamamı yerel — sunucu veya push sertifikası gerekmez):**

| Ne zaman | İçerik |
|---|---|
| Vadeden **1 hafta** önce | "Yaklaşan ödeme: … — vade …" |
| Vadeden **1 gün** önce | "Yarın ödeme günü: …" |
| **Vade günü** | "Bugün ödeme günü: … — bu tutar giderlere eklensin mi?" + **Ödedim** / **Ertele** butonları |

- **Ödedim** → planlanan ödeme otomatik olarak bir **gider işlemine** dönüşür
  (tutar, para birimi, kategori, ödeme yöntemi ve banka bilgisi taşınır).
  Uygulama kapalıyken de çalışır: iOS uygulamayı arka planda başlatır,
  kayıt yazılır ve bildirimler iptal edilir.
- **Ertele** → uygulama öne gelir ve tarih seçme yaprağı açılır
  (hızlı seçenekler: 1 gün / 3 gün / 1 hafta / 15 gün / 1 ay, ya da takvimden).
  Yeni vadeye göre üç hatırlatma baştan kurulur.

Aynı işlemler listede kaydırma hareketiyle de yapılabilir (sola: Sil / Ertele,
sağa: Ödedim). Ödenen bir kaydı "Geri al" ile geri çevirdiğinizde oluşturulan
gider işlemi de silinir.

Bildirim izni ilk planlı ödeme kaydedilirken istenir; Ayarlar ▸ Bildirimler
bölümünden durum görüntülenebilir. iOS uygulama başına en fazla 64 bekleyen
bildirim tuttuğu için vadesi en yakın **20** ödeme planlanır; kırpma olursa
Ayarlar'da uyarı gösterilir.

---

## 7. Ödeme yöntemleri ve bankalar

Ödeme yöntemleri: **Nakit, Kredi Kartı, Banka Kartı, Banka Transferi, Çek.**

Nakit **dışındaki** her yöntemde kayıt ekranında bir **Banka** alanı belirir.
Uygulama dört hazır bankayla gelir — Ziraat Bankası, İş Bankası, Akbank, TEB —
ve **Ayarlar ▸ Yönetim ▸ Bankalar** ekranından:

- yeni banka eklenebilir,
- adı değiştirilebilir,
- **Düzenle** moduna girip sürükleyerek sıralanabilir,
- silinebilir (bağlı işlemler korunur, "Silinmiş banka" olarak görünür).

Aynı düzenle/sırala/sil yetenekleri **Kategoriler** ekranında da vardır.
Bu sıra, kayıt ekranındaki kategori ve banka listelerinde de geçerlidir.

İşlem listesinde banka adı satır altında görünür ve filtre ekranından
bankaya göre filtreleme yapılabilir.

---

## 8. Senkronizasyon nasıl çalışıyor?

1. **Yerel önce.** Her kayıt önce SwiftData'ya yazılır; UI anında güncellenir.
2. **Çekme.** `lastSyncDate`'ten sonra değişen uzak kayıtlar çekilir ve yerele
   uygulanır. Çakışmada `updatedAt` değeri büyük olan kazanır (last-write-wins).
3. **Gönderme.** `syncedAt < updatedAt` olan yerel kayıtlar Firestore'a yazılır
   (500'lük batch sınırı gözetilerek 400'lük parçalar hâlinde).
4. **Silme.** Silinen kayıtlar hemen yok edilmez; `isRemoved = true` mezar taşı
   olarak işaretlenip buluta bildirilir, 30 gün sonra yerelden temizlenir.

**Ne zaman tetiklenir?**
- Uygulama açılışında ve arka plandan öne gelişte
- `BGTaskScheduler` ile arka planda (kimlik: `com.kasaplus.sync`, en erken 4 saatte bir)
- Ayarlar ▸ "Şimdi Yedekle" ile elle

---

## 9. Çoklu para birimi

- Her işlem kendi para birimini taşır (TRY / USD / EUR / GBP).
- İşlem listesinde kayıtlar **orijinal** para birimiyle gösterilir; altında
  ana para birimi karşılığı (`≈ ₺…`) ikincil satır olarak görünür.
- Raporlarda tüm tutarlar **ana para birimine** (varsayılan TRY) çevrilerek toplanır.
- Kur kaynağı: [frankfurter.app](https://www.frankfurter.app) — ücretsiz, API
  anahtarı gerektirmez, ECB verisi. **Günde bir kez** çekilir ve
  `Application Support/exchange-rates.json` içinde cache'lenir.
- Kur alınamazsa son bilinen kur kullanılır ve ekranda uyarı gösterilir.

Ana para birimini **Ayarlar ▸ Para Birimi** bölümünden değiştirebilirsiniz.

---

## 10. Güvenlik

- Oturum bilgileri (userID, Apple kimliği, ad, e-posta) **Keychain**'de saklanır
  (`kSecAttrAccessibleAfterFirstUnlock`), UserDefaults'ta değil.
- Uygulama kilidi: **Face ID / Touch ID**, başarısızlıkta **cihaz parolası**
  fallback'i (`LAPolicy.deviceOwnerAuthentication`). Arka planda 15 saniyeden
  uzun kalınırsa yeniden kilitlenir.
- Firestore'da her kullanıcı yalnızca `users/{kendi uid}` altını okuyup yazabilir
  (bkz. `firestore.rules`).
- `GoogleService-Info.plist` `.gitignore` içindedir; anahtarlarınızı depoya
  göndermeyin.

---

## 11. Kabul kriterleri durumu

| # | Kriter | Durum |
|---|---|---|
| 1 | Apple ID ile giriş, Face ID kilidi | ✅ (Sign in with Apple için Adım 1 gerekli) |
| 2 | Gelir/gider ekleme, düzenleme, silme (onaylı) | ✅ |
| 3 | Hazır kategoriler + kullanıcı kategorileri (ad/ikon/renk) | ✅ |
| 4 | Tarihe göre gruplu işlem listesi | ✅ (gün başlıkları + günlük net) |
| 5 | Dashboard: toplam gelir / gider / bakiye | ✅ |
| 6 | Kategori dağılım grafiği (donut) | ✅ |
| 7 | Haftalık / aylık / yıllık trend + dönem karşılaştırma | ✅ |
| 8 | Offline-first tam fonksiyon | ✅ |
| 9 | Periyodik otomatik + manuel Firebase yedekleme | ✅ (Adım 3 sonrası aktif) |
| 10 | Dark Mode | ✅ (sistem/aydınlık/karanlık seçimi) |
| 11 | iPhone'da native, HIG uyumlu görünüm | ✅ |
| 12 | Çoklu para birimi + kur çevrimi | ✅ |
| 13 | Ödeme yöntemi: Çek ve Banka Kartı | ✅ |
| 14 | Nakit dışı yöntemlerde banka seçimi + banka yönetimi | ✅ |
| 15 | Planlı ödemeler + 1 hafta / 1 gün / vade günü hatırlatma | ✅ |
| 16 | Vade bildiriminde Ödedim / Ertele aksiyonları | ✅ |
| 17 | Kategori ve banka listelerinde sıralama ve silme | ✅ |

---

## 12. Kapsam dışı (MVP'de yok)

Fatura fotoğrafı & OCR, **yinelenen (recurring) planlı ödemeler**, bütçe
hedefleri, Excel/PDF dışa aktarma, çoklu kullanıcı paylaşımı, Android, web paneli. Mimari bunların hiçbirine
kapalı değildir — bkz. Bölüm 5 "Genişletilebilirlik".

---

## 13. Gereksinimler

- Xcode 16+
- iOS 17.0+ (SwiftData, Swift Charts, `@Observable`)
- Yalnızca iPhone (portre)
- Swift 5 dil modu
