import Foundation

// Los DECIMAL de MySQL llegan como string desde la API (mysql2 sin
// decimalNumbers) y Gson en Android los convierte solo. Estos helpers
// replican esa tolerancia: aceptan número o string en cualquier campo.
extension KeyedDecodingContainer {

    func flexDouble(_ key: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s) }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        return nil
    }

    func flexFloat(_ key: Key) -> Float? {
        flexDouble(key).map { Float($0) }
    }

    func flexInt(_ key: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) ?? Double(s).map { Int($0) } }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    func flexString(_ key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return "\(i)" }
        if let d = try? decodeIfPresent(Double.self, forKey: key) {
            // Sin decimales innecesarios (4.5 no "4.500000")
            return d == d.rounded() && abs(d) < 1e15 ? "\(Int(d))" : "\(d)"
        }
        return nil
    }
}
