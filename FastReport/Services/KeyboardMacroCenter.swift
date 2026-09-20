import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import Observation

enum MacroPhase: Equatable {
    case idle
    case recording
    case playing
}

enum MacroPadDragPhase: Equatable {
    case began
    case changed
    case ended
}

enum MacroCapture: Equatable {
    case none
    case key
    case click
}

@MainActor
@Observable
final class KeyboardMacroCenter {
    static let offsetXKey = "fastreport.macro.offset.x"
    static let offsetYKey = "fastreport.macro.offset.y"
    static let originXKey = "fastreport.macro.origin.x"
    static let originYKey = "fastreport.macro.origin.y"
    static let delayKey = "fastreport.macro.stepDelayMs"
    static let legacyStorageKey = "fastreport.macro.events"
    private static let maxEvents = 400
    private static let interEventNanoseconds: UInt64 = 12_000_000
    private static let cursorSettleMs = 90

    private let defaults: UserDefaults
    private let fileURL: URL
    private let tap = MacroEventTap()
    private let mouseMonitor = MacroMouseMonitor()
    private let hotkeyTap = MacroHotkeyTap()
    private var playTask: Task<Void, Never>?
    private var lastFlags: CGEventFlags = []

    var phase: MacroPhase = .idle
    var macros: [StoredMacro] = []
    var selectedID: UUID?
    var draft: [KeyboardMacroEvent] = []
    var playbackEventIndex: Int?
    var isTrusted = AXIsProcessTrusted()
    var padOrigin: CGPoint
    var padOffset: CGSize
    var isExpanded = false
    var stepDelayMs: Int
    var currentProjectPath: String?
    var currentProjectName: String = ""
    var capture: MacroCapture = .none
    var focusedChipID: Int?
    var isAppendingRecording = false
    var onPadDrag: ((MacroPadDragPhase) -> Void)?

    private let markers = MacroClickMarkerHost()
    private let placement = MacroClickPlacementOverlay()
    private var keyCaptureMonitors: [Any] = []
    private var keyReplaceChipID: Int?
    private var isHotkeyEnabled = false
    nonisolated(unsafe) private var hotkeyConsumes = false

    init(defaults: UserDefaults = .standard, fileURL: URL? = nil) {
        self.defaults = defaults
        self.fileURL = fileURL ?? Self.defaultLibraryURL()
        let ox = defaults.double(forKey: Self.offsetXKey)
        let oy = defaults.double(forKey: Self.offsetYKey)
        padOffset = CGSize(width: ox, height: oy)
        if defaults.object(forKey: Self.originXKey) != nil {
            padOrigin = CGPoint(
                x: defaults.double(forKey: Self.originXKey),
                y: defaults.double(forKey: Self.originYKey)
            )
        } else {
            padOrigin = .zero
        }
        let storedDelay = defaults.object(forKey: Self.delayKey) as? Int ?? KeyboardMacroEvent.defaultStepDelayMs
        stepDelayMs = KeyboardMacroEvent.clampedStepDelayMs(storedDelay)
        macros = Self.load(from: self.fileURL, defaults: defaults)
        selectedID = StoredMacro.available(in: macros, projectPath: nil).first?.id
        tap.onEvent = { [weak self] payload in
            Task { @MainActor in
                self?.handleTap(payload)
            }
        }
        mouseMonitor.onClick = { [weak self] isDown, location, clickCount in
            Task { @MainActor in
                self?.handleMouse(isDown: isDown, location: location, clickCount: clickCount)
            }
        }
        markers.onMove = { [weak self] chipID, point, ended in
            self?.moveClick(chipID: chipID, to: point, persist: ended)
        }
        markers.onSelect = { [weak self] chipID in
            self?.focusedChipID = chipID
            self?.refreshMarkers()
        }
        hotkeyTap.onHotkey = { [weak self] in
            Task { @MainActor in
                self?.handlePlayHotkey()
            }
        }
    }

