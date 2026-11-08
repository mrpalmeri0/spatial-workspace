import Foundation

/// Italian source keys with English fallback; Bundle respects the per-app system language.
func L(_ key: String) -> String {
    let preference = UserDefaults.standard.string(forKey: "spatial.language") ?? "system"
    let bundle: Bundle
    if ["en", "it"].contains(preference),
       let path = Bundle.main.path(forResource: preference, ofType: "lproj"),
       let localized = Bundle(path: path) {
        bundle = localized
    } else { bundle = .main }
    return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
