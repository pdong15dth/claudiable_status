//
//  Item.swift
//  claudiable_status
//
//  Created by Pham Dong on 28/2/26.
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