    var availableMacros: [StoredMacro] {
        StoredMacro.available(in: macros, projectPath: currentProjectPath)
    }

    var selected: StoredMacro? {
        availableMacros.first { $0.id == selectedID } ?? availableMacros.first
    }

    var chips: [MacroChip] {
        MacroDisplay.chips(from: visibleEvents)
    }

    var visibleEvents: [KeyboardMacroEvent] {
        if phase == .recording { return draft }
        return selected?.events ?? []
    }

    var canPlay: Bool {
        isTrusted && phase == .idle && capture == .none && !(selected?.isEmpty ?? true)
    }

    var canEdit: Bool {
        phase == .idle && capture == .none && selected != nil
    }

    var playbackChipID: Int? {
        guard phase == .playing, let index = playbackEventIndex else { return nil }
        return MacroDisplay.chips(from: Array(visibleEvents.prefix(index + 1))).last?.id
    }

    func attach(projectPath: String, displayName: String) {
        currentProjectPath = projectPath
        currentProjectName = displayName
        pruneMissingProjects()
        if let first = availableMacros.first {
            selectedID = first.id
        }
        refreshMarkers()
    }

    func detach() {
        cancelActivity()
        currentProjectPath = nil
        currentProjectName = ""
        selectedID = availableMacros.first?.id
        focusedChipID = nil
        refreshMarkers()
    }

    func refreshTrust() {
        isTrusted = AXIsProcessTrusted()
    }

    func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func startRecording(appending: Bool = false) {
        refreshTrust()
        guard isTrusted else {
            requestTrust()
            return
        }
        cancelCapture()
        playTask?.cancel()
        playTask = nil
        playbackEventIndex = nil
        isAppendingRecording = appending
        if appending, let selected {
            draft = selected.events
        } else {
            draft = []
        }
        lastFlags = CGEventSource.flagsState(.combinedSessionState)
        phase = .recording
        refreshHotkeyFlag()
        refreshMarkers()
        mouseMonitor.start()
        if !tap.start() {
            mouseMonitor.stop()
            phase = .idle
            isAppendingRecording = false
            draft = []
            refreshHotkeyFlag()
            refreshMarkers()
            requestTrust()
        }
    }

    func stopRecording() {
        tap.stop()
        mouseMonitor.stop()
        phase = .idle
        if isAppendingRecording, let selected, let index = macros.firstIndex(where: { $0.id == selected.id }) {
            macros[index].events = draft
            selectedID = selected.id
            persist()
        } else if !draft.isEmpty {
            let saved = StoredMacro(
                id: UUID(),
                name: nextDefaultName(),
                events: draft,
                recordedAt: .now,
                projectPath: currentProjectPath
            )
            macros.insert(saved, at: 0)
            selectedID = saved.id
            persist()
        }
        isAppendingRecording = false
        draft = []
        focusedChipID = chips.last?.id
        refreshHotkeyFlag()
        refreshMarkers()
    }

    func play() {
        refreshTrust()
        guard isTrusted else {
            requestTrust()
            return
        }
        guard phase == .idle, capture == .none, let events = selected?.events, !events.isEmpty else { return }
        playTask?.cancel()
        phase = .playing
        playbackEventIndex = nil
        refreshHotkeyFlag()
        refreshMarkers()
        playTask = Task { @MainActor [weak self] in
            await self?.runPlayback(events)
        }
    }

