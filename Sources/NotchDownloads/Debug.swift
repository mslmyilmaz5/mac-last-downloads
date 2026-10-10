import Foundation

/// ND_DEBUG=1 ile çalıştırıldığında stderr'e debug logu basar.
func dlog(_ message: @autoclosure () -> String) {
    guard ProcessInfo.processInfo.environment["ND_DEBUG"] != nil else { return }
    FileHandle.standardError.write(Data(("[nd] \(message())\n").utf8))
}
