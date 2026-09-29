import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let statusPath = NSHomeDirectory() + "/Library/Application Support/XiaomeiSignal/status.json"
    static let ackPath = NSHomeDirectory() + "/Library/Application Support/XiaomeiSignal/user-ack.json"

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var panel: NSPanel!
    var light: PixelTrafficLightView!
    var timer: Timer?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPanel()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        panel.orderFrontRegardless()
    }

    func setupMenuBar() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "回到当前任务", action: #selector(returnToCurrentTask), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "复制状态", action: #selector(copyStatus), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "我已知晓", action: #selector(ackYellow), keyEquivalent: "y"))
        menu.addItem(NSMenuItem(title: "需支援", action: #selector(needHelp), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for m in menu.items { m.target = self }
        item.menu = menu
        item.button?.imagePosition = .imageOnly
    }

    func setupPanel() {
        let scale: CGFloat = 4
        let w = 30 * scale
        let h = 42 * scale
        panel = NSPanel(
            contentRect: NSRect(x: 28, y: 480, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        light = PixelTrafficLightView(frame: NSRect(x: 0, y: 0, width: w, height: h), scale: scale)
        light.onLeft = { [weak self] key in self?.handleLeft(key) }
        light.onRight = { [weak self] in self?.item.button?.performClick(nil) }
        panel.contentView = light
    }

    func refresh() {
        let s = loadStatus()
        light.state = s.state
        light.needsDisplay = true
        item.button?.image = makeBarImage(active: s.state)
        let tip = [s.label, s.detail, s.updatedAt].filter { !$0.isEmpty }.joined(separator: "\n")
        item.button?.toolTip = tip
        light.toolTip = tip
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func makeBarImage(active: String) -> NSImage {
        let s: CGFloat = 2
        let img = NSImage(size: NSSize(width: 8 * s, height: 16 * s))
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        func p(_ x: Int, _ y: Int, _ c: NSColor) {
            c.setFill()
            NSBezierPath(rect: NSRect(x: CGFloat(x)*s, y: CGFloat(y)*s, width: s, height: s)).fill()
        }
        for y in 0..<16 {
            p(0, y, .black); p(7, y, .black)
            for x in 1..<7 { p(x, y, NSColor(calibratedWhite: 0.14, alpha: 1)) }
        }
        let rows = [(12, "red"), (7, "yellow"), (2, "green")]
        for (cy, key) in rows {
            let on = key == active
            let c: NSColor = {
                if key == "red" { return on ? NSColor(calibratedRed: 1, green: 0.3, blue: 0.35, alpha: 1) : NSColor(calibratedRed: 0.45, green: 0.16, blue: 0.18, alpha: 1) }
                if key == "yellow" { return on ? NSColor(calibratedRed: 1, green: 0.85, blue: 0.15, alpha: 1) : NSColor(calibratedRed: 0.45, green: 0.34, blue: 0.10, alpha: 1) }
                return on ? NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.45, alpha: 1) : NSColor(calibratedRed: 0.14, green: 0.38, blue: 0.20, alpha: 1)
            }()
            for dy in 0..<3 { for dx in 0..<4 { p(2+dx, cy+dy, c) } }
        }
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    struct SignalStatus {
        var state = "green"
        var label = "推进中"
        var detail = ""
        var updatedAt = ""
    }

    func loadStatus() -> SignalStatus {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.statusPath)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SignalStatus(state: "red", label: "卡住", detail: "读不到状态")
        }
        var st = (obj["state"] as? String ?? "green").lowercased()
        if st == "g" { st = "green" }
        if st == "y" || st == "wait" { st = "yellow" }
        if st == "r" || st == "block" { st = "red" }
        if !["green", "yellow", "red"].contains(st) { st = "green" }
        let defaults = ["green": "推进中", "yellow": "等你", "red": "卡住"]
        let label = obj["label"] as? String
        return SignalStatus(
            state: st,
            label: (label?.isEmpty == false ? label! : defaults[st]!),
            detail: obj["detail"] as? String ?? "",
            updatedAt: obj["updatedAt"] as? String ?? ""
        )
    }

    func writeAck(kind: String, note: String) {
        let payload = ["kind": kind, "note": note, "at": ISO8601DateFormatter().string(from: Date())]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: Self.ackPath))
        }
    }

    func handleLeft(_ key: String) {
        // Brief left-click (not drag) → jump back to current task
        returnToCurrentTask()
    }

    @objc func returnToCurrentTask() {
        let s = loadStatus()
        let taskFile = NSHomeDirectory() + "/Library/Application Support/XiaomeiSignal/current-task.md"
        let detailText = s.detail.isEmpty ? "（暂无详情）" : s.detail
        let body = "# 当前任务\n\n- 状态：**" + s.label + "**\n- 更新：" + s.updatedAt + "\n\n## 内容\n\n" + detailText + "\n\n---\n来自小梅信号灯点击。\n"
        try? body.write(toFile: taskFile, atomically: true, encoding: .utf8)

        // Only bring Grok Bot forward — never open .md (would launch Xcode)
        let openBot = Process()
        openBot.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openBot.arguments = ["-a", "Grok Bot"]
        try? openBot.run()

        writeAck(kind: "return_to_task", note: s.detail)

        let safeDetail = detailText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let safeLabel = s.label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"" + safeDetail + "\" with title \"小梅 · " + safeLabel + "\" subtitle \"已回到当前任务\""
        let note = Process()
        note.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        note.arguments = ["-e", script]
        try? note.run()
    }

    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }
    @objc func copyStatus() {
        let s = loadStatus()
        copy("[\(s.label)] \(s.detail) (\(s.updatedAt))")
    }
    @objc func ackYellow() { writeAck(kind: "ack_yellow", note: "user acknowledged") }
    @objc func needHelp() { writeAck(kind: "need_help", note: "user needs support") }
    @objc func quit() { NSApp.terminate(nil) }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

