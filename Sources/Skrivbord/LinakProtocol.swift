import CoreBluetooth

/// GATT constants for the Linak DPG1C control box used by the IKEA Idasen desk
/// and many other rebranded Linak-based standing desks.
enum LinakBLE {
    static let serviceUUID = CBUUID(string: "99fa0001-338a-1024-8a49-009c0215f78a")
    static let commandCharacteristicUUID = CBUUID(string: "99fa0002-338a-1024-8a49-009c0215f78a")
    static let heightCharacteristicUUID = CBUUID(string: "99fa0021-338a-1024-8a49-009c0215f78a")

    static let commandUp: [UInt8] = [0x47, 0x00]
    static let commandDown: [UInt8] = [0x46, 0x00]
    static let commandStop: [UInt8] = [0xFF, 0x00]

    /// The notify characteristic reports a 2-byte little-endian raw value in
    /// tenths of a millimeter above the desk's 62.0cm mechanical base height.
    static func heightCM(fromRawBytes data: Data) -> Double? {
        guard data.count >= 2 else { return nil }
        let start = data.startIndex
        let raw = Int(data[start]) | (Int(data[start + 1]) << 8)
        return 62.0 + Double(raw) / 100.0
    }
}
