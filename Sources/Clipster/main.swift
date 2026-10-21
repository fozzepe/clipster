import AppKit

let app = NSApplication.shared

// Скриншоты для README: ./build.sh, затем build/Clipster.app/Contents/MacOS/Clipster --screenshots docs
if let flag = CommandLine.arguments.firstIndex(of: "--screenshots") {
    let path = CommandLine.arguments.indices.contains(flag + 1) ? CommandLine.arguments[flag + 1] : "docs"
    Screenshots.run(to: URL(fileURLWithPath: path))
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