final class PixelTrafficLightView: NSView {
    var state = "green" {
        didSet {
            if oldValue != state { startBlink() }
        }
    }
    var onLeft: ((String) -> Void)?
    var onRight: (() -> Void)?
    let scale: CGFloat
    private var blinkOn = true
    private var blinkTimer: Timer?
    private var blinkPhase = 0 // 0=lit dwell, 1=off pulse

    init(frame: NSRect, scale: CGFloat) {
        self.scale = scale
        super.init(frame: frame)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startBlink() }
    }

    private func startBlink() {
        blinkTimer?.invalidate()
        blinkPhase = 0
        blinkOn = true
        needsDisplay = true
        scheduleBlinkTick(after: 4.8) // longer dwell between blinks
    }

    private func scheduleBlinkTick(after: TimeInterval) {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: after, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.blinkPhase == 0 {
                // brief off pulse
                self.blinkOn = false
                self.blinkPhase = 1
                self.needsDisplay = true
                self.scheduleBlinkTick(after: 0.28)
            } else {
                // back on, longer dwell
                self.blinkOn = true
                self.blinkPhase = 0
                self.needsDisplay = true
                self.scheduleBlinkTick(after: 4.8)
            }
        }
        if let blinkTimer { RunLoop.main.add(blinkTimer, forMode: .common) }
    }

    private let circle7: [[Int]] = [
        [0,0,1,1,1,0,0],
        [0,1,1,1,1,1,0],
        [1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1],
        [0,1,1,1,1,1,0],
        [0,0,1,1,1,0,0],
    ]

    private func px(_ x: Int, _ y: Int, _ c: NSColor) {
        guard x >= 0, y >= 0, x < 30, y < 42 else { return }
        c.setFill()
        NSBezierPath(rect: NSRect(x: CGFloat(x)*scale, y: CGFloat(y)*scale, width: scale, height: scale)).fill()
    }

    private func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
        for yy in y..<(y+h) { for xx in x..<(x+w) { px(xx, yy, c) } }
    }

    private func fillRoundBody(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
        // Fill solid first so no transparent holes, then only outer outline is rounded.
        fill(x, y, w, h, c)
    }

    private func strokeRoundOutline(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: NSColor) {
        for yy in (y+2)..<(y+h-2) { px(x, yy, c); px(x+w-1, yy, c) }
        for xx in (x+2)..<(x+w-2) { px(xx, y, c); px(xx, y+h-1, c) }
        let corners = [
            (x+1,y+1),(x+2,y),(x,y+2),
            (x+w-2,y+1),(x+w-3,y),(x+w-1,y+2),
            (x+1,y+h-2),(x+2,y+h-1),(x,y+h-3),
            (x+w-2,y+h-2),(x+w-3,y+h-1),(x+w-1,y+h-3),
        ]
        for (cx, cy) in corners { px(cx, cy, c) }
    }

    /// Local time → ground shadow + specular (light opposite of shadow).
    /// Morning: shadow left; noon: short under; afternoon: shadow right (~40°); night: faint short.
    private func shadowParams() -> (dx: Double, dy: Double, steps: Int, alpha: Double) {
        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let t = Double(h) + Double(m) / 60.0

        // Stronger, clearer day arc so direction change is obvious
        if t < 5.5 || t >= 20.0 {
            return (0.85, 0.4, 5, 0.10)
        }
        if t < 7 {
            return (-1.35, 0.85, 7, 0.14)
        }
        if t < 11 {
            let k = (t - 7) / 4.0
            let dx = -1.35 + k * 1.15
            let dy = 0.9 - k * 0.25
            let steps = 8 - Int(k * 2)
            return (dx, dy, max(5, steps), 0.15 - k * 0.03)
        }
        if t < 13 {
            return (0.15, 0.55, 5, 0.10)
        }
        if t < 17 {
            let k = (t - 13) / 4.0
            let dx = 0.55 + k * 0.85
            let dy = 0.55 + k * 0.35
            let steps = 5 + Int(k * 3)
            return (dx, dy, min(9, steps), 0.12 + k * 0.04)
        }
        let k = (t - 17) / 3.0
        return (1.3 - k * 0.25, 0.85 - k * 0.2, 7, 0.14 - k * 0.04)
    }

    /// Specular sits toward the light source (opposite of ground-shadow dx).
    private func specularOffset() -> (ox: Int, oy: Int) {
        let p = shadowParams()
        let ox: Int
        if p.dx > 0.35 { ox = -1 }       // afternoon: light from left
        else if p.dx < -0.35 { ox = 1 }  // morning: light from right
        else { ox = 0 }                  // noon: top-center
        let oy = p.dy > 0.75 ? 2 : 1     // low sun → highlight higher on sphere
        return (ox, oy)
    }

    private func drawTimeShadow(originX: Int, originY: Int) {
        let p = shadowParams()
        let steps = p.steps
        for i in 0..<steps {
            let fade = 1.0 - Double(i) / Double(max(1, steps))
            let a = p.alpha * (0.35 + 0.65 * fade)
            let x = originX + Int((p.dx * Double(i)).rounded())
            let y = originY + Int((p.dy * Double(i)).rounded())
            // Soft / blurry: wider kernel, multiple translucent layers
            let core = max(2, 3 - i / 3)
            let soft = core + 2
            let cSoft = NSColor.black.withAlphaComponent(CGFloat(a * 0.28))
            let cMid = NSColor.black.withAlphaComponent(CGFloat(a * 0.45))
            let cCore = NSColor.black.withAlphaComponent(CGFloat(a * 0.7))
            fill(x - soft, y, soft * 2 + 1, 1, cSoft)
            fill(x - soft + 1, y - 1, max(1, soft * 2 - 1), 1, cSoft)
            fill(x - soft + 1, y + 1, max(1, soft * 2 - 1), 1, cSoft)
            fill(x - core - 1, y, (core + 1) * 2 + 1, 1, cMid)
            fill(x - core, y, core * 2 + 1, 1, cCore)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        // Clear so time-of-day shadow/highlight never leave ghosts
        NSColor.clear.setFill()
        dirtyRect.fill()

        let ink = NSColor.black
        let body = NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.22, alpha: 1)
        let bodyHi = NSColor(calibratedRed: 0.48, green: 0.50, blue: 0.55, alpha: 1)
        let bodyLo = NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        let slot = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        let sp = shadowParams()
        // Lit edge faces the sun (opposite of shadow)
        let litLeft = sp.dx >= 0
        let edgeLit = litLeft ? bodyHi : bodyLo
        let edgeShade = litLeft ? bodyLo : bodyHi

        // Center housing in canvas so left/right shadows both fit
        let hx = 9, hy = 10, hw = 11, hh = 26
        let cx = hx + hw / 2

        // Ground shadow; direction follows local clock
        drawTimeShadow(originX: cx + 1, originY: 3)

        // Base
        fill(cx - 5, 3, 11, 1, ink)
        fill(cx - 4, 4, 9, 1, bodyLo)
        fill(cx - 4, 4, 1, 1, NSColor(calibratedWhite: 0.62, alpha: 1))
        fill(cx - 3, 5, 7, 1, ink)

        // Pole
        fill(cx - 1, 6, 3, 4, bodyLo)
        fill(cx - 1, 6, 1, 4, edgeLit)
        fill(cx + 1, 6, 1, 4, edgeShade)
        fill(cx - 2, 9, 5, 1, ink)

        fill(hx + 2, hy - 1, hw - 3, 1, NSColor.black.withAlphaComponent(0.14))

        strokeRoundOutline(hx, hy, hw, hh, ink)
        fillRoundBody(hx + 1, hy + 1, hw - 2, hh - 2, body)
        for yy in (hy + 3)..<(hy + hh - 3) {
            px(hx + 1, yy, edgeLit)
            px(hx + hw - 2, yy, edgeShade)
        }

        fill(hx + 2, hy + 9, hw - 4, 1, ink)
        fill(hx + 2, hy + 17, hw - 4, 1, ink)

        drawLamp(cx: cx, cy: hy + 21, key: "red", slot: slot)
        drawLamp(cx: cx, cy: hy + 13, key: "yellow", slot: slot)
        drawLamp(cx: cx, cy: hy + 5, key: "green", slot: slot)
    }

    private func drawLamp(cx: Int, cy: Int, key: String, slot: NSColor) {
        let on = (key == state) && blinkOn
        fill(cx - 3, cy + 4, 7, 1, NSColor(calibratedWhite: 0.06, alpha: 1))
        fill(cx - 3, cy - 3, 7, 7, slot)
        let off: NSColor
        let onC: NSColor
        let hi: NSColor
        switch key {
        case "red":
            off = NSColor(calibratedRed: 0.48, green: 0.16, blue: 0.18, alpha: 1)
            onC = NSColor(calibratedRed: 1.00, green: 0.30, blue: 0.34, alpha: 1)
            hi = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.74, alpha: 1)
        case "yellow":
            off = NSColor(calibratedRed: 0.48, green: 0.36, blue: 0.10, alpha: 1)
            onC = NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.16, alpha: 1)
            hi = NSColor(calibratedRed: 1.00, green: 0.95, blue: 0.55, alpha: 1)
        default:
            off = NSColor(calibratedRed: 0.14, green: 0.40, blue: 0.22, alpha: 1)
            onC = NSColor(calibratedRed: 0.34, green: 0.96, blue: 0.48, alpha: 1)
            hi = NSColor(calibratedRed: 0.72, green: 1.00, blue: 0.80, alpha: 1)
        }
        let base = on ? onC : off
        for row in 0..<7 {
            for col in 0..<7 where circle7[row][col] == 1 {
                px(cx - 3 + col, cy - 3 + row, base)
            }
        }
        if on {
            // white specular follows sun (opposite of ground shadow)
            let off = specularOffset()
            let sx = cx + off.ox
            let sy = cy + off.oy
            let white = NSColor.white
            px(sx, sy, white)
            px(sx + (off.ox == 0 ? 1 : 0), sy, white.withAlphaComponent(0.85))
            if off.oy >= 1 {
                px(sx, sy + 1, white.withAlphaComponent(0.55))
            }
            // soft colored rim sparkle on the lit side
            let rimX = cx + (off.ox == 0 ? 1 : off.ox)
            px(rimX, sy, hi.withAlphaComponent(0.65))
        }
    }

    private var mouseDownScreen: NSPoint?
    private var mouseDownTime: TimeInterval = 0
    private let clickMoveThreshold: CGFloat = 5
    private let clickMaxDuration: TimeInterval = 0.45

    private func key(at point: NSPoint) -> String? {
        let lx = Int(point.x / scale)
        let ly = Int(point.y / scale)
        let hx = 9, hy = 10, hw = 11
        let cx = hx + hw / 2
        let centers = [(hy + 21, "red"), (hy + 13, "yellow"), (hy + 5, "green")]
        for (cy, key) in centers {
            if abs(lx - cx) <= 4 && abs(ly - cy) <= 4 { return key }
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        // Record press only — do not return-to-task yet (drag must not trigger it)
        mouseDownScreen = NSEvent.mouseLocation
        mouseDownTime = ProcessInfo.processInfo.systemUptime
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownScreen = nil
            mouseDownTime = 0
        }
        guard let start = mouseDownScreen else { return }
        let end = NSEvent.mouseLocation
        let dist = hypot(end.x - start.x, end.y - start.y)
        let dt = ProcessInfo.processInfo.systemUptime - mouseDownTime
        // Brief click only: small movement + short press
        guard dist < clickMoveThreshold, dt <= clickMaxDuration else { return }
        let p = convert(event.locationInWindow, from: nil)
        onLeft?(key(at: p) ?? "green")
    }

    override func rightMouseDown(with event: NSEvent) { onRight?() }
}
