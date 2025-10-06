//
//  Item.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
