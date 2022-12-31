//
//  SudokuAIApp.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//

import SwiftUI
import Vision

@main
struct SudokuAIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
