//
//  Item.swift
//  Card
//
//  Created by Ankur Yadav on 12/05/25.
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
