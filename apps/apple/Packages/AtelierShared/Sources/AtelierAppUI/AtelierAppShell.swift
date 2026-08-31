import AtelierCore
import AtelierDesign
import AtelierEditor
import SwiftUI

@MainActor
public struct AtelierAppShell: View {
    @State private var model: WorkspaceModel

    public init(product: AppProduct) {
        _model = State(initialValue: WorkspaceModel(product: product))
    }

    public var body: some View {
        AtelierWorkspaceView(model: model)
            .tint(AtelierPalette.accent(for: model.product))
    }
}

@MainActor
private struct AtelierWorkspaceView: View {
    @Bindable private var model: WorkspaceModel

    init(model: WorkspaceModel) {
        self.model = model
    }

    var body: some View {
        NavigationSplitView {
            ProductSidebar(model: model)
        } content: {
            ItemList(model: model)
        } detail: {
            WorkspaceDetail(model: model)
        }
        .navigationSplitViewStyle(.balanced)
        .task(id: model.selectedSectionID) {
            await model.loadSelectedSection()
        }
    }
}

@MainActor
private struct ProductSidebar: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        List(selection: $model.selectedSectionID) {
            ForEach(model.product.sections) { section in
                NavigationLink(value: section.id) {
                    Label(section.title, systemImage: section.systemImage)
                }
                .tag(section.id)
                .accessibilityHint(Text("Show this section", bundle: .module))
            }
        }
        .navigationTitle(model.product.displayName)
        .safeAreaInset(edge: .bottom) {
            OfflineStatusBadge(status: model.offlineStatus)
                .padding()
        }
    }
}

@MainActor
private struct ItemList: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        List(selection: $model.selectedItemID) {
            ForEach(model.items) { item in
                NavigationLink(value: item.id) {
                    WorkspaceItemRow(item: item)
                }
                .tag(item.id)
            }
        }
        .overlay {
            if model.isLoading {
                ProgressView()
                    .accessibilityLabel(Text("Loading local items", bundle: .module))
            } else if model.items.isEmpty {
                ContentUnavailableView(
                    "No Local Items",
                    systemImage: "tray",
                    description: Text("Create a local draft to begin.", bundle: .module)
                )
            }
        }
        .navigationTitle(model.product.sections.first(where: { $0.id == model.selectedSectionID })?.title ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.createLocalDraft() }
                } label: {
                    Label {
                        Text("New local draft", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .accessibilityHint(Text("Creates a draft for this preview session.", bundle: .module))
            }
        }
    }
}

private struct WorkspaceItemRow: View {
    let item: WorkspaceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            Text(item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(item.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct WorkspaceDetail: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        if let item = model.selectedItem {
            VStack(spacing: 0) {
                PublicPDSDisclosure()
                    .padding()
                Divider()
                NativeMarkdownEditor(model: model.editor)
            }
            .navigationTitle(item.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.saveEditorDraftLocally() }
                    } label: {
                        Text("Save locally", bundle: .module)
                    }
                    .disabled(!model.editor.isDirty)
                    .accessibilityHint(Text("Saves this draft for this preview session without publishing it.", bundle: .module))
                }
            }
        } else {
            ContentUnavailableView(
                "Select an Item",
                systemImage: model.product.systemImage,
                description: Text("Choose a local item or create a draft.", bundle: .module)
            )
        }
    }
}

private struct PublicPDSDisclosure: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "globe.americas.fill")
                .foregroundStyle(AtelierPalette.coral)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard PDS records are public", bundle: .module)
                    .font(.headline)
                Text(
                    "Anything you publish to an AT Protocol repository can be read and mirrored. This foundation currently saves only to a named local mock repository.",
                    bundle: .module
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .atelierCard()
    }
}

private struct OfflineStatusBadge: View {
    let status: OfflineStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .accessibilityHidden(true)
            Text(statusLabel, bundle: .module)
                .font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatusLabel)
    }

    private var statusLabel: LocalizedStringKey {
        switch status.phase {
        case .localOnly: "Local only"
        case .queued: "Waiting to sync"
        case .syncing: "Syncing"
        case .durable: "Durably saved"
        case .needsAttention: "Sync needs attention"
        }
    }

    private var iconName: String {
        switch status.phase {
        case .localOnly: "internaldrive"
        case .queued: "clock"
        case .syncing: "arrow.triangle.2.circlepath"
        case .durable: "checkmark.circle"
        case .needsAttention: "exclamationmark.triangle"
        }
    }

    private var accessibilityStatusLabel: Text {
        switch status.phase {
        case .localOnly: Text("Persistence status: Local only", bundle: .module)
        case .queued: Text("Persistence status: Waiting to sync", bundle: .module)
        case .syncing: Text("Persistence status: Syncing", bundle: .module)
        case .durable: Text("Persistence status: Durably saved", bundle: .module)
        case .needsAttention: Text("Persistence status: Sync needs attention", bundle: .module)
        }
    }
}

public struct AtelierSettingsView: View {
    private let product: AppProduct

    public init(product: AppProduct) {
        self.product = product
    }

    public var body: some View {
        Form {
            Section("Native foundation") {
                LabeledContent("Application", value: product.displayName)
                LabeledContent("Bundle identifier", value: product.bundleIdentifier)
                LabeledContent("Data source", value: "Named local mock")
            }
            Section("Privacy") {
                Text("No external account or provider is connected by this foundation build.", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