    func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playbackEventIndex = nil
        if phase == .playing {
            phase = .idle
        }
        refreshHotkeyFlag()
        refreshMarkers()
    }

    func deleteSelected() {
        guard let id = selected?.id else { return }
        stopPlayback()
        macros.removeAll { $0.id == id }
        selectedID = availableMacros.first?.id
        focusedChipID = nil
        persist()
        refreshMarkers()
    }

    func makeSelectedGlobal(name: String) {
        guard let selected, !selected.isGlobal else { return }
        if let index = macros.firstIndex(where: { $0.id == selected.id }) {
            macros[index] = selected.makingGlobal(name: name)
            selectedID = selected.id
            persist()
        }
    }

    func removeMacros(forProjectPath path: String) {
        macros = StoredMacro.removing(projectPath: path, from: macros)
        if selectedID != nil, selected == nil {
            selectedID = availableMacros.first?.id
        }
        persist()
    }

    func select(_ id: UUID) {
        selectedID = id
        focusedChipID = chips.first?.id
        refreshMarkers()
    }

    func focusChip(_ id: Int) {
        focusedChipID = id
        refreshMarkers()
    }

    func createBlank() {
        guard phase == .idle else { return }
        cancelCapture()
        let saved = StoredMacro(
            id: UUID(),
            name: nextDefaultName(),
            events: [],
            recordedAt: .now,
            projectPath: currentProjectPath
        )
        macros.insert(saved, at: 0)
        selectedID = saved.id
        focusedChipID = nil
        persist()
        refreshMarkers()
    }

    func renameSelected(_ name: String) {
        guard phase == .idle, let selected, let index = macros.firstIndex(where: { $0.id == selected.id }) else { return }
        macros[index].name = StoredMacro.normalizedName(name)
        persist()
    }

    func beginKeyCapture(replacing chipID: Int? = nil) {
        guard phase == .idle else { return }
        ensureSelectedForEditing()
        guard selected != nil else { return }
        refreshTrust()
        cancelCapture()
        keyReplaceChipID = chipID
        if let chipID {
            focusedChipID = chipID
        }
        capture = .key
        refreshHotkeyFlag()
        refreshMarkers()
        let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleCapturedKey(event)
            }
            return nil
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleCapturedKey(event)
            }
        }
        keyCaptureMonitors.append(contentsOf: [local, global].compactMap { $0 })
    }

    func beginClickCapture() {
        guard phase == .idle else { return }
        ensureSelectedForEditing()
        guard selected != nil else { return }
        cancelCapture()
        capture = .click
        refreshHotkeyFlag()
        refreshMarkers()
        placement.begin { [weak self] point in
            self?.insertEvents(MacroSequence.clickEvents(at: point))
            self?.capture = .none
            self?.refreshHotkeyFlag()
            self?.refreshMarkers()
        } onCancel: { [weak self] in
            self?.capture = .none
            self?.refreshHotkeyFlag()
            self?.refreshMarkers()
        }
    }

    func cancelCapture(clearReplace: Bool = true) {
        placement.end()
        for monitor in keyCaptureMonitors {
            NSEvent.removeMonitor(monitor)
        }
        keyCaptureMonitors.removeAll()
        if clearReplace {
            keyReplaceChipID = nil
        }
        if capture != .none {
            capture = .none
            refreshHotkeyFlag()
            refreshMarkers()
        }
    }

    func deleteChip(_ id: Int) {
        guard canEdit, let chip = chips.first(where: { $0.id == id }) else { return }
        mutateSelectedEvents { MacroSequence.removingStep(in: $0, chip: chip) }
        focusedChipID = chips.last(where: { $0.id < id })?.id ?? chips.first?.id
        refreshMarkers()
    }

    func moveChip(_ id: Int, offset: Int) {
        guard canEdit, let chip = chips.first(where: { $0.id == id }) else { return }
        mutateSelectedEvents { MacroSequence.movingStep(in: $0, chip: chip, offset: offset) }
        let movedNumber = chip.stepNumber + offset
        focusedChipID = chips.first(where: { $0.stepNumber == movedNumber })?.id ?? id
        refreshMarkers()
    }

    func moveClick(chipID: Int, to point: CGPoint, persist: Bool) {
        guard phase != .recording, let chip = chips.first(where: { $0.id == chipID }) else { return }
        focusedChipID = chipID
        mutateSelectedEvents(persist: persist) { MacroSequence.movingClick(in: $0, chip: chip, to: point) }
        if persist {
            refreshMarkers()
        }
    }

    func cancelActivity() {
        cancelCapture()
        if phase == .recording {
            stopRecording()
        } else {
            stopPlayback()
        }
        markers.closeAll()
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        if !expanded {
            cancelCapture()
        }
        refreshMarkers()
    }

    func setHotkeyEnabled(_ enabled: Bool) {
        isHotkeyEnabled = enabled
        refreshHotkeyFlag()
        if enabled {
            refreshTrust()
            if !hotkeyTap.start() {
                requestTrust()
            }
        } else {
            hotkeyTap.stop()
        }
    }

    func dragPad(_ phase: MacroPadDragPhase) {
        onPadDrag?(phase)
    }

    func setPadOffset(_ offset: CGSize) {
        padOffset = offset
        defaults.set(Double(offset.width), forKey: Self.offsetXKey)
        defaults.set(Double(offset.height), forKey: Self.offsetYKey)
    }

    func setPadOrigin(_ origin: CGPoint) {
        padOrigin = origin
        defaults.set(Double(origin.x), forKey: Self.originXKey)
        defaults.set(Double(origin.y), forKey: Self.originYKey)
    }

    func setStepDelayMs(_ value: Int) {
        stepDelayMs = KeyboardMacroEvent.clampedStepDelayMs(value)
        defaults.set(stepDelayMs, forKey: Self.delayKey)
    }

    private func nextDefaultName() -> String {
        let count = availableMacros.filter { !$0.isGlobal }.count + 1
        return String(localized: "macro.defaultName \(count)")
    }

    private func ensureSelectedForEditing() {
        if selected == nil {
            createBlank()
        }
    }

    private func handleCapturedKey(_ event: NSEvent) {
        guard capture == .key else { return }
        if event.keyCode == 53 {
            cancelCapture()
            refreshMarkers()
            return
        }
        var flags: UInt64 = 0
        if event.modifierFlags.contains(.control) { flags |= CGEventFlags.maskControl.rawValue }
        if event.modifierFlags.contains(.option) { flags |= CGEventFlags.maskAlternate.rawValue }
        if event.modifierFlags.contains(.shift) { flags |= CGEventFlags.maskShift.rawValue }
        if event.modifierFlags.contains(.command) { flags |= CGEventFlags.maskCommand.rawValue }
        cancelCapture(clearReplace: false)
        insertEvents(MacroSequence.keyEvents(code: event.keyCode, flags: flags))
        refreshHotkeyFlag()
        refreshMarkers()
    }

    private func insertEvents(_ addition: [KeyboardMacroEvent]) {
        ensureSelectedForEditing()
        if let replaceID = keyReplaceChipID, let chip = chips.first(where: { $0.id == replaceID }) {
            mutateSelectedEvents { MacroSequence.replacingStep(in: $0, chip: chip, with: addition) }
            focusedChipID = replaceID
            keyReplaceChipID = nil
            return
        }
        let insertAt: Int
        if let focus = focusedChipID, let chip = chips.first(where: { $0.id == focus }) {
            insertAt = chip.eventIndex + chip.eventCount
        } else {
            insertAt = selected?.events.count ?? 0
        }
        mutateSelectedEvents { current in
            MacroSequence.inserting(addition, in: current, atEventIndex: insertAt)
        }
        if let focus = focusedChipID {
            focusedChipID = focus + 1
        } else {
            focusedChipID = chips.last?.id
        }
    }

    private func mutateSelectedEvents(persist shouldPersist: Bool = true, _ transform: ([KeyboardMacroEvent]) -> [KeyboardMacroEvent]) {
        guard let selected, let index = macros.firstIndex(where: { $0.id == selected.id }) else { return }
        let next = transform(macros[index].events)
        guard next.count <= Self.maxEvents else { return }
        macros[index].events = next
        if shouldPersist {
            persist()
        }
    }

    private func refreshMarkers() {
        let show = isExpanded && capture != .click && phase != .recording
        let models: [MacroClickMarkerModel] = chips.compactMap { chip in
            guard let point = chip.cocoaPoint else { return nil }
            return MacroClickMarkerModel(
                id: chip.id,
                stepNumber: chip.stepNumber,
                cocoaPoint: point,
                isFocused: focusedChipID == chip.id,
                isActivePlayback: playbackChipID == chip.id
            )
        }
        markers.sync(models, visible: show)
    }

    private func handlePlayHotkey() {
        if phase == .playing {
            stopPlayback()
            return
        }
        play()
    }

    private func refreshHotkeyFlag() {
        hotkeyConsumes = isHotkeyEnabled && capture == .none && phase != .recording
        hotkeyTap.consumes = hotkeyConsumes
    }

    private func runPlayback(_ events: [KeyboardMacroEvent]) async {
        try? await Task.sleep(for: .milliseconds(180))
        var awaitingStepDelay = false
        for (index, event) in events.enumerated() {
            if Task.isCancelled { break }
            playbackEventIndex = index
            if event.isPlaybackStep {
                refreshMarkers()
                if awaitingStepDelay {
                    let delay = event.kind == .mouseMove ? Self.cursorSettleMs : stepDelayMs
                    try? await Task.sleep(for: .milliseconds(delay))
                }
                awaitingStepDelay = true
            } else if index > 0 {
                try? await Task.sleep(nanoseconds: Self.interEventNanoseconds)
            }
            if Task.isCancelled { break }
            MacroPlayer.post(event)
        }
        playbackEventIndex = nil
        playTask = nil
        if phase == .playing {
            phase = .idle
        }
        refreshHotkeyFlag()
        refreshMarkers()
    }

    private func handleTap(_ payload: MacroTapPayload) {
        if payload.type == .tapDisabledByTimeout || payload.type == .tapDisabledByUserInput {
            tap.reenable()
            return
        }
        guard phase == .recording, !payload.isRepeat else { return }

        switch payload.type {
        case .keyDown, .keyUp:
            append(.key(code: payload.keyCode, flags: payload.flags, down: payload.type == .keyDown))
        case .flagsChanged:
            let newFlags = CGEventFlags(rawValue: payload.flags)
            let modifier = Self.flag(forModifierKey: payload.keyCode)
            let wasOn = modifier.map { lastFlags.contains($0) } ?? false
            let isOn = modifier.map { newFlags.contains($0) } ?? false
            lastFlags = newFlags
            if wasOn != isOn {
                append(.key(code: payload.keyCode, flags: payload.flags, down: isOn))
            }
        default:
            break
        }
    }

    private func handleMouse(isDown: Bool, location: CGPoint, clickCount: Int) {
        guard phase == .recording else { return }
        if isDown {
            append(.mouseMove(to: location))
            append(.mouseDown(at: location, count: clickCount))
        } else {
            append(.mouseUp(at: location, count: clickCount))
        }
    }

    private func append(_ event: KeyboardMacroEvent) {
        guard draft.count < Self.maxEvents else { return }
        draft.append(event)
    }

    private func pruneMissingProjects() {
        let before = macros.count
        macros.removeAll { macro in
            guard let path = macro.projectPath else { return false }
            var isDirectory: ObjCBool = false
            return !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue
        }
        if macros.count != before {
            persist()
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(MacroLibraryFile(macros: macros))
            try data.write(to: fileURL, options: [.atomic])
            defaults.removeObject(forKey: Self.legacyStorageKey)
        } catch {
            return
        }
    }

    private static func load(from fileURL: URL, defaults: UserDefaults) -> [StoredMacro] {
        if let data = try? Data(contentsOf: fileURL),
           let file = try? JSONDecoder().decode(MacroLibraryFile.self, from: data) {
            return file.macros
        }
        if let data = defaults.data(forKey: legacyStorageKey),
           let legacy = try? JSONDecoder().decode(KeyboardMacro.self, from: data),
           !legacy.events.isEmpty {
            return [
                StoredMacro(
                    id: UUID(),
                    name: String(localized: "macro.migrated"),
                    events: legacy.events,
                    recordedAt: legacy.recordedAt,
                    projectPath: nil
                )
            ]
        }
        return []
    }

    private static func defaultLibraryURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent("FastReport", isDirectory: true).appendingPathComponent("macros.json")
    }

    private static func flag(forModifierKey keyCode: UInt16) -> CGEventFlags? {
        switch keyCode {
        case 54, 55: return .maskCommand
        case 56, 60: return .maskShift
        case 58, 61: return .maskAlternate
        case 59, 62: return .maskControl
        default: return nil
        }
    }
}

