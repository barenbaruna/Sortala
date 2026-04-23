//
//  ShareExtensionViewController.swift
//  SortalaShare
//
//  Entry point for the Share Extension. Receives shared text from the iOS
//  Share Sheet via `NSExtensionItem`, parses it through `OrderParser`, and
//  presents a SwiftUI review form embedded in a `UIHostingController`.
//
//  Lifecycle:
//    1. iOS instantiates this ViewController when user selects "Sortala" in Share Sheet
//    2. viewDidLoad → show loading → extract text from NSItemProvider
//    3. Parse text → present ShareImportView (or error state)
//    4. User taps Simpan/Batal → completeRequest → iOS returns to host app

import SwiftData
import SwiftUI
import UIKit

final class ShareExtensionViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        presentLoadingState()

        extractSharedText { [weak self] text in
            DispatchQueue.main.async {
                self?.handleExtractedText(text)
            }
        }
    }

    // MARK: - Text Extraction

    /// Walks the extension context's `NSItemProvider` attachments to find the
    /// first plain-text payload. Calls `completion` with the result.
    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text") { data, _ in
                        let text = (data as? String) ?? ""
                        completion(text.isEmpty ? nil : text)
                    }
                    return
                }
            }
        }
        completion(nil)
    }

    // MARK: - Routing

    /// Routes to the correct UI based on extraction result.
    private func handleExtractedText(_ text: String?) {
        guard let rawText = text, !rawText.trimmingCharacters(in: .whitespaces).isEmpty else {
            presentEmptyState()
            return
        }

        guard let container = makeSharedContainer() else {
            presentErrorState()
            return
        }

        let parsed    = OrderParser.shared.parse(rawText)
        let viewModel = OrderImportViewModel(parsedOrder: parsed)
        let importView = ShareImportView(viewModel: viewModel) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        .modelContainer(container)

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
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
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

    // MARK: - Shared Container

    /// Builds a `ModelContainer` pointing to the App Group SQLite store.
    /// Returns `nil` (non-fatal) if the group container is unavailable.
    private func makeSharedContainer() -> ModelContainer? {
        let groupID = "group.com.barenbaruna.Sortala"
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else { return nil }

        let storeURL = groupURL.appendingPathComponent("Sortala.sqlite")
        let schema   = Schema([Order.self, OrderItem.self])
        do {
            let config = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            return nil
        }
    }
}
