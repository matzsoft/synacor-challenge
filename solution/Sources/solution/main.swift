//
//  main.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/26/21.
//

import  Foundation

let binFileName = "challenge.bin"

try switchToDirectory( containing: binFileName )

var game = try Game( from: URL( fileURLWithPath: binFileName ) )

try game.interactive()
