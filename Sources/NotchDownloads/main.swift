import AppKit

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Dock simgesi gösterme; yalnızca menü çubuğu + çentik paneli.
app.setActivationPolicy(.accessory)
app.run()
