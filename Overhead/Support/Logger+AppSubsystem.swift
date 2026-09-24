//
//  Logger+AppSubsystem.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 15/07/26.
//

import os

extension Logger {
    static let appSubsystem = "com.mazzsva.Overhead"

    init(category: String) {
        self.init(subsystem: Self.appSubsystem, category: category)
    }
}
