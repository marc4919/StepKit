//
//  ContentView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var searchText: String = ""

    var body: some View {
        TabView {
            Tab("Steps", systemImage: "target"){
                GoalsListView()
            }
            Tab("Trainer", systemImage: "sparkles"){
                TrainerView()
            }
            Tab("Profile", systemImage: "person.circle"){
                StepDetailView()
            }
            Tab(role: .search){
                NavigationStack{
                    Text("Search")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Enter any search")
//        .tabViewBottomAccessory {
//            HStack(spacing: 10) {
//                HStack(spacing: 8) {
//                    Image(systemName: "message.fill")
//                        .foregroundStyle(.secondary)
//                    TextField("Escribe un mensaje…", text: $searchText, axis: .vertical)
//                        .textFieldStyle(.plain)
//                        .font(.body)
//                        .lineLimit(1...4)
//                        .submitLabel(.send)
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
//
//                Button(action: {
//                    print("Enviar: \(searchText)")
//                }) {
//                    Image(systemName: "paperplane.fill")
//                        .font(.system(size: 17, weight: .semibold))
//                }
//                .buttonStyle(.borderedProminent)
//                .controlSize(.large)
//                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//            .background(
//                .ultraThinMaterial
//                    .shadow(.drop(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2))
//            )
//        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

private struct SearchView: View {
    let items: [Item]
    @Binding var searchText: String

    // Filtrado simple por texto en la fecha formateada
    private var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return items.filter { item in
            formatter.string(from: item.timestamp)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if filteredItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredItems) { item in
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar por fecha")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
