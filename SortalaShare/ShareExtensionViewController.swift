//
//  ShareExtensionViewController.swift
//  SortalaShare
//
//  Entry point for the iOS Share Extension. Receives shared text from the
//  system Share Sheet via `NSExtensionItem`, parses it through `OrderParser`,
//  and presents a SwiftUI review form embedded in a `UIHostingController`.
//
//  Lifecycle:
//    1. iOS instantiates this ViewController when user selects "Sortala"
//    2. viewDidLoad → show loading → extract text from NSItemProvider
//    3. Parse text → present ShareImportView (or error state)
//    4. User taps Simpan/Batal → completeRequest → iOS returns to host app
//
//  Memory constraint: Share Extensions are limited to ~120 MB. The
//  architecture (extract → parse → present UI) is optimised to remain
//  well within this budget.

import SwiftData
import SwiftUI
import UIKit

final class ShareExtensionViewController: UIViewController {
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        presentLoadingState()

        Task { @MainActor in
            let text = await extractSharedText()
            handleExtractedText(text)
        }
    }

    // MARK: - Text Extraction

    /// Walks the extension context's `NSItemProvider` attachments to find the
    /// first plain-text payload.
    ///
    /// Uses structured concurrency (`withCheckedContinuation`) to bridge
    /// the callback-based `NSItemProvider.loadItem` API.
    private func extractSharedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    let text: String? = await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: "public.plain-text") { data, _ in
                            let result = data as? String
                            continuation.resume(returning: result)
                        }
                    }
                    if let text, !text.isEmpty { return text }
                }
            }
        }
        return nil
    }

    // MARK: - Routing

    /// Routes to the correct UI based on extraction result.
    ///
    /// > Important: `.tint(.teal)` is NOT applied globally. Only the
    /// > checkmark (confirm) button uses `.tint(.teal)` — the cancel
    /// > button must remain system-default per HIG `.cancellationAction`
    /// > semantics.
    private func handleExtractedText(_ text: String?) {
        guard let rawText = text, !rawText.trimmingCharacters(in: .whitespaces).isEmpty else {
            presentEmptyState()
            return
        }

        let container = SharedContainerFactory.makeContainer()

        let parsed = OrderParser.shared.parse(rawText)
        let viewModel = OrderImportViewModel(parsedOrder: parsed)
        let importView = ShareImportView(viewModel: viewModel) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        .modelContainer(container)
        // NO global .tint(.teal) — individual buttons set their own tint

        replaceContent(with: importView)
    }

    // MARK: - State Views

    /// Shows a spinner while the text payload is being extracted.
    private func presentLoadingState() {
        let loading = VStack(spacing: 12) {
            ProgressView()
            Text("Memuat teks…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        replaceContent(with: loading)
    }

    /// Shows a message when no text was found in the shared content.
    private func presentEmptyState() {
        let empty = dismissableWrapper {
            ContentUnavailableView(
                "Teks Tidak Ditemukan",
                systemImage: "text.slash",
                description: Text("Bagikan teks pesan order dari WhatsApp atau Instagram.")
            )
        }
        replaceContent(with: empty)
    }

    /// Shows a message when the shared SQLite store is unavailable.
    private func presentErrorState() {
        let error = dismissableWrapper {
            ContentUnavailableView(
                "Tidak Dapat Menyimpan",
                systemImage: "exclamationmark.triangle",
                description: Text("App Group belum dikonfigurasi dengan benar.")
            )
        }
        replaceContent(with: error)
    }

    /// Wraps a view in NavigationStack with a cancel button so the user can dismiss.
    private func dismissableWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Tutup") { [weak self] in
                            self?.extensionContext?.completeRequest(
                                returningItems: [],
                                completionHandler: nil
                            )
                        }
                    }
                }
        }
    }

    // MARK: - View Embedding

    /// Replaces the current child view controller with a new SwiftUI view.
    /// Removes any previous child before embedding the new one.
    private func replaceContent<V: View>(with swiftUIView: V) {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        let hosting = UIHostingController(rootView: swiftUIView)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

}
