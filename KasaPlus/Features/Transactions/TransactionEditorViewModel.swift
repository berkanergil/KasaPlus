import Foundation
import Observation

/// İşlem ekleme / düzenleme ekranının durumu.
@MainActor
@Observable
final class TransactionEditorViewModel {

    var draft: TransactionDraft
    var errorMessage: String?

    let isEditing: Bool

    @ObservationIgnored private let session: AppSession

    init(session: AppSession, mode: TransactionEditorView.Mode, defaultCurrency: Currency) {
        self.session = session
        switch mode {
        case .create(let type):
            var draft = TransactionDraft.empty(type: type, currency: defaultCurrency)
            draft.categoryID = session.categories(for: type).first?.id
            self.draft = draft
            self.isEditing = false
        case .edit(let transaction):
            self.draft = TransactionDraft(transaction: transaction)
            self.isEditing = true
        }
    }

    var title: String {
        isEditing ? L10n.text("İşlemi Düzenle") : (draft.type == .income ? L10n.text("Gelir Ekle") : L10n.text("Gider Ekle"))
    }

    var availableCategories: [Category] {
        session.categories(for: draft.type)
    }

    var availableBanks: [Bank] { session.banks }

    /// Ödeme yöntemi değiştiğinde banka alanını tutarlı tut.
    func paymentMethodDidChange() {
        if draft.paymentMethod.requiresBank {
            if draft.bankID == nil || !availableBanks.contains(where: { $0.id == draft.bankID }) {
                draft.bankID = availableBanks.first?.id
            }
        } else {
            draft.bankID = nil
        }
    }

    var canSave: Bool { draft.isValid }

    /// Tür değiştiğinde kategori de o türe ait ilk kategoriye taşınır.
    func typeDidChange() {
        let categories = availableCategories
        if let current = draft.categoryID, categories.contains(where: { $0.id == current }) { return }
        draft.categoryID = categories.first?.id
    }

    /// Kategori listesi boşsa kullanıcıyı yönlendirmek için.
    var hasNoCategories: Bool { availableCategories.isEmpty }

    @discardableResult
    func save() -> Bool {
        guard draft.isValid else {
            errorMessage = L10n.text("Lütfen tutar girin ve bir kategori seçin.")
            return false
        }
        let success = session.saveTransaction(draft)
        if !success {
            errorMessage = session.lastErrorMessage ?? L10n.text("Kayıt kaydedilemedi.")
        }
        return success
    }

    /// Sık kullanılan tutarları tek dokunuşla girmek için hızlı seçenekler.
    var quickAmounts: [Double] { [50, 100, 250, 500, 1000] }

    func applyQuickAmount(_ value: Double) {
        draft.amount += value
    }

    func clearAmount() {
        draft.amount = 0
    }
}
