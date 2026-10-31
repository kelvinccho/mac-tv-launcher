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
    private enum Editor: String, Identifiable {
        case settings, add
        var id: String { rawValue }
    }
    private enum Field: Hashable { case name, address(Int) }
    @StateObject private var voice = VoiceController()
    @State private var selected = 0
    @State private var editor: Editor?
    @State private var status = "Choose something to watch"
    @State private var monitor: Any?
    @State private var shortcut = VoiceShortcut()
    @State private var tiles: [Tile] = []
    @State private var storageError = ""
    @State private var drafts: [String] = []
    @State private var name = ""
    @State private var address = ""
    @State private var validation = ""
    @FocusState private var field: Field?
    private let store = TileStore()
    private let colors: [Color] = [.red, Color(red: 0.7, green: 0.06, blue: 0.12), .teal, .indigo]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.11, blue: 0.19), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TV Launcher").font(.system(size: 22, weight: .medium)).foregroundColor(.white.opacity(0.65))
                        Text("Your evening starts here.").font(.system(size: 36, weight: .bold))
                    }
                    Spacer()
                    Button { show(.add) } label: { Label("Add Tile", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command).disabled(!storageError.isEmpty)
                    Button { show(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                        .keyboardShortcut(",", modifiers: .command).disabled(!storageError.isEmpty)
                }
                if !storageError.isEmpty {
                    Text(storageError).foregroundColor(.orange).textSelection(.enabled)
                    Button("Retry loading saved tiles") { load() }
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                            ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                                tileButton(tile, index: index).id(tile.id)
                            }
                        }.padding(8)
                    }
                    .onChange(of: selected) { index in
                        if tiles.indices.contains(index) { proxy.scrollTo(tiles[index].id, anchor: .center) }
                    }
                    .onChange(of: tiles.count) { _ in
                        if tiles.indices.contains(selected) { proxy.scrollTo(tiles[selected].id, anchor: .center) }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(status).font(.system(size: 21, weight: .medium)).accessibilityAddTraits(.updatesFrequently)
                    Text("Arrows  Choose    Return  Open    1–3  Quick launch    ⌘N  Add Tile")
                        .font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                    HStack {
                        Button { toggleVoice() } label: {
                            Label(voice.listening ? "Stop listening · ⌘⇧Space" : "Voice control · ⌘⇧Space", systemImage: voice.listening ? "mic.fill" : "mic")
                        }.disabled(tiles.isEmpty)
                        Text(voice.message.isEmpty ? "Say “open” followed by a tile name" : voice.message)
                            .font(.system(size: 16)).foregroundColor(.white.opacity(0.75))
                    }
                    Text("After watching, press ⌘Tab to return to TV Launcher.").foregroundColor(.white.opacity(0.6))
                }
            }.padding(32).foregroundColor(.white)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editor) { item in editorView(item) }
        .onAppear { load(); installKeyboard() }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            cancelForFocusLoss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in cancelForFocusLoss() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in cancelForFocusLoss() }
    }

    private func tileButton(_ tile: Tile, index: Int) -> some View {
        Button { selected = index; open(tile) } label: {
            VStack(spacing: 14) {
                Image(systemName: tile.service == .youtube ? "play.rectangle.fill" : tile.service == .netflix ? "film.fill" : tile.service == .teevie ? "tv.fill" : "globe")
                    .font(.system(size: 40))
                Text(tile.name).font(.system(size: 26, weight: .bold)).lineLimit(2)
                Text(index == selected ? "Press Return to open" : index < 3 ? "\(index + 1)" : "Web tile")
                    .font(.system(size: 15)).opacity(0.8)
            }
            .padding(12).frame(maxWidth: .infinity).frame(height: 200)
            .background(colors[min(index, 3)].gradient, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: selected == index ? 5 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tile.name)
        .accessibilityValue(selected == index ? "Selected" : "")
    }

    private func editorView(_ item: Editor) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(item == .add ? "Add Tile" : "Service addresses").font(.largeTitle.bold())
            Text("Enter a full http:// or https:// address. TeeVee may be left empty.")
            if item == .add {
                TextField("Name", text: $name).focused($field, equals: .name)
                    .accessibilityLabel("Tile name")
                TextField("Web address", text: $address).focused($field, equals: .address(0))
                    .accessibilityLabel("Tile web address")
            } else {
                ForEach(Array(Service.allCases.enumerated()), id: \.element.id) { index, service in
                    TextField(service.title, text: $drafts[index]).focused($field, equals: .address(index))
                        .accessibilityLabel("\(service.title) address")
                }
            }
            Text(validation).foregroundColor(.orange).accessibilityAddTraits(.updatesFrequently)
            HStack {
                Button("Cancel") { editor = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save(item) }.keyboardShortcut(.defaultAction)
            }
        }
        .textFieldStyle(.roundedBorder).padding(32).frame(width: 600)
        .onAppear { field = item == .add ? .name : .address(0) }
    }

    private func load() {
        do {
            tiles = try store.load()
            selected = min(selected, tiles.count - 1)
            storageError = ""
        } catch { storageError = error.localizedDescription }
    }

    private func show(_ item: Editor) {
        guard storageError.isEmpty else { return }
        voice.cancel(message: "")
        drafts = Array(tiles.prefix(3).map(\.address))
        name = ""
        address = ""
        validation = ""
        editor = item
    }

    private func save(_ item: Editor) {
        do {
            if item == .add {
                tiles = try store.adding(name: name, address: address, to: tiles)
                selected = tiles.count - 1
                status = "Added \(tiles[selected].name)"
            } else {
                var updated = tiles
                for index in drafts.indices { updated[index].address = drafts[index].trimmingCharacters(in: .whitespacesAndNewlines) }
                try store.save(updated)
                tiles = updated
                status = "Service addresses saved"
            }
            editor = nil
        } catch { validation = error.localizedDescription }
    }

    private func open(_ tile: Tile) {
        voice.cancel(message: "")
        guard let index = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        selected = index
        guard let url = LauncherLogic.webURL(tile.address) else {
            status = "Set the \(tile.name) address in Settings first"
            show(.settings)
            return
        }
        status = NSWorkspace.shared.open(url) ? "Opened \(tile.name) · ⌘Tab returns here" : "Could not open \(tile.name). Check your default browser."
    }

    private func toggleVoice() {
        guard editor == nil, !tiles.isEmpty else { return }
        voice.toggle(names: tiles.map(\.name)) { transcript in
            guard editor == nil, NSApp.isActive else { return }
            if let tile = LauncherLogic.tile(for: transcript, in: tiles) { open(tile) }
            else { status = "Command not recognized. Say one exact tile name, or use the arrow keys." }
        }
    }

    private func cancelForFocusLoss() {
        shortcut.reset()
        voice.cancel()
    }

    private func installKeyboard() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            let flags = event.modifierFlags
            let inputActive = editor != nil || NSApp.keyWindow?.isSheet == true
            if shortcut.handle(keyCode: event.keyCode, keyDown: event.type == .keyDown, isRepeat: event.isARepeat,
                               command: flags.contains(.command), shift: flags.contains(.shift),
                               control: flags.contains(.control), option: flags.contains(.option), inputActive: inputActive) {
                toggleVoice()
                return nil
            }
            guard event.type == .keyDown, !inputActive else { return event }
            // Consume repeated voice chords too, so Space cannot activate a focused button.
            if event.keyCode == 49 && flags.contains([.command, .shift]) && flags.intersection([.control, .option]).isEmpty { return nil }
            guard flags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 123, 126: selected = LauncherLogic.moved(selected, by: -1, count: tiles.count)
            case 124, 125: selected = LauncherLogic.moved(selected, by: 1, count: tiles.count)
            case 36, 76: if !event.isARepeat, tiles.indices.contains(selected) { open(tiles[selected]) }
            case 53:
                if voice.listening { voice.cancel() }
                else if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true { NSApp.keyWindow?.toggleFullScreen(nil) }
            default:
                if !event.isARepeat, let key = event.characters, let number = Int(key), (1...3).contains(number), tiles.indices.contains(number - 1) { open(tiles[number - 1]) }
                else { return event }
            }
            return nil
        }
    }
}
