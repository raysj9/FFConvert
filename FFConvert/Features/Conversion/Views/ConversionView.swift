//
//  ConversionView.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConversionView: View {
    @StateObject private var viewModel = ConversionViewModel()

    var body: some View {
        NavigationSplitView {
            recentHistorySidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
        } detail: {
            ZStack {
                ConversionBackground()

                VStack(alignment: .leading, spacing: 24) {
                    intakeCards
                    topControls
                    workingFilePanel
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(28)

                if viewModel.isDropTargeted {
                    DropTargetOverlay()
                        .padding(20)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingActionControl(
                    title: viewModel.toolbarActionTitle,
                    isRunning: viewModel.isRunning,
                    isDisabled: viewModel.isRunning ? viewModel.isCancellationRequested : !viewModel.canStartQueue
                ) {
                    if viewModel.isRunning {
                        viewModel.cancelQueue()
                    } else {
                        viewModel.startQueue()
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .fileImporter(
            isPresented: $viewModel.isShowingInputPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleInputSelection
        )
        .dropDestination(for: URL.self) { items, _ in
            viewModel.handleDroppedFiles(items)
            return !items.isEmpty
        } isTargeted: { isTargeted in
            viewModel.isDropTargeted = isTargeted
        }
    }

    private var intakeCards: some View {
        HStack(spacing: 20) {
            FileSelectionCard(
                title: "Source File",
                subtitle: "Work on one file at a time",
                path: currentInputPath,
                symbolName: "doc",
                accentColor: Color(red: 0.18, green: 0.46, blue: 0.91),
                buttonTitle: "Choose File",
                buttonSymbolName: "plus",
                action: viewModel.showInputPicker
            )

            FileSelectionCard(
                title: "Output Folder",
                subtitle: "Where the converted file will be written",
                path: currentOutputFolderPath,
                symbolName: "folder",
                accentColor: Color(red: 0.10, green: 0.63, blue: 0.50),
                buttonTitle: "Choose Folder",
                buttonSymbolName: "folder.badge.gearshape",
                isButtonDisabled: !viewModel.canChooseDestination,
                action: viewModel.chooseOutputDirectory
            )
        }
    }

    private var topControls: some View {
        HStack(spacing: 16) {
            FormatPresetPicker(
                selectedPreset: viewModel.selectedPreset,
                isDisabled: viewModel.isRunning,
                onSelect: viewModel.selectPreset
            )

            Text(workingSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var workingFilePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current File")
                .font(.headline)

            if let item = viewModel.currentItem {
                QueueItemRow(
                    item: item,
                    onOpen: item.status == .succeeded ? { viewModel.openOutput(item.outputURL) } : nil,
                    onReveal: item.status == .succeeded ? { viewModel.revealOutput(item.outputURL) } : nil
                )

                selectedItemPanel(item)
            } else {
                Text("Choose a file or drop one onto the window to begin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(SurfaceCardModifier(accentColor: Color(red: 0.18, green: 0.46, blue: 0.91), cornerRadius: 26))
    }

    @ViewBuilder
    private func selectedItemPanel(_ item: ConversionQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let mediaInfo = item.mediaInfo {
                HStack(spacing: 18) {
                    InspectionValue(label: "Duration", value: mediaInfo.formattedDuration)
                    InspectionValue(label: "Video", value: mediaInfo.videoSummary)
                    InspectionValue(label: "Audio", value: mediaInfo.audioSummary)
                }
            } else {
                Text("Inspecting media…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let compatibilityResult = item.compatibilityResult {
                Label(
                    compatibilityResult.message,
                    systemImage: compatibilityResult.isCompatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(compatibilityResult.isCompatible ? Color.green : Color.orange)
            }

            if let progressFraction = item.progressFraction,
               item.status == .converting || item.status == .cancelling {
                ProgressView(value: progressFraction)
                    .tint(statusColor(for: item.status))
                    .controlSize(.small)
            }

            Text(item.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorSummary = item.errorSummary {
                Divider()
                Text(errorSummary)
                    .font(.subheadline)

                if !item.diagnosticsOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DisclosureGroup("Show Details") {
                        ScrollView {
                            Text(item.diagnosticsOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 120)
                    }
                }
            }
        }
    }

    private var recentHistorySidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)

            if viewModel.recentConversions.isEmpty {
                Text("Completed, cancelled, and failed jobs will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recentConversions) { item in
                            HistoryRow(
                                item: item,
                                onRetry: { viewModel.retry(item) },
                                onOpen: item.outputURL.map { url in { viewModel.openOutput(url) } },
                                onReveal: item.outputURL.map { url in { viewModel.revealOutput(url) } }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var currentInputPath: String {
        viewModel.currentItem?.inputURL.path(percentEncoded: false) ?? "No file selected"
    }

    private var currentOutputFolderPath: String {
        viewModel.outputDirectoryURL?.path(percentEncoded: false)
        ?? viewModel.currentItem?.inputURL.deletingLastPathComponent().path(percentEncoded: false)
        ?? "Using each source file's folder"
    }

    private var workingSummary: String {
        if let current = viewModel.currentItem {
            return current.progressText
        }

        return "Choose a file to inspect it and convert it."
    }

    private func statusColor(for status: ConversionQueueItem.Status) -> Color {
        switch status {
        case .inspecting:
            return .secondary
        case .ready:
            return .blue
        case .converting:
            return .accentColor
        case .cancelling:
            return .orange
        case .cancelled:
            return .secondary
        case .succeeded:
            return Color(red: 0.11, green: 0.58, blue: 0.36)
        case .failed, .incompatible:
            return Color(red: 0.78, green: 0.21, blue: 0.24)
        }
    }
}

private struct QueueItemRow: View {
    let item: ConversionQueueItem
    var onOpen: (() -> Void)?
    var onReveal: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.inputURL.lastPathComponent)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(item.outputURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: item.status)
            }

            if let progressFraction = item.progressFraction,
               item.status == .converting || item.status == .cancelling {
                ProgressView(value: progressFraction)
                    .controlSize(.small)
            }

            Text(item.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if item.status == .succeeded, let onOpen {
                    SmallActionButton(title: "Open", action: onOpen)
                }

                if item.status == .succeeded, let onReveal {
                    SmallActionButton(title: "Reveal", action: onReveal)
                }

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct HistoryRow: View {
    let item: ConversionHistoryItem
    let onRetry: () -> Void
    var onOpen: (() -> Void)?
    var onReveal: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.inputURL.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text(item.result.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(historyColor)
            }

            Text(item.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                SmallActionButton(title: "Retry", action: onRetry)

                if let onOpen {
                    SmallActionButton(title: "Open", action: onOpen)
                }

                if let onReveal {
                    SmallActionButton(title: "Reveal", action: onReveal)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var historyColor: Color {
        switch item.result {
        case .succeeded:
            return Color(red: 0.11, green: 0.58, blue: 0.36)
        case .cancelled:
            return .secondary
        case .failed, .incompatible:
            return Color(red: 0.78, green: 0.21, blue: 0.24)
        }
    }
}

private struct SmallActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.72), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
    }
}

private struct StatusBadge: View {
    let status: ConversionQueueItem.Status

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.14), in: Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .inspecting:
            return .secondary
        case .ready:
            return .blue
        case .converting:
            return .accentColor
        case .cancelling:
            return .orange
        case .cancelled:
            return .secondary
        case .succeeded:
            return Color(red: 0.11, green: 0.58, blue: 0.36)
        case .failed, .incompatible:
            return Color(red: 0.78, green: 0.21, blue: 0.24)
        }
    }
}

private struct InspectionValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SurfaceCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let accentColor: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: 1)
            }
    }

    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        accentColor.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.82),
                    accentColor.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55)
    }
}

private struct FloatingActionControl: View {
    let title: String
    let isRunning: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isRunning ? "xmark.circle.fill" : "bolt.fill")
                    .font(.subheadline.weight(.semibold))

                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(isRunning ? Color.orange : Color.accentColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .glassEffect(
            .regular
                .tint((isRunning ? Color.orange : Color.accentColor).opacity(0.12))
                .interactive(),
            in: .capsule
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
    }
}

private struct FormatPresetPicker: View {
    let selectedPreset: ConversionPreset
    let isDisabled: Bool
    let onSelect: (ConversionPreset) -> Void

    var body: some View {
        Menu {
            ForEach(ConversionPreset.allCases) { preset in
                Button {
                    onSelect(preset)
                } label: {
                    Label(preset.title, systemImage: preset.symbolName)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedPreset.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.72), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Output Preset")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selectedPreset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.32), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(selectedPreset.subtitle)
    }
}

private struct FileSelectionCard: View {
    let title: String
    let subtitle: String
    let path: String?
    let symbolName: String
    let accentColor: Color
    let buttonTitle: String
    var buttonSymbolName = "arrow.right"
    var isButtonDisabled = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(accentColor.gradient, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(path ?? "Nothing selected yet")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)

            Button(action: action) {
                HStack(spacing: 10) {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.semibold))

                    Image(systemName: buttonSymbolName)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.72), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(isButtonDisabled)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .modifier(SurfaceCardModifier(accentColor: accentColor, cornerRadius: 28))
    }
}

private struct DropTargetOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 34)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
            .foregroundStyle(Color.accentColor.opacity(0.8))
            .background {
                RoundedRectangle(cornerRadius: 34)
                    .fill(Color.accentColor.opacity(0.08))
            }
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text("Drop files to add them to the queue")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct ConversionBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(topHighlightColor)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .offset(x: -40, y: -120)
        }
        .overlay(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 120)
                .fill(bottomHighlightColor)
                .frame(width: 420, height: 320)
                .blur(radius: 36)
                .offset(x: 120, y: 90)
        }
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.10, blue: 0.14),
                Color(red: 0.06, green: 0.12, blue: 0.18),
                Color(red: 0.08, green: 0.14, blue: 0.12)
            ]
        }

        return [
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.88, green: 0.93, blue: 0.99),
            Color(red: 0.92, green: 0.96, blue: 0.93)
        ]
    }

    private var topHighlightColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08)
        }

        return Color.white.opacity(0.65)
    }

    private var bottomHighlightColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.30, green: 0.50, blue: 0.78).opacity(0.18)
        }

        return Color(red: 0.58, green: 0.76, blue: 0.98).opacity(0.25)
    }
}
