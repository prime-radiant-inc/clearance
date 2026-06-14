import SwiftUI

struct HelpWindowView: View {
    @ObservedObject var viewModel: HelpViewModel
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 220)
        } detail: {
            detail
                .frame(minWidth: 480, minHeight: 360)
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField("Search help", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.runSearch()
                }

            if viewModel.isSearching {
                List(viewModel.results, id: \.topic.id) { result in
                    Button {
                        viewModel.select(result.topic)
                        viewModel.searchQuery = ""
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.topic.title).font(.headline)
                            Text(result.snippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                List(
                    viewModel.topics,
                    selection: Binding(
                        get: { viewModel.currentTopic?.id },
                        set: { id in
                            if let topic = viewModel.topics.first(where: { $0.id == id }) {
                                viewModel.select(topic)
                            }
                        }
                    )
                ) { topic in
                    Text(topic.title)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let topic = viewModel.currentTopic {
            RenderedMarkdownView(
                document: topic.renderDocument,
                sourceDocumentURL: topic.fileURL,
                isRemoteContent: false,
                allowsLocalFileStaging: false,
                headingScrollRequest: nil,
                theme: appSettings.theme,
                appearance: appSettings.appearance,
                textScale: appSettings.renderedTextScale,
                onOpenLinkedDocument: { linkedURL in
                    viewModel.openLink(linkedURL)
                }
            )
        } else {
            Text("Help content is unavailable.")
                .foregroundStyle(.secondary)
        }
    }
}
