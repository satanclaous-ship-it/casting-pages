import SwiftUI

struct IdeasView: View {
    @Environment(Store.self) private var store
    @State private var filter: IdeaStatus = .inbox
    @State private var query = ""
    @State private var showCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                FlowLayout {
                    ForEach(IdeaStatus.allCases) { s in
                        let n = store.ideas.filter { $0.status == s }.count
                        Button {
                            filter = s
                        } label: {
                            Text("\(s.title) \(n)")
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(filter == s ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground),
                                            in: Capsule())
                                .overlay(Capsule().strokeBorder(filter == s ? Color.accentColor : .clear, lineWidth: 1))
                                .foregroundStyle(filter == s ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if filtered.isEmpty {
                    Card {
                        VStack(spacing: 6) {
                            Text("\(filter.title)에 아직 없어요.")
                            if !filter.blurb.isEmpty {
                                Text(filter.blurb).foregroundStyle(.tertiary)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                } else {
                    ForEach(filtered) { idea in
                        IdeaCard(idea: idea)
                    }
                }
            }
            .cardStack()
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, prompt: "아이디어 검색")
        .navigationTitle("아이디어")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCapture = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCapture) { CaptureSheet() }
    }

    private var filtered: [Idea] {
        store.ideas.filter { $0.status == filter }
            .filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
    }
}

struct IdeaCard: View {
    @Environment(Store.self) private var store
    let idea: Idea

    var body: some View {
        Card {
            Text(idea.text).font(.system(size: 14))
            Text("\(Fmt.pretty(idea.day)) \(Fmt.hhmm(idea.slot))\(idea.fromPing ? " · 알람 중" : "")")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            FlowLayout(spacing: 6) {
                ForEach(IdeaStatus.allCases.filter { $0 != idea.status }) { s in
                    Button(s.title) { store.setIdeaStatus(idea.id, s) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.system(size: 12))
                }
                Button("삭제", role: .destructive) { store.deleteIdea(idea.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 12))
            }
        }
    }
}

/// Reachable any time — from the tab, from the notification's text field, and
/// from the Shortcuts/Siri intent. Ideas don't wait for the alarm.
struct CaptureSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var dictation = Dictation()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("알람이 안 울려도 언제든 여기에…", text: $text, axis: .vertical)
                    .lineLimit(5...12)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)

                MicButton(dictation: dictation, large: true, seed: { text }) { text = $0 }

                if let err = dictation.errorMessage {
                    Text(err).font(.system(size: 12)).foregroundStyle(.orange)
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle("지금 떠오른 것")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dictation.stop(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("담기") {
                        dictation.stop()
                        store.addIdea(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
