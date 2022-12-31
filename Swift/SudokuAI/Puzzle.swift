//
//  Puzzle.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//

import SwiftUI
import Foundation

struct PuzzleCell: View {
    @ObservedObject var item: Item
    var body: some View {
          NavigationLink(destination: PuzzleDetail(item: item, timestamp: item.timestamp ?? Date(), image: item.image)) {
            VStack {
                Text(item.name ?? "Untitled Puzzle")
                    .font(.title)
                Grid(grid: $item.currentGrid, currentValues: $item.currentValues, item: item, canEdit: false)
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .body)
                    .scaledToFill()
                    .allowsHitTesting(false) // Necessary to prevent GridCell from absorbing onTapGesture.
                Text(item.timestamp ?? Date(), formatter: itemFormatter)
                    .font(.subheadline)
            }
        }
    }
}

struct PuzzleDetail: View {
    @State private var showImage = true
    @State private var showPlayButton = true
    @State private var resetButtonDisabled = true
    @State private var playButtonDisabled = false
    @State private var hintButtonDisabled = false
    @State private var solveButtonDisabled = false
    @State private var isShowNameEdit = false
    @State private var editIcon = "pencil.circle"
    @FocusState private var nameFieldIsFocused: Bool

    @ObservedObject var item: Item
    var timestamp: Date
    var image: Data?
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    if (self.isShowNameEdit) {
                        TextField("Untitled Puzzle", text: Binding($item.name)!)
                            .focused($nameFieldIsFocused)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .disableAutocorrection(true)
                            .font(.title)
                            .onSubmit {
                                self.isShowNameEdit = self.isShowNameEdit ? false : true
                                self.nameFieldIsFocused = self.isShowNameEdit ? true : false
                                editIcon = self.isShowNameEdit ? "pencil.circle.fill" : "pencil.circle"

                                if (self.isShowNameEdit == false) {
                                    do {
                                        try PersistenceController.shared.container.viewContext.save()
                                    } catch {
                                        let nsError = error as NSError
                                        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                                    }
                                }
                            }
                    }
                    else {
                        Text(item.name ?? "Untitled Puzzle")
                            .font(.title)
                    }
                    Image(systemName: editIcon)
                        .onTapGesture {
                            self.isShowNameEdit = self.isShowNameEdit ? false : true
                            self.nameFieldIsFocused = self.isShowNameEdit ? true : false
                            editIcon = self.isShowNameEdit ? "pencil.circle.fill" : "pencil.circle"

                            if (self.isShowNameEdit == false) {
                                do {
                                    try PersistenceController.shared.container.viewContext.save()
                                } catch {
                                    let nsError = error as NSError
                                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                                }
                            }
                        }
                }
                Text(item.timestamp ?? Date(), formatter: itemFormatter)
                    .font(.subheadline)
                Divider()
                ZStack {
                    if showImage && image != nil {
                        Image(uiImage: UIImage(data: image!)!)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(contentMode: .fit)
                            .opacity(0.4)
                    }
                    Grid(grid: $item.currentGrid, currentValues: $item.currentValues, item: item, canEdit: resetButtonDisabled)
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .body)
                        .scaledToFill()
                }
                if (resetButtonDisabled) {
                    Text("Tap to Change Numbers")
                        .italic()
                        .font(.system(size: 14))
                    HStack {
                        Image(systemName: (item.finalGrid != "") ? "checkmark.circle" : "x.circle")
                        Text((item.finalGrid != "") ? "Ready to Solve" : "No Solution")
                            .italic()
                            .font(.system(size: 14))
                    }
                }
                else {
                    HStack {
                        Text("Original squares in black")
                            .italic()
                            .font(.system(size: 14))
                            .foregroundColor(Color.black)
                        Text("Solved squares in blue")
                            .italic()
                            .font(.system(size: 14))
                            .foregroundColor(Color.blue)
                    }
                    if (item.isPlaying) {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("Eliminate. Assign. Search. Repeat.")
                                .italic()
                                .font(.system(size: 14))
                        }
                    }
                    else {
                        HStack {
                            Image(systemName: "puzzlepiece.extension")
                            Text("\(item.solutionSquares!.count - item.currentSolutionSquaresIndex) hints left")
                                .italic()
                                .font(.system(size: 14))
                        }
                    }
                }
                HStack {
                    // Reset Button
                    Button(action: {
                        withAnimation {
                            // Toggle image.
                            showImage = true
                            showPlayButton = true
                            resetButtonDisabled = true
                            playButtonDisabled = false
                            hintButtonDisabled = false
                            solveButtonDisabled = false
                            item.isPlaying = false
                            item.isPaused = false
                            item.currentGrid = item.grid
                            item.currentSolutionSquaresIndex = 0
                        }
                    }) {
                        VStack {
                            Image(systemName: "backward.end.fill")
                            Text("Reset")
                        }
                        .font(.system(size: 16))
                        .padding()
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 160 : 80)
                        .foregroundColor(Color.white)
                        .background(resetButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(15.0)
                    }
                    .disabled(resetButtonDisabled)

                    // Play Button
                    Button(action: {
                        withAnimation {
                            resetButtonDisabled = false
                            hintButtonDisabled = true
                            solveButtonDisabled = true
                            // Toggle image.
                            showImage = false
                            if (!item.isPlaying) {
                                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 0.1) {
                                    item.isPlaying = true
                                    item.solveGrid()
                                    item.isPlaying = false

                                    if (resetButtonDisabled == true) {
                                        // User reset during play.
                                        showImage = true
                                        showPlayButton = true
                                        resetButtonDisabled = true
                                        playButtonDisabled = false
                                        hintButtonDisabled = false
                                        solveButtonDisabled = false
                                        item.isPlaying = false
                                        item.isPaused = false
                                        item.currentGrid = item.grid
                                        item.currentSolutionSquaresIndex = 0
                                    }
                                    else {
                                        // Play completed.
                                        playButtonDisabled = true
                                        showPlayButton = true
                                        item.currentSolutionSquaresIndex = item.solutionSquares!.count
                                        item.currentGrid = item.finalGrid
                                    }
                                }
                            }
                            else {
                                item.isPaused = !item.isPaused
                            }
                            showPlayButton = item.isPaused
                        }
                    }) {
                        VStack {
                            Image(systemName: showPlayButton ? "play.fill" : "pause.fill")
                            Text(showPlayButton ? "Play" : "Pause")
                        }
                        .font(.system(size: 16))
                        .padding()
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 160 : 80)
                        .foregroundColor(Color.white)
                        .background(playButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(15.0)
                    }
                    .disabled(playButtonDisabled)

                    // Hint Button
                    Button(action: {
                        withAnimation {
                            resetButtonDisabled = false
                            playButtonDisabled = true
                            // Toggle image.
                            showImage = false
                            item.currentGrid = item.currentGridPlusNextSquare()
                            hintButtonDisabled = item.solutionSquares!.count - item.currentSolutionSquaresIndex == 0
                            if (item.currentGrid == item.finalGrid) {
                                playButtonDisabled = true
                                hintButtonDisabled = true
                                solveButtonDisabled = true
                            }
                        }
                    }) {
                        VStack {
                            Image(systemName: "forward.frame.fill")
                            Text("Hint")
                        }
                        .font(.system(size: 16))
                        .padding()
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 160 : 80)
                        .foregroundColor(Color.white)
                        .background(hintButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(15.0)
                    }
                    .disabled(hintButtonDisabled)

                    // Solve Button
                    Button(action: {
                        withAnimation {
                            // Toggle image.
                            showImage = false
                            resetButtonDisabled = false
                            playButtonDisabled = true
                            hintButtonDisabled = true
                            solveButtonDisabled = true
                            item.currentSolutionSquaresIndex = item.solutionSquares!.count
                            item.currentGrid = item.finalGrid
                        }
                    }) {
                        VStack {
                            Image(systemName: "forward.end.fill")
                            Text("Solve")
                        }
                        .font(.system(size: 16))
                        .padding()
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 160 : 80)
                        .foregroundColor(Color.white)
                        .background(solveButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(15.0)
                    }
                    .disabled(solveButtonDisabled)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            resetButtonDisabled = true
            playButtonDisabled = item.finalGrid == ""
            hintButtonDisabled = item.finalGrid == ""
            solveButtonDisabled = item.finalGrid == ""
        }
        .onDisappear() {
            item.isPlaying = false
            item.isPaused = false
            item.currentGrid = item.grid
            item.currentSolutionSquaresIndex = 0
        }
    }
}