enum MacroScreen {
    /// `NSEvent.mouseLocation` is Cocoa (origin bottom-left of the main screen).
    /// Warp / `CGEvent` mouse positions are Quartz (origin top-left of the main display).
    static func quartzPoint(fromCocoa cocoa: CGPoint) -> CGPoint {
        let height = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
        return CGPoint(x: cocoa.x, y: height - cocoa.y)
    }
}

enum MacroPlayer {
    static func post(_ event: KeyboardMacroEvent) {
        let source = CGEventSource(stateID: .hidSystemState)
        let quartz = MacroScreen.quartzPoint(fromCocoa: event.point)
        switch event.kind {
        case .key:
            let posted = CGEvent(keyboardEventSource: source, virtualKey: event.keyCode, keyDown: event.isKeyDown)
            posted?.flags = event.cgFlags
            posted?.post(tap: .cghidEventTap)
        case .mouseMove:
            warpCursor(to: quartz)
        case .mouseDown, .mouseUp:
            warpCursor(to: quartz)
            let type: CGEventType = event.kind == .mouseDown ? .leftMouseDown : .leftMouseUp
            let posted = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: quartz,
                mouseButton: .left
            )
            posted?.setIntegerValueField(.mouseEventClickState, value: Int64(max(event.clickCount, 1)))
            posted?.post(tap: .cghidEventTap)
        }
    }

    private static func warpCursor(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }
}

