//
//  Utils.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/26/21.
//

import Foundation

struct RuntimeError: Error {
    let message: String

    init( _ message: String ) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}
