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


func switchToDirectory( containing filename: String ) throws -> Void {
    let fileManager = FileManager.default
    var directory = URL( fileURLWithPath: #file ).deletingLastPathComponent()

    while directory != URL( fileURLWithPath: "/" ) {
        let file = directory.appendingPathComponent( filename ).path
        if fileManager.isReadableFile( atPath: file ) {
            fileManager.changeCurrentDirectoryPath( directory.path )
            return
        }
        
        directory = directory.deletingLastPathComponent()
    }

    throw RuntimeError( "Can't find directory containing \(binFileName)!" )
}
