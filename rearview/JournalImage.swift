//
//  JournalImage.swift
//  rearview
//
//  Created by Matthew Susko on 2025-09-26.
//

import SwiftUI

struct JournalImage: Identifiable, Hashable {
    let id: String
    var url: String?
    var image: UIImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: JournalImage, rhs: JournalImage) -> Bool {
        lhs.id == rhs.id
    }
}
