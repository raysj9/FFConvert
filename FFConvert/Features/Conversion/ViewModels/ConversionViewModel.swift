//
//  ConversionViewModel.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Combine
import AppKit
import Foundation

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published var queueItems: [ConversionQueueItem] = []
    @Published var recentConversions: [ConversionHistoryItem] = []
    @Published var selectedQueueItemID: ConversionQueueItem.ID?
    @Published var outputDirectoryURL: URL?
    @Published var selectedPreset: ConversionPreset = .mp4H264
    @Published var isShowingInputPicker = false
    @Published var isRunning = false
    @Published var isDropTargeted = false
    @Published var statusMessage = "Add files to build a conversion queue."
    @Published private(set) var isCancellationRequested = false

    private let fileSelectionService: FileSelectionService
    private let commandBuilder: FFmpegCommandBuilder
    private let outputFileCoordinator: OutputFileCoordinator
    private let outputConflictResolver: OutputConflictResolver
    private let compatibilityValidator: PresetCompatibilityValidator
    private let failureSummarizer: ConversionFailureSummarizer
    private let ffprobeService: FFprobeService
    private let runner: FFmpegRunner
    private var inspectionTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        self.fileSelectionService = FileSelectionService()
        self.commandBuilder = FFmpegCommandBuilder()
        self.outputFileCoordinator = OutputFileCoordinator()
        self.outputConflictResolver = OutputConflictResolver()
        self.compatibilityValidator = PresetCompatibilityValidator()
        self.failureSummarizer = ConversionFailureSummarizer()
        self.ffprobeService = FFprobeService(ffprobePath: "/opt/homebrew/bin/ffprobe")
        self.runner = FFmpegRunner(ffmpegPath: "/opt/homebrew/bin/ffmpeg")
    }

    var selectedQueueItem: ConversionQueueItem? {
        guard let selectedQueueItemID else { return queueItems.first }
        return queueItems.first(where: { $0.id == selectedQueueItemID }) ?? queueItems.first
    }

    var currentQueueItem: ConversionQueueItem? {
        queueItems.first(where: { $0.status == .converting || $0.status == .cancelling })
    }

    var currentItem: ConversionQueueItem? {
        currentQueueItem ?? selectedQueueItem
    }

    var canChooseDestination: Bool {
        !isRunning
    }

    var canStartQueue: Bool {
        queueItems.contains(where: { $0.status == .ready }) && !isRunning
    }

    var toolbarActionTitle: String {
        isRunning ? "Cancel Queue" : "Convert"
    }

    var queueSummary: String {
        let readyCount = queueItems.filter { $0.status == .ready }.count
        let finishedCount = queueItems.filter { $0.status == .succeeded }.count

        if isRunning, let currentQueueItem {
            return "Converting \(currentQueueItem.inputURL.lastPathComponent)"
        }

        if readyCount > 0 {
            return "\(readyCount) file\(readyCount == 1 ? "" : "s") ready. \(finishedCount) completed."
        }

        if queueItems.isEmpty {
            return "No queued files."
        }

        return "\(finishedCount) completed."
    }

    func showInputPicker() {
        guard !isRunning else { return }
        isShowingInputPicker = true
    }

    func handleInputSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            replaceWorkingItem(with: urls)
        case .failure(let error):
            statusMessage = "Could not add files: \(error.localizedDescription)"
        }
    }

    func handleDroppedFiles(_ urls: [URL]) {
        guard !isRunning else { return }
        replaceWorkingItem(with: urls)
    }

    func chooseOutputDirectory() {
        guard !isRunning else { return }

        let initialDirectory = outputDirectoryURL ?? selectedQueueItem?.inputURL.deletingLastPathComponent()
        if let directory = fileSelectionService.selectOutputDirectory(initialDirectory: initialDirectory) {
            outputDirectoryURL = directory
            updateOutputURLsForQueuedItems()
            statusMessage = "Output folder updated."
        }
    }

    func selectPreset(_ preset: ConversionPreset) {
        guard !isRunning else { return }

        selectedPreset = preset

        for index in queueItems.indices {
            guard queueItems[index].status != .succeeded else { continue }
            queueItems[index].preset = preset
            queueItems[index].outputURL = fileSelectionService.updatedOutputURL(
                from: queueItems[index].outputURL,
                inputURL: queueItems[index].inputURL,
                preset: preset,
                outputDirectory: outputDirectoryURL
            )
            updateCompatibility(for: queueItems[index].id)
        }

        statusMessage = "\(preset.title) selected."
    }

    func startQueue() {
        guard canStartQueue else { return }

        isRunning = true
        isCancellationRequested = false
        statusMessage = "Starting queue…"

        Task {
            await processQueue()
        }
    }

    func cancelQueue() {
        guard isRunning, !isCancellationRequested else { return }

        isCancellationRequested = true
        statusMessage = "Cancelling queue…"

        if let currentItemID = currentQueueItem?.id {
            updateQueueItem(id: currentItemID) { item in
                item.status = .cancelling
                item.progressText = "Cancelling…"
            }
        }

        Task {
            await runner.cancelCurrentRun()
        }
    }

    func retry(_ historyItem: ConversionHistoryItem) {
        guard !isRunning else { return }
        replaceWorkingItem(with: [historyItem.inputURL], preset: historyItem.preset)
    }

    func openOutput(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealOutput(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func addInputURLs(_ urls: [URL], preset: ConversionPreset? = nil) {
        let uniqueURLs = urls.filter { url in
            !queueItems.contains(where: { $0.inputURL == url })
        }

        guard !uniqueURLs.isEmpty else {
            statusMessage = "Those files are already in the queue."
            return
        }

        let activePreset = preset ?? selectedPreset
        let newItems = uniqueURLs.map { url in
            ConversionQueueItem(
                inputURL: url,
                outputURL: fileSelectionService.suggestedOutputURL(for: url, preset: activePreset, outputDirectory: outputDirectoryURL),
                preset: activePreset
            )
        }

        queueItems.append(contentsOf: newItems)
        selectedQueueItemID = selectedQueueItemID ?? newItems.first?.id
        statusMessage = "\(newItems.count) file\(newItems.count == 1 ? "" : "s") added to the queue."

        for item in newItems {
            inspect(itemID: item.id)
        }
    }

    private func replaceWorkingItem(with urls: [URL], preset: ConversionPreset? = nil) {
        guard let firstURL = urls.first else {
            statusMessage = "No file selected."
            return
        }

        if queueItems.contains(where: { $0.inputURL == firstURL }) {
            selectedQueueItemID = queueItems.first(where: { $0.inputURL == firstURL })?.id
            statusMessage = "\(firstURL.lastPathComponent) is already loaded."
            return
        }

        guard !isRunning else { return }

        for task in inspectionTasks.values {
            task.cancel()
        }
        inspectionTasks.removeAll()

        queueItems.removeAll { $0.status != .succeeded }
        selectedQueueItemID = nil
        addInputURLs([firstURL], preset: preset)
    }

    private func inspect(itemID: UUID) {
        guard let index = queueItems.firstIndex(where: { $0.id == itemID }) else { return }
        let inputURL = queueItems[index].inputURL

        inspectionTasks[itemID]?.cancel()
        inspectionTasks[itemID] = Task {
            do {
                let mediaInfo = try await ffprobeService.inspectMedia(at: inputURL)

                await MainActor.run {
                    guard let index = self.queueItems.firstIndex(where: { $0.id == itemID }) else { return }
                    self.queueItems[index].mediaInfo = mediaInfo
                    self.queueItems[index].errorSummary = nil
                    self.updateCompatibility(for: itemID)
                    self.inspectionTasks[itemID] = nil
                }
            } catch {
                await MainActor.run {
                    guard let index = self.queueItems.firstIndex(where: { $0.id == itemID }) else { return }
                    self.queueItems[index].status = .failed
                    self.queueItems[index].progressText = "Inspection failed"
                    self.queueItems[index].errorSummary = error.localizedDescription
                    self.inspectionTasks[itemID] = nil
                }
            }
        }
    }

    private func updateCompatibility(for itemID: UUID) {
        guard let index = queueItems.firstIndex(where: { $0.id == itemID }) else { return }
        guard let mediaInfo = queueItems[index].mediaInfo else { return }

        let result = compatibilityValidator.validate(preset: queueItems[index].preset, mediaInfo: mediaInfo)
        queueItems[index].compatibilityResult = result
        queueItems[index].status = result.isCompatible ? .ready : .incompatible
        queueItems[index].progressText = result.isCompatible ? "Ready" : result.message
        queueItems[index].errorSummary = result.isCompatible ? nil : result.message
    }

    private func updateOutputURLsForQueuedItems() {
        for index in queueItems.indices {
            guard queueItems[index].status != .succeeded else { continue }
            queueItems[index].outputURL = fileSelectionService.updatedOutputURL(
                from: queueItems[index].outputURL,
                inputURL: queueItems[index].inputURL,
                preset: queueItems[index].preset,
                outputDirectory: outputDirectoryURL
            )
        }
    }

    private func processQueue() async {
        while !isCancellationRequested {
            guard let itemID = queueItems.first(where: { $0.status == .ready })?.id else { break }
            await processItem(itemID)
        }

        await MainActor.run {
            self.isRunning = false
            self.isCancellationRequested = false
            self.statusMessage = self.queueSummary
        }
    }

    private func processItem(_ itemID: UUID) async {
        guard let index = queueItems.firstIndex(where: { $0.id == itemID }) else { return }
        let item = queueItems[index]

        guard let resolvedOutput = outputConflictResolver.resolveOutputURL(item.outputURL) else {
            updateQueueItem(id: itemID) { item in
                item.status = .cancelled
                item.progressText = "Skipped existing output"
                item.completedAt = Date()
            }
            appendHistory(for: itemID, result: .cancelled, summary: "Skipped because output selection was cancelled.")
            return
        }

        updateQueueItem(id: itemID) { item in
            item.outputURL = resolvedOutput.outputURL
            item.status = .converting
            item.progressFraction = 0
            item.progressText = "Preparing conversion"
            item.errorSummary = nil
            item.diagnosticsOutput = ""
        }

        do {
            let outputSession = try outputFileCoordinator.makeSession(for: resolvedOutput.outputURL)
            let progressParser = FFmpegProgressParser()
            let arguments = commandBuilder.arguments(
                for: item.preset,
                inputURL: item.inputURL,
                outputURL: outputSession.temporaryURL
            )

            let status = try await runner.run(arguments: arguments) { line in
                Task {
                    if let update = await progressParser.consume(line) {
                        await MainActor.run {
                            self.updateQueueItem(id: itemID) { item in
                                item.progressFraction = update.fractionComplete ?? item.progressFraction
                                item.progressText = "Processed \(update.elapsedTimeDescription)"
                            }
                        }
                    }
                }

                Task { @MainActor in
                    self.updateQueueItem(id: itemID) { item in
                        item.diagnosticsOutput.append(line)
                    }
                }

            }

            if isCancellationRequested {
                outputFileCoordinator.cleanupTemporaryFile(for: outputSession)
                updateQueueItem(id: itemID) { item in
                    item.status = .cancelled
                    item.progressFraction = nil
                    item.progressText = "Cancelled"
                    item.completedAt = Date()
                }
                appendHistory(for: itemID, result: .cancelled, summary: "Cancelled during conversion.")
                return
            }

            if status == 0 {
                try outputFileCoordinator.promoteTemporaryFile(for: outputSession)
                updateQueueItem(id: itemID) { item in
                    item.status = .succeeded
                    item.progressFraction = 1
                    item.progressText = "Finished successfully"
                    item.completedAt = Date()
                }
                appendHistory(for: itemID, result: .succeeded, summary: "Completed successfully.")
            } else {
                outputFileCoordinator.cleanupTemporaryFile(for: outputSession)
                let diagnostics = queueItems.first(where: { $0.id == itemID })?.diagnosticsOutput ?? ""
                let summary = failureSummarizer.summarize(status: status, output: diagnostics, error: nil)
                updateQueueItem(id: itemID) { item in
                    item.status = .failed
                    item.progressText = "FFmpeg exited with status \(status)"
                    item.errorSummary = summary
                    item.completedAt = Date()
                }
                appendHistory(for: itemID, result: .failed, summary: summary)
            }
        } catch {
            let diagnostics = queueItems.first(where: { $0.id == itemID })?.diagnosticsOutput ?? ""
            let summary = isCancellationRequested
                ? "Cancelled during conversion."
                : failureSummarizer.summarize(status: nil, output: diagnostics, error: error)

            updateQueueItem(id: itemID) { item in
                item.status = self.isCancellationRequested ? .cancelled : .failed
                item.progressFraction = nil
                item.progressText = self.isCancellationRequested ? "Cancelled" : "Conversion failed"
                item.errorSummary = self.isCancellationRequested ? nil : summary
                item.completedAt = Date()
            }

            appendHistory(for: itemID, result: isCancellationRequested ? .cancelled : .failed, summary: summary)
        }
    }

    private func appendHistory(for itemID: UUID, result: ConversionHistoryItem.Result, summary: String) {
        guard let item = queueItems.first(where: { $0.id == itemID }) else { return }

        recentConversions.insert(
            ConversionHistoryItem(
                id: UUID(),
                inputURL: item.inputURL,
                outputURL: result == .succeeded ? item.outputURL : nil,
                preset: item.preset,
                result: result,
                summary: summary,
                completedAt: item.completedAt ?? Date()
            ),
            at: 0
        )

        if recentConversions.count > 12 {
            recentConversions.removeLast(recentConversions.count - 12)
        }
    }

    private func updateQueueItem(id: UUID, mutation: (inout ConversionQueueItem) -> Void) {
        guard let index = queueItems.firstIndex(where: { $0.id == id }) else { return }
        mutation(&queueItems[index])
    }
}
