//
//  SearchView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//
//  Buscar v4.4: Kits, pasos y notas del registro en una lista del sistema.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var entries: [ProgressEntryEntity]

    @State private var searchText = ""
    /// Lupa como botón (HIG): al tocarla, el campo recibe el foco y sale el teclado.
    @FocusState private var isSearchFocused: Bool
    @State private var isSearching = false
    /// Al cerrar la búsqueda sin texto se vuelve a la pestaña anterior.
    var onDismiss: () -> Void = {}
    @State private var navigationPath = NavigationPath()

    private var ownerID: String? { authManager.currentUser?.id }

    private var kits: [GoalEntity] {
        guard let ownerID else { return [] }
        return goalEntities.filter { $0.ownerID == ownerID }
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ text: String) -> Bool {
        text.localizedStandardContains(query)
    }

    private var matchingKits: [GoalEntity] {
        kits.filter { matches($0.title) || matches($0.kpi) }
    }

    private var matchingSteps: [StepEntity] {
        kits.flatMap(\.orderedActiveSteps).filter { matches($0.stepTitle) || matches($0.descriptionShort) }
    }

    private var matchingEntries: [ProgressEntryEntity] {
        let kitIDs = Set(kits.map(\.id))
        return entries.filter {
            $0.deletedAt == nil && $0.ownerID == ownerID && kitIDs.contains($0.kitID) && matches($0.note)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if query.isEmpty {
                    ContentUnavailableView {
                        Label { Text("Encuentra tus Kits y pasos") } icon: {
                            IconChip(symbol: "magnifyingglass", color: .accentColor, size: 90)
                        }
                    } description: {
                        Text("Busca por nombre de Kit, paso o nota.")
                    }
                    .background(alignment: .top) { BrandGlow() }
                } else if matchingKits.isEmpty && matchingSteps.isEmpty && matchingEntries.isEmpty {
                    ContentUnavailableView {
                        Label { Text("No encontramos coincidencias") } icon: {
                            IconChip(symbol: "magnifyingglass", color: .accentColor, size: 90)
                        }
                    } description: {
                        Text("Prueba con otro nombre de Kit, paso o nota.")
                    } actions: {
                        Button("Limpiar búsqueda") { searchText = "" }
                    }
                } else {
                    results
                }
            }
            .navigationTitle("Buscar")
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Kits, pasos y notas")
            .searchFocused($isSearchFocused)
            .task { isSearchFocused = true }
            .onChange(of: isSearching) { _, searching in
                if !searching && query.isEmpty && navigationPath.isEmpty { onDismiss() }
            }
            .navigationDestination(for: GoalNavigation.self) { nav in
                if let kit = kits.first(where: { $0.id == nav.id }) {
                    KitDetailView(kitEntity: kit)
                }
            }
            .navigationDestination(for: StepNavigation.self) { nav in
                if let step = kits.flatMap(\.steps).first(where: { $0.id == nav.id }) {
                    StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
                }
            }
        }
    }

    private var results: some View {
        List {
            if !matchingKits.isEmpty {
                Section("Kits") {
                    ForEach(matchingKits) { kit in
                        NavigationLink(value: GoalNavigation(id: kit.id)) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(kit.title).font(.headline)
                                    if !kit.kpi.isEmpty {
                                        Text(kit.kpi).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                            } icon: {
                                ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount,
                                             size: 34, showsLabel: false)
                            }
                        }
                    }
                }
            }
            if !matchingSteps.isEmpty {
                Section("Pasos") {
                    ForEach(matchingSteps) { step in
                        NavigationLink(value: StepNavigation(id: step.id)) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(step.stepTitle).font(.headline)
                                    Text("\(step.goal?.title ?? "") · \(step.estimateMinutes) min")
                                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                }
                            } icon: {
                                IconChip(symbol: step.isCompleted ? "checkmark.circle.fill" : "circle",
                                         color: step.isCompleted ? MetaTint.done : .accentColor, size: 32)
                            }
                        }
                    }
                }
            }
            if !matchingEntries.isEmpty {
                Section("Registro") {
                    ForEach(matchingEntries) { entry in
                        let kit = kits.first { $0.id == entry.kitID }
                        let step = kit?.orderedActiveSteps.first { $0.id == entry.stepID }
                        NavigationLink(value: step.map { AnyHashable(StepNavigation(id: $0.id)) }
                                        ?? AnyHashable(GoalNavigation(id: entry.kitID))) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(entry.note).font(.headline).lineLimit(2)
                                    Text([kit?.title, step.map { "Paso \(kit?.position(of: $0) ?? 1)" },
                                          entry.notedAt.formatted(.dateTime.day().month(.abbreviated))]
                                            .compactMap { $0 }.joined(separator: " · "))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                IconChip(symbol: entry.kind == .blocked ? Symbols.blocked : Symbols.note,
                                         color: entry.kind == .blocked ? .red : .orange, size: 32)
                            }
                        }
                    }
                }
            }
        }
    }
}
