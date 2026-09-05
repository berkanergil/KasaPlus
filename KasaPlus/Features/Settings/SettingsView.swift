import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(AppleAuthService.self) private var authService
    @Environment(BiometricLockService.self) private var lockService
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL

    @State private var isCategoryManagerPresented = false
    @State private var isBankManagerPresented = false
    @State private var isSignOutConfirmationPresented = false
    @State private var isSyncing = false
    @State private var syncMessage: String?

    var body: some View {
        NavigationStack {
            List {
                profileSection
                securitySection
                notificationSection
                backupSection
                managementSection
                currencySection
                appearanceSection
                languageSection
                aboutSection
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $isCategoryManagerPresented) {
                CategoryManagementView()
            }
            .sheet(isPresented: $isBankManagerPresented) {
                BankManagementView()
            }
            .confirmationDialog(
                "Oturumu kapat",
                isPresented: $isSignOutConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Oturumu kapat", role: .destructive) {
                    authService.signOut()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Verileriniz cihazınızda kalır. Tekrar giriş yaptığınızda kaldığınız yerden devam edersiniz.")
            }
            .task { await notifications.refreshAuthorizationStatus() }
        }
    }

    // MARK: - Profil

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                AppLogoMark(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.user.displayName ?? L10n.text("Kasa+ Kullanıcısı"))
                        .font(.headline)
                        .lineLimit(1)
                    Text(session.user.email?.isEmpty == false
                         ? (session.user.email ?? "")
                         : L10n.text("Apple ID ile giriş yapıldı"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.vertical, 4)

            Button("Oturumu kapat", role: .destructive) {
                isSignOutConfirmationPresented = true
            }
        } header: {
            Text("Profil")
        }
    }

    // MARK: - Güvenlik

    private var securitySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { lockService.isEnabled },
                set: { newValue in
                    Task { await lockService.setEnabled(newValue) }
                }
            )) {
                SettingsRowLabel(
                    title: L10n.format("%@ ile kilitle", lockService.biometryDescription),
                    systemImage: "faceid",
                    tint: AppTheme.accent
                )
            }
            .disabled(!lockService.isBiometryAvailable)

            if !lockService.isBiometryAvailable {
                Text("Bu cihazda biyometrik doğrulama veya cihaz parolası tanımlı değil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Güvenlik")
        } footer: {
            Text("Uygulama açıldığında ve arka plandan döndüğünde kimlik doğrulaması istenir.")
        }
    }

    // MARK: - Bildirimler

    private var notificationSection: some View {
        Section {
            SettingsValueRow(
                title: L10n.text("Durum"),
                systemImage: "bell.badge",
                tint: notifications.isAuthorized ? AppTheme.income : .orange,
                value: notifications.statusDescription
            )

            if notifications.isAuthorized {
                SettingsValueRow(
                    title: L10n.text("Kurulu hatırlatma"),
                    systemImage: "clock.badge.checkmark",
                    tint: AppTheme.accent,
                    value: "\(notifications.scheduledCount)"
                )

                if notifications.skippedPaymentCount > 0 {
                    Text("iOS'un bildirim sınırı nedeniyle en yakın vadeli 20 ödeme hatırlatılıyor; \(notifications.skippedPaymentCount) ödeme sıraya alınmadı.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        let content = UNMutableNotificationContent()
                        content.title = L10n.text("Kasa+ Hatırlatma")
                        content.body = L10n.text("Bu bir test bildirimidir.")
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
                        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
                        try? await UNUserNotificationCenter.current().add(request)
                    }
                } label: {
                    SettingsRowLabel(title: L10n.text("Bildirimi Test Et (3 sn)"), systemImage: "bell.and.waves.left.and.right", tint: .blue)
                }
            } else if notifications.authorizationStatus == .notDetermined {
                Button {
                    Task {
                        await notifications.requestAuthorizationIfNeeded()
                        session.scheduleReminders()
                    }
                } label: {
                    SettingsRowLabel(title: L10n.text("Bildirimlere izin ver"), systemImage: "bell", tint: AppTheme.accent)
                }
            } else {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    SettingsRowLabel(title: L10n.text("iOS Ayarları'nı aç"), systemImage: "gear", tint: .orange)
                }
            }
        } header: {
            Text("Bildirimler")
        } footer: {
            Text("Planlı ödemeler için vadeden 1 hafta önce, 1 gün önce ve vade günü hatırlatma gönderilir. Vade günü bildiriminde \"Ödedim\" ve \"Ertele\" seçenekleri bulunur.")
        }
    }

    // MARK: - Yedekleme

    private var backupSection: some View {
        Section {
            SettingsValueRow(
                title: L10n.text("Durum"),
                systemImage: "icloud",
                tint: session.syncService.isCloudConfigured ? AppTheme.income : .secondary,
                value: session.syncService.cloudStatusDescription
            )

            SettingsValueRow(
                title: L10n.text("Son yedekleme"),
                systemImage: "clock.arrow.circlepath",
                tint: AppTheme.accent,
                value: session.syncService.lastSyncDescription
            )

            Button {
                Task {
                    isSyncing = true
                    let success = await session.syncService.syncNow()
                    isSyncing = false
                    syncMessage = success
                        ? L10n.text("Yedekleme tamamlandı.")
                        : (syncErrorText ?? L10n.text("Yedekleme yapılamadı."))
                }
            } label: {
                HStack {
                    SettingsRowLabel(
                        title: L10n.text("Şimdi Yedekle"),
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: AppTheme.accent
                    )
                    if isSyncing {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isSyncing || !session.syncService.isCloudConfigured)

            if let syncMessage {
                Text(syncMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Bulut Yedekleme")
        } footer: {
            Text(session.syncService.isCloudConfigured
                 ? "Veriler uygulama her açıldığında ve arka planda düzenli olarak yedeklenir."
                 : "Uygulama tam fonksiyonel çalışmakta olup, cihazınızdaki veriler iCloud aracılığıyla yedeklenebilir.")
        }
    }

    private var syncErrorText: String? {
        if case .failed(let message) = session.syncService.state { return message }
        return nil
    }

    // MARK: - Yönetim (kategoriler & bankalar)

    private var managementSection: some View {
        Section {
            Button {
                isCategoryManagerPresented = true
            } label: {
                SettingsDisclosureRow(
                    title: L10n.text("Kategoriler"),
                    systemImage: "square.grid.2x2",
                    tint: AppTheme.income,
                    value: "\(session.categories.count)"
                )
            }

            Button {
                isBankManagerPresented = true
            } label: {
                SettingsDisclosureRow(
                    title: L10n.text("Bankalar"),
                    systemImage: "building.columns",
                    tint: AppTheme.accent,
                    value: "\(session.banks.count)"
                )
            }
        } header: {
            Text("Yönetim")
        } footer: {
            Text("Kategori ve banka listelerini düzenleyebilir, sıralayabilir ve silebilirsiniz.")
        }
    }

    // MARK: - Para birimi

    private var currencySection: some View {
        Section {
            // `.navigationLink` stili: uzun para birimi adları satıra sığmadığında
            // alt ekrana taşınır — satır taşması olmaz.
            Picker(selection: Binding(
                get: { settings.mainCurrency },
                set: { settings.mainCurrency = $0 }
            )) {
                ForEach(Currency.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            } label: {
                SettingsRowLabel(
                    title: L10n.text("Ana para birimi"),
                    systemImage: "chart.bar.doc.horizontal",
                    tint: AppTheme.accent
                )
            }
            .pickerStyle(.navigationLink)

            Picker(selection: Binding(
                get: { settings.defaultEntryCurrency },
                set: { settings.defaultEntryCurrency = $0 }
            )) {
                ForEach(Currency.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            } label: {
                SettingsRowLabel(
                    title: L10n.text("Yeni kayıt birimi"),
                    systemImage: "plus.square",
                    tint: AppTheme.accent
                )
            }
            .pickerStyle(.navigationLink)

            Button {
                Task { await exchangeRates.refresh() }
            } label: {
                HStack {
                    SettingsRowLabel(
                        title: L10n.text("Kurları güncelle"),
                        systemImage: "arrow.clockwise",
                        tint: AppTheme.accent
                    )
                    if exchangeRates.isRefreshing {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(exchangeRates.isRefreshing)
        } header: {
            Text("Para Birimi")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Raporlarda tüm tutarlar ana para birimine çevrilerek toplanır.")
                Text(exchangeRates.statusDescription)
                if let error = exchangeRates.lastErrorMessage {
                    Text(error).foregroundStyle(.orange)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Görünüm

    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { settings.appearance },
                set: { settings.appearance = $0 }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            } label: {
                SettingsRowLabel(
                    title: L10n.text("Tema"),
                    systemImage: "circle.lefthalf.filled",
                    tint: AppTheme.accent
                )
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Görünüm")
        }
    }

    // MARK: - Dil

    private var languageSection: some View {
        Section {
            Picker(selection: Binding(
                get: { settings.language },
                set: { settings.language = $0 }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            } label: {
                SettingsRowLabel(
                    title: L10n.text("Uygulama dili"),
                    systemImage: "globe",
                    tint: AppTheme.accent
                )
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Dil")
        } footer: {
            Text("Tarih ve sayı biçimleri seçtiğiniz dile göre güncellenir.")
        }
    }

    // MARK: - Hakkında

    private var aboutSection: some View {
        Section {
            SettingsValueRow(
                title: L10n.text("Sürüm"),
                systemImage: "info.circle",
                tint: .secondary,
                value: Self.versionString
            )
            SettingsValueRow(
                title: L10n.text("Veri saklama"),
                systemImage: "internaldrive",
                tint: .secondary,
                value: L10n.text("Cihazda")
            )
        } header: {
            Text("Hakkında")
        } footer: {
            Text("Kasa+ — günlük gelir/gider takibi.")
        }
    }

    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Taşmaya dayanıklı satır bileşenleri

/// İkon + başlık. Başlık tek satırda kalır, sığmazsa küçültülür —
/// böylece değer alanıyla çakışıp alt satıra taşmaz.
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
        }
    }
}

/// Sol tarafta ikon + başlık, sağda değer. Değer uzunsa kısaltılır.
struct SettingsValueRow: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            SettingsRowLabel(title: title, systemImage: systemImage, tint: tint)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 170, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Alt ekrana giden satır (değer + chevron).
struct SettingsDisclosureRow: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            SettingsRowLabel(title: title, systemImage: systemImage, tint: tint)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
