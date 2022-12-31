//
//  Help.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//

import SwiftUI
import Foundation

struct HelpScreen: Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var image: String = ""
}

extension HelpScreen {
    static var sample: [HelpScreen] {
        [
            HelpScreen(
                title: "SudokuAI",
                text: "Use SudokuAI to help solve any Sudoku puzzle with instant solutions, hints, and autoplay.",
                image: "Help - Intro"
            ),
            HelpScreen(
                title: "Get Started",
                text: "Play with a pre-loaded puzzle, create a blank puzzle, import a picture of a puzzle, or take a photo of a puzzle.",
                image: "Help - Get Started"
            ),
            HelpScreen(
                title: "Solve Sudoku Instantly",
                text: "Tap “Solve” to see the solution instantly.",
                image: "Help - Solve Instantly"
            ),
            HelpScreen(
                title: "Tap for a Hint",
                text: "Tap “Hint” to see the next number in the solution.",
                image: "Help - Tap for a Hint"
            ),
            HelpScreen(
                title: "How to Solve Any Puzzle",
                text: "Tap “Play” to see SudokuAI solve any puzzle on autoplay.",
                image: "Help - How to Solve Every Puzzle"
            )
        ]
    }
}

struct ShowHelp: View {
    let screens = HelpScreen.sample
    @State private var selection = 0
    var body: some View {
        VStack {
            TabView(selection: $selection) {
                ForEach(screens.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        Text(screens[index].title)
                            .font(.largeTitle)
                            .padding()
                        Text(screens[index].text)
                            .foregroundColor(.secondary)
                            .padding()
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(height: 1)
                            .padding()
                        Image(screens[index].image)
                            .resizable()
                            .scaledToFit()
                            .border(Color.secondary)
                    }
                    .padding()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack {
                Button {
                    withAnimation {
                        if selection <= screens.count - 1 && selection > 0 {
                            selection -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left.circle")
                        .font(.largeTitle)
                }
                .disabled(selection <= 0)

                Spacer()

                Button {
                    withAnimation {
                        if selection < screens.count - 1 && selection >= 0 {
                            selection += 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right.circle")
                        .font(.largeTitle)
                }
                .disabled(selection >= screens.count - 1)
            }
            .padding()
        }
        
    }
}
