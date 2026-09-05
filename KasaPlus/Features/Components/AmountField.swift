import SwiftUI

/// Tutar girişi için ortak alan.
///
/// `TextField(value:format:)` yerine metin tabanlı çalışır; böylece:
/// * Alan boşken (tutar 0) "0" görünmez, yalnızca ipucu metni durur —
///   yani 0 varken 8'e basınca "08" değil "8" yazılır.
/// * Elle yazılan baştaki sıfırlar temizlenir ("007" → "7"), ama "0,5" korunur.
/// * Ondalık ayırıcı olarak hem "," hem "." kabul edilir, seçili dilin
///   ayırıcısına çevrilir ve en fazla 2 ondalık haneye izin verilir.
/// * Tutar dışarıdan değişirse (hızlı tutar butonları, sıfırla, kayıt düzenleme)
///   alan kendini günceller.
struct AmountField: View {

    @Binding var amount: Double
    var tint: Color = .primary
    var fontSize: CGFloat = 34
    /// Dışarıdaki bir `@FocusState`'e bağlanmak için (ör. klavye araç çubuğu).
    var focus: FocusState<Bool>.Binding? = nil

    @State private var text: String = ""

    private var separator: String { Formatters.locale.decimalSeparator ?? "," }

    var body: some View {
        Group {
            if let focus {
                field.focused(focus)
            } else {
                field
            }
        }
        .onAppear { text = Self.display(amount, separator: separator) }
        .onChange(of: text) { _, newValue in
            let cleaned = Self.sanitize(newValue, separator: separator)
            if cleaned != newValue { text = cleaned }
            let parsed = Self.value(of: cleaned, separator: separator)
            if parsed != amount { amount = parsed }
        }
        .onChange(of: amount) { _, newValue in
            // Yalnızca değişiklik dışarıdan geldiyse metni yeniden kur;
            // böylece kullanıcı "8," yazarken alan "8"e dönmez.
            if Self.value(of: text, separator: separator) != newValue {
                text = Self.display(newValue, separator: separator)
            }
        }
    }

    private var field: some View {
        TextField("0\(separator)00", text: $text)
            .keyboardType(.decimalPad)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .accessibilityLabel("Tutar")
    }

    // MARK: - Metin ↔ sayı

    /// Girilen metni yalnızca rakam + tek ondalık ayırıcı içerecek şekilde temizler.
    static func sanitize(_ raw: String, separator: String) -> String {
        let separatorCharacter = separator.first ?? ","
        var result = ""
        var hasSeparator = false
        var fractionDigits = 0

        for character in raw {
            if character.isASCII, character.isNumber {
                if hasSeparator {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                result.append(character)
            } else if character == "," || character == "." {
                guard !hasSeparator else { continue }
                hasSeparator = true
                if result.isEmpty { result.append("0") }
                result.append(separatorCharacter)
            }
        }

        // "08" → "8". Tek başına "0" ve "0,5" olduğu gibi kalır.
        while result.count > 1,
              result.hasPrefix("0"),
              let second = result.dropFirst().first,
              second.isNumber {
            result.removeFirst()
        }

        return result
    }

    static func value(of text: String, separator: String) -> Double {
        var normalized = text.replacingOccurrences(of: separator, with: ".")
        if normalized.hasSuffix(".") { normalized.removeLast() }
        guard !normalized.isEmpty else { return 0 }
        return Double(normalized) ?? 0
    }

    /// 0 için boş metin döndürür; ipucu metni ("0,00") görünür kalsın diye.
    static func display(_ value: Double, separator: String) -> String {
        guard value != 0 else { return "" }
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded(), abs(rounded) < 1e15 {
            return String(Int64(rounded))
        }
        return String(format: "%.2f", rounded)
            .replacingOccurrences(of: ".", with: separator)
    }
}