// Grid

struct Grid: View {
    @Binding var grid: String?
    @Binding var currentValues: [String:String]
    var item: Item
    var canEdit: Bool
    var body: some View {
        VStack(spacing: 0) {
            let gridArray = Array(grid ?? "")
            let rows = stride(from: 0, to: gridArray.count, by: 9).map {
                Array(gridArray[$0..<min($0 + 9, gridArray.count)])
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, column in
                        GridCell(square: item.squareInGrid(row:rowIndex, column: columnIndex), number: String(column), rowIndex: rowIndex, columnIndex: columnIndex, currentValues: $currentValues, item: item, canEdit: canEdit)
                    }
                }
            }
        }
    }
}

struct GridCell: View {
    var square: String
    var number: String
    var rowIndex: Int
    var columnIndex: Int
    @Binding var currentValues: [String:String]
    var item: Item
    var canEdit: Bool
    var body: some View {
        GeometryReader { geometry in
            // guard let currentValues = item.currentValues
            if (!item.currentValues.isEmpty && item.currentValues[square]!.count > 1) {
                // Display 9 values.
                // DEBUG: let x = print("PLAY MULTI: \(square): \(item.currentValues[square]!.count)")
                GridCellMulti(values: item.currentValues[square]!, item: item)
                    .foregroundColor(item.gridState(row: rowIndex, column: columnIndex) ? Color.blue : Color.black)
                    .frame(width: geometry.size.width, height: geometry.size.width, alignment: .center)
                    .background(Rectangle().stroke())
                    // Left
                    .overlay(Rectangle().frame(width: columnIndex == 0 ? 2 : 0, height: nil, alignment: .leading).foregroundColor(Color.black), alignment: .leading)
                    // Right
                    .overlay(Rectangle().frame(width: columnIndex == 8 ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
                    // Top
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 0 ? 2 : 0, alignment: .top).foregroundColor(Color.black), alignment: .top)
                    // Bottom
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 8 ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Rows
                    .overlay(Rectangle().frame(width: nil, height: (rowIndex == 2 || rowIndex == 5) ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Columns
                    .overlay(Rectangle().frame(width: (columnIndex == 2 || columnIndex == 5) ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
            }
            else if (!item.currentValues.isEmpty && item.currentValues[square]!.count == 1) {
                // Display one large number.
                // DEBUG: let x = print("PLAY SINGLE: \(square): \(item.currentValues[square]!)")
                Text(item.currentValues[square]!)
                    .foregroundColor(item.gridState(row: rowIndex, column: columnIndex) ? Color.blue : Color.black)
                    .frame(width: geometry.size.width, height: geometry.size.width, alignment: .center)
                    .background(Rectangle().stroke())
                    // Left
                    .overlay(Rectangle().frame(width: columnIndex == 0 ? 2 : 0, height: nil, alignment: .leading).foregroundColor(Color.black), alignment: .leading)
                    // Right
                    .overlay(Rectangle().frame(width: columnIndex == 8 ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
                    // Top
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 0 ? 2 : 0, alignment: .top).foregroundColor(Color.black), alignment: .top)
                    // Bottom
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 8 ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Rows
                    .overlay(Rectangle().frame(width: nil, height: (rowIndex == 2 || rowIndex == 5) ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Columns
                    .overlay(Rectangle().frame(width: (columnIndex == 2 || columnIndex == 5) ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
            }
            else {
                Text(number == "." ? " " : number)
                    .foregroundColor(item.gridState(row: rowIndex, column: columnIndex) ? Color.blue : Color.black)
                    .frame(width: geometry.size.width, height: geometry.size.width, alignment: .center)
                    .background(Rectangle().stroke())
                    // Left
                    .overlay(Rectangle().frame(width: columnIndex == 0 ? 2 : 0, height: nil, alignment: .leading).foregroundColor(Color.black), alignment: .leading)
                    // Right
                    .overlay(Rectangle().frame(width: columnIndex == 8 ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
                    // Top
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 0 ? 2 : 0, alignment: .top).foregroundColor(Color.black), alignment: .top)
                    // Bottom
                    .overlay(Rectangle().frame(width: nil, height: rowIndex == 8 ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Rows
                    .overlay(Rectangle().frame(width: nil, height: (rowIndex == 2 || rowIndex == 5) ? 2 : 0, alignment: .bottom).foregroundColor(Color.black), alignment: .bottom)
                    // Middle Columns
                    .overlay(Rectangle().frame(width: (columnIndex == 2 || columnIndex == 5) ? 2 : 0, height: nil, alignment: .trailing).foregroundColor(Color.black), alignment: .trailing)
                    .onTapGesture {
                        if (canEdit) {
                            // Increment that square and save.
                            item.increment(row: rowIndex, column: columnIndex)
                            item.solveGrid()
                            
                            do {
                                try PersistenceController.shared.container.viewContext.save()
                            } catch {
                                let nsError = error as NSError
                                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                            }
                        }
                    }
            }
        }
    }
}

struct GridCellMulti: View {
    var values: String
    var item: Item
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                let valuesArray = item.arrayWithDotsToGridCellValues(values: values)
                let rows = stride(from: 0, to: valuesArray.count, by: 3).map {
                    Array(valuesArray[$0..<min($0 + 3, valuesArray.count)])
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, column in
                            Text(String(column) == "." ? "•" : String(column))
                                .frame(width: geometry.size.width / 3, height: geometry.size.width / 3, alignment: .center)
                                .foregroundColor(String(column) == "." ? Color.red : Color.gray)
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                        }
                    }
                }
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()
