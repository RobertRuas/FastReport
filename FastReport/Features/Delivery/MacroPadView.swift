import AppKit
import SwiftUI

struct MacroPadView: View {
    @Environment(KeyboardMacroCenter.self) private var macros
    @State private var draggingPad = false
    @State private var globalName = ""
    @State private var showGlobalSheet = false

    var body: some View {
        expandedPad
            .onAppear { macros.refreshTrust() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                macros.refreshTrust()
            }
            .sheet(isPresented: $showGlobalSheet) {
                globalNameSheet
            }
    }

    private var expandedPad: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            picker
            captureBanner
            sequence
            editorActions
            delayControl
            footer
        }
        .padding(14)
        .frame(width: 372, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(macros.phase == .recording ? 0.28 : 0.08), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "command.square.fill")
                .foregroundStyle(macros.phase == .recording ? Color.red : Color.accentColor)
            Text("macro.title")
                .font(.headline)
            Spacer(minLength: 4)
            if macros.phase == .recording {
                RecordingDot()
            }
            compactActions
            expandButton
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .help("macro.drag.hint")
    }

    private var compactActions: some View {
        HStack(spacing: 6) {
            if macros.phase == .recording {
                padButton(
                    systemImage: "stop.fill",
                    help: "macro.stop",
                    hint: "macro.stop.hint",
                    tint: .red,
                    filled: true,
                    compact: true,
                    action: macros.stopRecording
                )
            } else {
                padButton(
                    systemImage: "record.circle",
                    help: "macro.record",
                    hint: "macro.record.hint",
                    tint: .red,
                    compact: true,
                    isDisabled: macros.capture != .none,
                    action: { macros.startRecording() }
                )
            }
            if macros.phase == .playing {
                padButton(
                    systemImage: "stop.fill",
                    help: "macro.stop",
                    hint: "macro.stop.hint",
                    compact: true,
                    action: macros.stopPlayback
                )
            } else {
                padButton(
                    systemImage: "play.fill",
                    help: "macro.play",
                    hint: "macro.play.hint",
                    filled: true,
                    compact: true,
                    isDisabled: !macros.canPlay,
                    action: macros.play
                )
            }
        }
    }

    private var expandButton: some View {
        padButton(
            systemImage: macros.isExpanded ? "chevron.down" : "chevron.up",
            help: macros.isExpanded ? "macro.collapse" : "macro.expand",
            hint: macros.isExpanded ? "macro.collapse.hint" : "macro.expand.hint",
            compact: true
        ) {
            macros.setExpanded(!macros.isExpanded)
        }
    }

    private var picker: some View {
        HStack(spacing: 8) {
            if macros.availableMacros.isEmpty {
                Text("macro.empty")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Picker("macro.current", selection: selectionBinding) {
                    ForEach(macros.availableMacros) { item in
                        Text(item.isGlobal ? "\(item.name) · Global" : item.name)
                            .tag(Optional(item.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(macros.phase != .idle || macros.capture != .none)
                .hoverHint("macro.current", hint: "macro.select.help", placement: .above)
            }
            padButton(
                systemImage: "plus",
                help: "macro.new",
                hint: "macro.new.hint",
                compact: true,
                isDisabled: macros.phase != .idle || macros.capture != .none,
                action: macros.createBlank
            )
        }
    }

    @ViewBuilder
    private var captureBanner: some View {
        switch macros.capture {
        case .none:
            EmptyView()
        case .key:
            captureRow(text: "macro.capture.key")
        case .click:
            captureRow(text: "macro.capture.click")
        }
    }

    private func captureRow(text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("common.cancel") {
                macros.cancelCapture()
            }
            .controlSize(.small)
            .hoverHint("common.cancel", hint: "macro.capture.cancel.hint", placement: .above)
        }
    }

    @ViewBuilder
    private var sequence: some View {
        if !macros.isTrusted {
            trustBanner
        } else if macros.chips.isEmpty {
            Text(macros.phase == .recording ? "macro.recording.help" : "macro.editor.help")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(macros.chips) { chip in
                        stepRow(chip)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func stepRow(_ chip: MacroChip) -> some View {
        let focused = macros.focusedChipID == chip.id || macros.playbackChipID == chip.id
        return HStack(spacing: 8) {
            Text(String(localized: "macro.step \(chip.stepNumber)"))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(focused ? Color.white : Color.primary)
                .frame(width: 28, height: 22)
                .background(
                    Capsule().fill(focused ? Color.accentColor : Color.primary.opacity(0.08))
                )
            chipView(chip)
            Spacer(minLength: 0)
            if macros.canEdit {
                if case .key = chip.kind {
                    Button {
                        macros.beginKeyCapture(replacing: chip.id)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("macro.editKey")
                    .hoverHint("macro.editKey", hint: "macro.editKey.hint", placement: .above)
                }
                Button {
                    macros.moveChip(chip.id, offset: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(chip.id == 0)
                .help("macro.moveUp")
                Button {
                    macros.moveChip(chip.id, offset: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(chip.id == (macros.chips.last?.id ?? 0))
                .help("macro.moveDown")
                Button {
                    macros.deleteChip(chip.id)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("macro.deleteStep")
                .hoverHint("macro.deleteStep", hint: "macro.deleteStep.hint", placement: .above)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(focused ? 0.08 : 0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture { macros.focusChip(chip.id) }
        .opacity(isActive(chip) ? 1 : 0.45)
    }

    private var editorActions: some View {
        HStack(spacing: 6) {
            padButton(
                systemImage: "keyboard",
                help: "macro.addKey",
                hint: "macro.addKey.hint",
                compact: true,
                isDisabled: macros.phase != .idle || macros.capture != .none,
                action: { macros.beginKeyCapture() }
            )
            padButton(
                systemImage: "hand.tap",
                help: "macro.addClick",
                hint: "macro.addClick.hint",
                compact: true,
                isDisabled: macros.phase != .idle || macros.capture != .none,
                action: macros.beginClickCapture
            )
            padButton(
                systemImage: "plus",
                help: "macro.append",
                hint: "macro.append.hint",
                tint: .red,
                compact: true,
                isDisabled: macros.selected == nil || macros.phase != .idle || macros.capture != .none,
                action: { macros.startRecording(appending: true) }
            )
            Spacer(minLength: 0)
        }
    }

    private var delayControl: some View {
        HStack(spacing: 8) {
            Text("macro.delay")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Stepper(value: delayBinding, in: KeyboardMacroEvent.minStepDelayMs...KeyboardMacroEvent.maxStepDelayMs, step: 50) {
                Text(delayLabel)
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 64, alignment: .trailing)
            }
            .disabled(macros.phase != .idle)
        }
        .hoverHint("macro.delay", hint: "macro.delay.hint", placement: .above)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            padButton(
                systemImage: "globe",
                help: "macro.makeGlobal",
                hint: "macro.makeGlobal.hint",
                isDisabled: macros.selected == nil || macros.selected?.isGlobal == true || macros.phase != .idle
            ) {
                globalName = MacroDisplay.suggestedGlobalName(from: macros.selected?.name ?? "Macro")
                showGlobalSheet = true
            }
            Spacer(minLength: 0)
            padButton(
                systemImage: "trash",
                help: "macro.clear",
                hint: "macro.clear.hint",
                isDisabled: macros.selected == nil || macros.phase != .idle,
                action: macros.deleteSelected
            )
        }
    }

    private var globalNameSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("macro.makeGlobal.title")
                .font(.headline)
            Text("macro.makeGlobal.body")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("macro.makeGlobal.name", text: $globalName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("common.cancel") { showGlobalSheet = false }
                Button("macro.makeGlobal.confirm") {
                    macros.makeSelectedGlobal(name: globalName)
                    showGlobalSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(globalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var trustBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macro.needsTrust")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: macros.requestTrust) {
                Text("macro.grant")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .hoverHint("macro.grant", hint: "macro.grant.hint")
        }
    }

    @ViewBuilder
    private func chipView(_ chip: MacroChip) -> some View {
        switch chip.kind {
        case .click(let x, let y):
            Text("macro.chip.click \(x) \(y)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                }
        case .key(let parts):
            HStack(spacing: 3) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Text(part)
                        .font(.caption.weight(.semibold).monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                        }
                }
            }
        }
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { macros.selectedID ?? macros.selected?.id },
            set: { if let id = $0 { macros.select(id) } }
        )
    }

    private var delayBinding: Binding<Int> {
        Binding(
            get: { macros.stepDelayMs },
            set: { macros.setStepDelayMs($0) }
        )
    }

    private var delayLabel: String {
        String(localized: "macro.delay.value \(macros.stepDelayMs)")
    }

    private func isActive(_ chip: MacroChip) -> Bool {
        guard macros.phase == .playing, let index = macros.playbackEventIndex else {
            return true
        }
        let mapped = chipIndex(forEvent: index)
        return mapped == chip.id
    }

    private func chipIndex(forEvent eventIndex: Int) -> Int? {
        let events = macros.visibleEvents
        guard events.indices.contains(eventIndex) else { return nil }
        let prefix = Array(events.prefix(eventIndex + 1))
        return MacroDisplay.chips(from: prefix).last?.id
    }

    private func padButton(
        systemImage: String,
        help: LocalizedStringKey,
        hint: LocalizedStringKey,
        title: LocalizedStringKey? = nil,
        tint: Color = .primary,
        filled: Bool = false,
        compact: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        IconActionButton(
            systemImage: systemImage,
            help: help,
            hint: hint,
            hintPlacement: .above,
            title: title,
            tint: tint,
            filled: filled,
            isDisabled: isDisabled,
            compact: compact,
            action: action
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { _ in
                if !draggingPad {
                    draggingPad = true
                    macros.dragPad(.began)
                }
                macros.dragPad(.changed)
            }
            .onEnded { _ in
                macros.dragPad(.ended)
                draggingPad = false
            }
    }
}

private struct RecordingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.25 : 0.85)
            .opacity(pulse ? 1 : 0.55)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
