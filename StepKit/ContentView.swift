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
                FastCreatorView()
            }
            Tab("Trainer", systemImage: "sparkles"){
                
            }
            Tab("Profile", systemImage: "person.circle"){
                Text("Documents")
            }
            Tab(role: .search){
                NavigationStack{
                    Text("Search")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Enter any search"
                        )
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
