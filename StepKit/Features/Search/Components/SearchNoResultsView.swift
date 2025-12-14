//
//  SearchNoResultsView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct SearchNoResultsView: View {
    let searchText: String
    
    var body: some View {
        ContentUnavailableView.search(text: searchText)
    }
}
