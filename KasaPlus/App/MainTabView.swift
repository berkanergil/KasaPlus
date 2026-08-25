import SwiftUI

struct MainTabView: View {

    @Environment(AppSession.self) private var session
    @Environment(NotificationRouter.self) private var router

    @State private var selectedTab: Tab = .dashboard
    @State private var quickAddType: TransactionType?

    enum Tab: Hashable {
        case dashboard, transactions, planned, reports, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                onQuickAdd: { quickAddType = $0 },
                onShowPlannedPayments: { selectedTab = .planned }
            )
            .tabItem { Label("Özet", systemImage: "square.grid.2x2.fill") }
            .tag(Tab.dashboard)

            TransactionListView()
                .tabItem { Label("İşlemler", systemImage: "list.bullet.rectangle.fill") }
                .tag(Tab.transactions)

            PlannedPaymentListView(
                postponeRequestID: router.postponeRequestID,
                onPostponeHandled: { router.clearPostponeRequest() }
            )
            .tabItem { Label("Planlı", systemImage: "calendar.badge.clock") }
            .tag(Tab.planned)
            .badge(overdueBadge)

            ReportsView()
                .tabItem { Label("Raporlar", systemImage: "chart.pie.fill") }
                .tag(Tab.reports)

            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .sheet(item: $quickAddType) { type in
            TransactionEditorView(mode: .create(type: type))
        }
        // Bildirimden gelen yönlendirme
        .onChange(of: router.shouldOpenPlannedPayments) { _, shouldOpen in
            guard shouldOpen else { return }
            selectedTab = .planned
            router.shouldOpenPlannedPayments = false
        }
        .task {
            if router.shouldOpenPlannedPayments {
                selectedTab = .planned
                router.shouldOpenPlannedPayments = false
            }
        }
        // Arka planda "Ödedim" ile işlenen bildirimin sonucu
        .alert(
            "Kasa+",
            isPresented: Binding(
                get: { router.lastActionMessage != nil },
                set: { if !$0 { router.clearMessage() } }
            )
        ) {
            Button("Tamam") { router.clearMessage() }
        } message: {
            Text(router.lastActionMessage ?? "")
        }
    }

    /// Gecikmiş ödeme sayısı sekme rozetinde gösterilir.
    private var overdueBadge: Int {
        session.upcomingPlannedPayments(within: 0).count
    }
}
