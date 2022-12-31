//
//  ContentView.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
	
	@State private var isShowPhotoCamera = false
    @State private var isShowPhotoLibrary = false
    @State private var isShowHelp = false
	@State private var image = UIImage()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>

    var body: some View {
        NavigationView {
			List {
				ForEach(items) { item in
                    PuzzleCell(item: item)
                }
				.onDelete(perform: deleteItems)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("SudokuAI")
			.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        let newItem = Item(context: viewContext)
                        newItem.timestamp = Date()
                        newItem.grid = "................................................................................."
                        newItem.name = "Untitled"
                        newItem.currentGrid = newItem.grid
                        newItem.solveGrid()
                        do {
                            try viewContext.save()
                        } catch {
                            let nsError = error as NSError
                            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                        }
                    }) {
                        Label("Add Blank Puzzle", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { self.isShowPhotoCamera = true }) {
                        Label("Add Camera Image", systemImage: "camera")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { self.isShowPhotoLibrary = true }) {
                        Label("Add Photo Image", systemImage: "photo")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { loadDefaults() }) {
                        Label("Add Default Puzzles", systemImage: "text.book.closed")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { self.isShowHelp = true }) {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
			}
            Text("Select a puzzle from the navigation at the top left.")
        }
		.sheet(isPresented: $isShowPhotoCamera) {
			ImagePicker(sourceType: .camera, selectedImage: self.$image)
		}
		.sheet(isPresented: $isShowPhotoLibrary) {
			ImagePicker(sourceType: .photoLibrary, selectedImage: self.$image)
		}
        .sheet(isPresented: $isShowHelp) {
            ShowHelp()
        }
        .onAppear {
            // Load defaults on first launch.
            if UserDefaults.standard.bool(forKey: "loadDefaults") == false {
                loadDefaults()
                self.isShowHelp = true
            }
        }
        // .navigationViewStyle(StackNavigationViewStyle()) // I debated between this and default for iPad app.
    }

    private func loadDefaults() {
        // Norvig's Example: https://norvig.com/sudoku.html
        let newItem1 = Item(context: viewContext)
        newItem1.timestamp = Date()
        newItem1.grid = "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......"
        newItem1.name = "Norvig's Example"
        newItem1.currentGrid = newItem1.grid
        newItem1.solveGrid()

        // Unsolvable #28: https://www.sudokuwiki.org/Weekly_Sudoku.asp?puz=28
        let newItem2 = Item(context: viewContext)
        newItem2.timestamp = Date()
        newItem2.grid = "6....894.9....61...7..4....2..61..........2...89..2.......6...5.......3.8....16.."
        newItem2.name = "Unsolvable #28"
        newItem2.currentGrid = newItem2.grid
        newItem2.solveGrid()

        // Unsolvable #49: https://www.sudokuwiki.org/Weekly_Sudoku.asp?puz=49
        let newItem3 = Item(context: viewContext)
        newItem3.timestamp = Date()
        newItem3.grid = "..28......3..6...71......4.6...9.....5.6....9....57.6....3..1...7...6..84......2."
        newItem3.name = "Unsolvable #49"
        newItem3.currentGrid = newItem3.grid
        newItem3.solveGrid()

        // World's Hardest: https://abcnews.go.com/blogs/headlines/2012/06/can-you-solve-the-hardest-ever-sudoku
        let newItem4 = Item(context: viewContext)
        newItem4.timestamp = Date()
        newItem4.grid = "8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4.."
        newItem4.name = "World's Hardest"
        newItem4.currentGrid = newItem4.grid
        newItem4.solveGrid()

        // Save all.
        do {
            try viewContext.save()
            UserDefaults.standard.set(true, forKey: "loadDefaults")
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		Group {
			ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
			ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
		}
    }
}
