import SwiftUI

/// One category's Settings sections; never filters by visibility, so hidden rows stay listed.
struct LauncherItemsSection: View {
    let kind: AppEntry.Kind
    let header: String
    let searchPrompt: String

    @Environment(AppIndex.self) private var appIndex
    @Environment(VisibilityStore.self) private var visibility
    @State private var query = ""

    private var entries: [AppEntry] {
        // Run the matcher once per render, then scope the results to this category.
        let matched = query.isEmpty ? appIndex.apps : appIndex.matches(query)
        return matched.filter { $0.kind == kind }
    }

    var body: some View {
        Section {
            Toggle(isOn: kindBinding) {
                Text("Show in launcher")
                Text("Uncheck an item below to hide just that one.")
            }
        } header: {
            Text(header)
        }

        Section {
            SettingsFilterField(prompt: searchPrompt, query: $query)

            if entries.isEmpty {
                Text(query.isEmpty ? "Nothing here yet." : "No matches for “\(query)”.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // One row holding a lazy stack: a `Form` realizes every row it is handed.
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        if entry.id != entries.first?.id { Divider() }
                        LauncherItemRow(entry: entry)
                            .padding(.vertical, Self.rowPadding)
                    }
                }
                .padding(.vertical, -Self.rowPadding)
            }
        }
        // Rows dim while the category is off but stay interactive, so one can still be re-hidden.
        .opacity(visibility.isKindVisible(kind) ? 1 : 0.45)
    }

    /// A grouped `Form` row's own vertical padding.
    private static let rowPadding: CGFloat = 15

    private var kindBinding: Binding<Bool> {
        Binding(
            get: { visibility.isKindVisible(kind) },
            set: { visibility.setKindVisible($0, for: kind) }
        )
    }
}

private struct LauncherItemRow: View {
    let entry: AppEntry
    @Environment(VisibilityStore.self) private var visibility

    var body: some View {
        SettingsRow(title: entry.name) {
            AppIconView(app: entry).frame(width: 18, height: 18)
        } trailing: {
            AliasField(entry: entry)
            if let action = entry.hotKeyAction {
                ShortcutRecorder(action: action)
            }
            Toggle("", isOn: itemBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityLabel("Show \(entry.name) in launcher")
        }
    }

    private var itemBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(entry) },
            set: { visibility.setItemVisible($0, for: entry) }
        )
    }
}

/// Edits stay local until commit: writing per keystroke would re-rank the list under the cursor.
private struct AliasField: View {
    let entry: AppEntry
    @Environment(AliasStore.self) private var aliases
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Alias", text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
            .focused($focused)
            .onSubmit { aliases.setAlias(text, for: entry) }
            .onChange(of: focused) { _, nowFocused in
                if !nowFocused { aliases.setAlias(text, for: entry) }
            }
            .onChange(of: aliases.alias(for: entry), initial: true) { _, stored in
                if !focused { text = stored }
            }
            .accessibilityLabel("Alias for \(entry.name)")
    }
}
