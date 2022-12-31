//
//  Item+CoreDataClass.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//
//

import Foundation
import CoreData

@objc(Item)
public class Item: NSManagedObject {
	let digits:String = "123456789"
	let rows:String = "ABCDEFGHI"
	let columns:String = "123456789"
	var squares:Array<String> = []
	var unitList:Array<Array<String>> = []
    var units:[String: Array<Array<String>>] = [String: Array<Array<String>>]()
	var peers:[String: Array<String>] = [String: Array<String>]()
    var limit:Int = 2000 // Based on the hardest one I could find: Unsolvable #28 in 1386 steps
    var step:Int = 0
    var currentSolutionSquaresIndex:Int = 0
    var currentValues:[String:String] = [:]
    var isPaused:Bool = false
    var isPlaying:Bool = false

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        initSquares()
    }
    
	func cross(firstString:String, secondString:String) -> Array<String> {
		// Combine A and B elements (e.g. "AB" + "12" = ["A1", "A2", "B1", "B2"]).
		var crossedArray:[String] = []
		Array(firstString).forEach { firstChar in
			Array(secondString).forEach { secondChar in
				crossedArray.append("\(firstChar)\(secondChar)")
			}
		}
		return crossedArray
	}
	
	func initSquares() {
		// Initialize squares.
		squares = cross(firstString:rows, secondString:columns)
		
		// Initialize list of units.
		let unitList1 = Array(columns).map { c in cross(firstString:rows, secondString:String(c)) }
		let unitList2 = Array(rows).map { r in cross(firstString:String(r), secondString:columns) }
		var unitList3:[[String]] = []
		["ABC", "DEF", "GHI"].forEach { rSection in
			["123", "456", "789"].forEach { cSection in
				unitList3.append(cross(firstString:rSection, secondString:cSection))
			}
		}
		unitList = unitList1 + unitList2 + unitList3
		
		// Initialize units.
		units = [String: [[String]]]()
		squares.forEach { square in
			unitList.forEach { unit in
				if unit.contains(square) {
					if units[square] == nil {
						units[square] = []
					}
                    units[square]? += [unit]
				}
			}
		}

        // Initalize peers.
		peers = [String: [String]]()
		units.forEach { (key: String, value: [[String]]) in
            peers[key] = value.flatMap{ $0 }
            peers[key] = (NSOrderedSet(array: peers[key]!).array as! [String])
			peers[key] = peers[key]!.filter({ $0 != key})
		}
        
        if (self.finalGrid == nil) {
            self.finalGrid = ""
        }
        step = 0
	}

    func parseGrid(solutionSquares: inout [String]) -> [String:String]? {
        var values:[String:String] = [String: String]()
        squares.forEach { square in
            values[square] = digits
        }
        let grid_array = Array(self.grid!).map{String($0)}
        let keys_and_values = zip(squares, grid_array)
        let grid_values = Dictionary(uniqueKeysWithValues: keys_and_values)

        for (square, current_value) in grid_values {
            if digits.contains(current_value) && assign(values:&values, solutionSquares: &solutionSquares, square:square, value_to_assign:current_value) == nil {
                return nil
            }

            if digits.contains(current_value) {
                // Remove initial square from solutionSquares.
                solutionSquares = solutionSquares.filter { $0 != square }
            }
        }

        return values
    }

    func assign(values: inout [String:String], solutionSquares: inout [String], square:String, value_to_assign:String) -> [String:String]? {
        // DEBUG: print("assign \(square):\(value_to_assign)")
        let other_values = values[square]!.replacingOccurrences(of:value_to_assign, with:"").map {String($0)}
        if (other_values.reduce(true) {$0 && eliminate(values:&values, solutionSquares: &solutionSquares, square:square, value_to_eliminate:$1) != nil}) {
            if (!solutionSquares.contains(square)) {
                solutionSquares = solutionSquares + [square]
            }
			return values
		}
		else {
			return nil
		}
	}

    func eliminate(values: inout [String:String], solutionSquares: inout [String], square:String, value_to_eliminate:String) -> [String:String]? {
		if (!values[square]!.contains(value_to_eliminate)) {
			return values
		}
        
        // NOTE: Not happy with this implementation but not familiar enough to have an alternative. Open to suggestions.
        while (self.isPaused) {
            _ = DispatchQueue.main.sync {
                usleep(1000) // Wait .01s until checking that we're unpaused
            }
        }
        if (self.isPlaying) {
            _ = DispatchQueue.main.sync {
                usleep(1000) // Wait .01s before continuing during play mode
            }
         }

        // DEBUG: print("eliminate \(square):\(value_to_eliminate)")
        values[square] = String(values[square]!.replacingOccurrences(of:value_to_eliminate, with:"")) // as! String

        // Update current state of values for UI.
        self.currentValues = values
        self.currentGrid = self.currentGrid

        // 1) Propagate elimination of single value to peers.
		if (values[square]!.count == 0) {
			return nil
		}
		else if (values[square]!.count == 1) {
            let other_value:String? = values[square]
            if !(peers[square]!.reduce(true) { $0 && eliminate(values:&values, solutionSquares: &solutionSquares, square:$1, value_to_eliminate:other_value!) != nil}) {
                return nil
            }
		}
        // 2) If a unit has only one place for value, assign it.
        for unit in units[square] ?? [] {
            var squares_with_value:Array<String> = []
            for unit_square in unit {
                let unit_square_values:String = values[String(unit_square)]! // needs nil
                if unit_square_values.contains(value_to_eliminate) {
                    squares_with_value.append(String(unit_square))
                }
            }
            if (squares_with_value.count == 0) {
                return nil
            }
            else if (squares_with_value.count == 1) {
                if !(assign(values:&values, solutionSquares: &solutionSquares, square:squares_with_value[0], value_to_assign:value_to_eliminate) != nil) {
                    return nil
                }
            }
        }

        return values
	}
	
	func some(seq:Array<[String:String]?>) -> [String:String]? {
        var result:[String:String]? = nil
        for e in seq {
            if (e != nil) {
                result = e
            }
        }
		return result
	}

    func search(values:[String:String]?, solutionSquares: inout [String]) -> [String:String]? {
        // Fail after 1000 searches.
        step += 1
        if (step > limit) {
            return nil
        }
        else if (values == nil) {
			return nil
		}
		else if (values!.keys.reduce(true) { $0 && values![$1]!.count == 1 }) {
            // NOTE: SudokuAI supports incomplete grids. Store self.finalGrid to cut off further successful searches.
            // This differs from the Python implementation because of its lazy evaluation.
            self.finalGrid = convertValuesToGrid(values: values)
            self.solutionSquares = solutionSquares
			return values
		}
		else {
            let squares_with_smallest_values:Array<String> = values!.keys.sorted(by: { a, b in
                a < b
            }).filter { possible_square in
                return values![possible_square]!.count > 1
            }.compactMap({ $0 })
            let square_with_smallest_values = squares_with_smallest_values.min(by: { a, b in
                values![a]!.count < values![b]!.count
            })
            let values_for_square:String = values![square_with_smallest_values!]!
            // DEBUG: print("search \(step) \(square_with_smallest_values): \(values_for_square)")
            // Clone to branch off.
            var nextSolutionSquares:[String] = solutionSquares
            return some(seq:
                Array(values_for_square).map({ current_value in
                    // NOTE: SudokuAI supports solving incomplete grids. Check self.finalGrid to cut off further successful searches.
                    if (self.finalGrid != "") {
                        // A different search matched. Ignore this one.
                        return nil
                    }

                    var cloned_values = values
                    return search(
                        values:assign(values:&cloned_values!, solutionSquares: &nextSolutionSquares, square: square_with_smallest_values!, value_to_assign: String(current_value)),
                        solutionSquares: &nextSolutionSquares
                    )
                })
            )
		}
	}
    
    func convertValuesToGrid(values:[String:String]?) -> String {
        values!.keys.sorted().map { square in
            values![square]!.count != 1 ? "." : values![square]!
        }.joined(separator: "")
    }

    func convertGridToValues(grid:String?) -> [String:String]? {
        let grid_array = Array((grid ?? "")! as String).map{String($0)}
        let keys_and_values = zip(squares, grid_array)
        let grid_values = Dictionary(uniqueKeysWithValues: keys_and_values)
        return grid_values
    }

    func solveGrid() {
        step = 0
        self.finalGrid = ""
        var solutionSquares:[String] = []
        let values = parseGrid(solutionSquares: &solutionSquares)
        let values_solved = search(values: values, solutionSquares: &solutionSquares)
        if (values_solved != nil) {
            self.finalGrid = convertValuesToGrid(values: values_solved)
        }
        else {
            // No solution
            self.finalGrid = ""
        }
        // Reset displayed values.
        self.currentValues = [:]
	}
    
    func increment(row: Int, column: Int) {
        // Convert grid to values to edit it.
        var values = convertGridToValues(grid: self.grid)
        // Get the square and value.
        let square:String = "\(rows[rows.index(rows.startIndex, offsetBy:row)])\(columns[columns.index(columns.startIndex, offsetBy:column)])"
        var value:String? = values![square]
        // Increment value and save for that square.
        if (value == ".") {
            value = "1"
        }
        else if (value == "9") {
            value = "."
        }
        else {
            value = String((Int(value ?? "") ?? 0) + 1)
        }
        // Save new value to square and re-save the values to the grid.
        values![square] = value
        self.objectWillChange.send()
        self.grid = convertValuesToGrid(values: values)
        self.currentGrid = self.grid
    }

    func gridState(row:Int, column:Int) -> Bool {
        // Check if row/column matches a square with a value that wasn't in the original state.
        let values = convertGridToValues(grid: self.grid)
        let square:String = "\(rows[rows.index(rows.startIndex, offsetBy:row)])\(columns[columns.index(columns.startIndex, offsetBy:column)])"
        let value:String? = values![square]
        return value == "."
    }

    func arrayWithDotsToGridCellValues(values: String) -> [String] {
        Array("123456789").map { value in
            values.contains(value) ? String(value) : "."
        }
    }

    func squareInGrid(row:Int, column:Int) -> String {
        return "\(rows[rows.index(rows.startIndex, offsetBy:row)])\(columns[columns.index(columns.startIndex, offsetBy:column)])"
    }

    func currentGridPlusNextSquare() -> String? {
        if (self.currentSolutionSquaresIndex < self.solutionSquares!.count) {
            var nextGridValues:[String:String]? = convertGridToValues(grid: self.currentGrid)
            let finalGridValues:[String:String]? = convertGridToValues(grid: self.finalGrid)
            let nextSquare:String = self.solutionSquares![self.currentSolutionSquaresIndex]
            nextGridValues![nextSquare] = finalGridValues![nextSquare]
            let nextGrid:String = convertValuesToGrid(values: nextGridValues)
            self.currentSolutionSquaresIndex += 1
            return nextGrid
        }
        else {
            return self.finalGrid
        }

    }
}
