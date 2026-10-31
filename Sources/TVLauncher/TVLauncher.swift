import SwiftUI
import AppKit
import LauncherCore

@main
struct TVLauncherApp: App {
    var body: some Scene {
        WindowGroup("TV Launcher") {
            LauncherView().frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

struct LauncherView: View {
    @StateObject private var voice = VoiceController()
    @State private var selected = 0
    @State private var settings = false
    @State private var status = "Choose something to watch"
    @State private var monitor: Any?
    @State private var addresses = Service.allCases.map {
        UserDefaults.standard.string(forKey: "service.\($0.rawValue)") ?? $0.defaultAddress
    }
    @State private var drafts: [String] = []
    @State private var validation = ""
    private let colors: [Color] = [.red, Color(red: 0.7, green: 0.06, blue: 0.12), .teal]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.11, blue: 0.19), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 32) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TV Launcher").font(.system(size: 22, weight: .medium)).foregroundColor(.white.opacity(0.65))
                        Text("Your evening starts here.").font(.system(size: 42, weight: .bold))
                    }
                    Spacer()
                    Button { showSettings() } label: { Label("Settings", systemImage: "gearshape") }
                        .keyboardShortcut(",", modifiers: .command)
                }
                HStack(spacing: 24) {
                    ForEach(Array(Service.allCases.enumerated()), id: \.element.id) { index, service in
                        Button { selected = index; open(service) } label: {
                            VStack(spacing: 18) {
                                Image(systemName: index == 0 ? "play.rectangle.fill" : index == 1 ? "film.fill" : "tv.fill")
                                    .font(.system(size: 48))
                                Text(service.title).font(.system(size: 30, weight: .bold))
                                Text(index == selected ? "Press Return to open" : "\(index + 1)")
                                    .font(.system(size: 15)).opacity(0.8)
                            }
                            .frame(maxWidth: .infinity).frame(height: 230)
                            .background(colors[index].gradient, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: selected == index ? 5 : 0))
                            .scaleEffect(selected == index ? 1.025 : 0.96)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(service.title)
                        .accessibilityValue(selected == index ? "Selected" : "")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(status).font(.system(size: 23, weight: .medium)).accessibilityAddTraits(.updatesFrequently)
                    Text("← →  Choose    Return  Open    1–3  Quick launch    ⌃⌘F  Full screen")
                        .font(.system(size: 17)).foregroundColor(.white.opacity(0.7))
                    HStack {
                        Button { toggleVoice() } label: {
                            Label(voice.listening ? "Stop listening · ⌘⇧Space" : "Voice control · ⌘⇧Space", systemImage: voice.listening ? "mic.fill" : "mic")
                        }
                        Text(voice.message.isEmpty ? "Say “open YouTube”, “Netflix” or “TeeVee”" : voice.message)
                            .font(.system(size: 16)).foregroundColor(.white.opacity(0.75))
                    }
                    Text("After watching, press ⌘Tab to return to TV Launcher.").foregroundColor(.white.opacity(0.6))
                }
            }.padding(48).foregroundColor(.white)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $settings) { settingsView }
        .onAppear { installKeyboard() }
        .onDisappear { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; voice.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if voice.listening { voice.cancel() }
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Service addresses").font(.largeTitle.bold())
            Text("Enter a full http:// or https:// address. Set TeeVee to the service you use.")
            ForEach(Array(Service.allCases.enumerated()), id: \.element.id) { index, service in
                TextField(service.title, text: $drafts[index]).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(service.title) address")
            }
            Text(validation).foregroundColor(.orange)
            HStack {
                Button("Cancel") { settings = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveSettings() }.keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 600)
    }

    private func showSettings() {
        voice.cancel(message: "")
        drafts = addresses
        validation = ""
        settings = true
    }

    private func saveSettings() {
        for (index, address) in drafts.enumerated() {
            if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && index == 2 { continue }
            guard LauncherLogic.webURL(address) != nil else {
                validation = "Enter a valid web address for \(Service.allCases[index].title)."
                return
            }
        }
        addresses = drafts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for (index, service) in Service.allCases.enumerated() {
            UserDefaults.standard.set(addresses[index], forKey: "service.\(service.rawValue)")
        }
        settings = false
        status = "Service addresses saved"
    }

    private func open(_ service: Service) {
        voice.cancel(message: "")
        selected = Service.allCases.firstIndex(of: service)!
        guard let url = LauncherLogic.webURL(addresses[selected]) else {
            status = "Set the \(service.title) address in Settings first"
            showSettings()
            return
        }
        status = NSWorkspace.shared.open(url) ? "Opened \(service.title) · ⌘Tab returns here" : "Could not open \(service.title). Check your default browser."
    }

    private func toggleVoice() {
        voice.toggle { transcript in
            if let service = LauncherLogic.service(for: transcript) { open(service) }
            else { status = "Command not recognized. Say one service name, or use the arrow keys." }
        }
    }

    private func installKeyboard() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !settings, NSApp.keyWindow?.isSheet != true else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 49 && flags == [.command, .shift] { toggleVoice(); return nil }
            guard flags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 123, 126: selected = LauncherLogic.moved(selected, by: -1, count: 3)
            case 124, 125: selected = LauncherLogic.moved(selected, by: 1, count: 3)
            case 36, 76: open(Service.allCases[selected])
            case 53: if voice.listening { voice.cancel() } else if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true { NSApp.keyWindow?.toggleFullScreen(nil) }
            default:
                if let key = event.characters, let number = Int(key), (1...3).contains(number) { open(Service.allCases[number - 1]) }
                else { return event }
            }
            return nil
        }
    }
}