struct MacroTapPayload: Sendable {
    var type: CGEventType
    var keyCode: UInt16
    var flags: UInt64
    var isRepeat: Bool
}

final class MacroMouseMonitor: @unchecked Sendable {
    var onClick: (@Sendable (_ isDown: Bool, _ location: CGPoint, _ clickCount: Int) -> Void)?
    private var downMonitor: Any?
    private var upMonitor: Any?

    func start() {
        guard downMonitor == nil else { return }
        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.onClick?(true, NSEvent.mouseLocation, event.clickCount)
        }
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.onClick?(false, NSEvent.mouseLocation, event.clickCount)
        }
    }

    func stop() {
        if let downMonitor {
            NSEvent.removeMonitor(downMonitor)
        }
        if let upMonitor {
            NSEvent.removeMonitor(upMonitor)
        }
        downMonitor = nil
        upMonitor = nil
    }

    deinit {
        stop()
    }
}

final class MacroHotkeyTap: @unchecked Sendable {
    var onHotkey: (@Sendable () -> Void)?
    var consumes = false
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        if port != nil { return true }
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<MacroHotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    tap.reenable()
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                let mods = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
                guard keyCode == 49, !isRepeat, mods == .maskCommand, tap.consumes else {
                    return Unmanaged.passUnretained(event)
                }
                tap.onHotkey?()
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        port = tap
        source = loopSource
        return true
    }

    func reenable() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    func stop() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        port = nil
        source = nil
    }

    deinit {
        stop()
    }
}

final class MacroEventTap: @unchecked Sendable {
    var onEvent: (@Sendable (MacroTapPayload) -> Void)?
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        if port != nil { return true }
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<MacroEventTap>.fromOpaque(refcon).takeUnretainedValue()
                let payload = MacroTapPayload(
                    type: type,
                    keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                    flags: event.flags.rawValue,
                    isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                )
                tap.onEvent?(payload)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        port = tap
        source = loopSource
        return true
    }

    func reenable() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    func stop() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        port = nil
        source = nil
    }

    deinit {
        stop()
    }
}
