//
//  ContentView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Kits", systemImage: "target"){
                KitsListView()
            }
            Tab("Calendario", systemImage: "calendar.badge.clock"){
                CalendarPlusView()
            }
            Tab("Asistente", systemImage: "sparkles"){
                TrainerView()
            }
            Tab("Perfil", systemImage: "person.circle"){
                ProfileView()
            }
            Tab(role: .search){
                SearchView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
