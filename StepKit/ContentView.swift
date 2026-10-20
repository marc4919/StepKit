//
//  ContentView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.syncManager) private var syncManager

    var body: some View {
        TabView {
            Tab("Kits", systemImage: Symbols.kits){
                KitsListView()
            }
            Tab("Calendario", systemImage: Symbols.calendar){
                CalendarPlusView()
            }
            Tab("Asistente", systemImage: Symbols.assistant){
                TrainerView()
            }
            Tab("Perfil", systemImage: Symbols.profile){
                ProfileView()
            }
            Tab(role: .search){
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if DEBUG
        .overlay(alignment: .topLeading) {
            Text("Estado E2E")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("e2e.appState")
                .accessibilityLabel("Estado E2E")
                .accessibilityValue(e2eStateValue)
                .allowsHitTesting(false)
        }
        #endif
    }

    #if DEBUG
    private var e2eStateValue: String {
        let ownerID = authManager.currentUser?.id ?? "none"
        let syncState = syncManager?.isSyncing == true ? "syncing" : "idle"
        let cursor = syncManager?.lastSyncDate.map {
            String(format: "%.6f", $0.timeIntervalSince1970)
        } ?? "never"
        let completedSyncs = syncManager?.completedSyncCount ?? 0
        return "owner=\(ownerID);sync=\(syncState);cursor=\(cursor);completed=\(completedSyncs)"
    }
    #endif
}

#Preview {
    ContentView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
