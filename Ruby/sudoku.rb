# https://norvig.com/sudoku.html

require 'pry-byebug'
require 'csv'

class SudokuAI < Object
    def initialize()
        @digits = '123456789'
        @rows = 'ABCDEFGHI'
        @columns = @digits
        @moves = -1
        @invalid_grids = []
        @valid_grids = []
        @final_grid = nil
        @start = Time.now

        # Initialize squares.
        @squares = SudokuAI.cross(@rows, @columns)

        # Initialize list of units.
        @unitlist = @columns.chars.inject([]) {|array, c| array << SudokuAI.cross(@rows, c)} +
                   @rows.chars.inject([]) {|array, r| array << SudokuAI.cross(r, @columns)} +
                   ["ABC", "DEF", "GHI"].each.inject([]) {|array, rSection| ["123", "456", "789"].each {|cSection| array << SudokuAI.cross(rSection, cSection)}; array}
        # Initialize units.
        @units = {}
        @squares.each do |square|
            @unitlist.each do |unit|
                if unit.include?(square)
                    @units[square] = [] if @units[square].nil?
                    @units[square] << unit
                end
            end
        end
        
        # Initialize peers.
        @peers = @units.keys.each.inject({}) {|peers, key| peers[key] = @units[key].flatten.uniq.reject {|item| item == key}; peers}
    end

    def moves
        @moves
    end

    def final_grid
        @final_grid
    end

    def elapsed_ms
        # Use milliseconds.
        ((Time.now - @start) * 1000).to_i
    end

    def log(message)
        # Comment out to suppress logging.
        puts message
    end

    # Combine A and B elements (e.g. ["A", "B"] + ["1", "2"] = ["A1", "A2", "B1", "B2"]).
    def self.cross(aArray, bArray)
        aArray.chars.inject([]) {|array, a| bArray.chars.each {|b| array << a + b}; array}
    end

    # Check if grid is complete.
    def self.is_final_values(values)
        !SudokuAI.convert_values_to_grid(values).include?(".")
    end

    # Convert values dictionary into grid.
    def self.convert_values_to_grid(values)
        debugger if values == nil || values == false
        new_grid = values.values.collect {|value| value.length > 1 ? "." : value}.join
        raise RuntimeError unless new_grid.length == 81
        return new_grid
    end

    # Print human-readable version of grid.
    def format_grid(grid)
        # Print grid as standard squares.
        grid.chars.each_slice(9).to_a.each_with_index do |row, i|
            log (row.slice(0,3).join + "|" + row.slice(3,3).join + "|" + row.slice(6,3).join).split("").join(" ")
            log "------+------+------" if i % 3 == 2 && i < 8
        end
    end

    # Validate current representation.
    def validate(values)
        raise RuntimeError unless @squares.count == 81
        raise RuntimeError unless @unitlist.count == 27
        @squares.each {|square| raise RuntimeError unless @units[square].count == 3 }
        @squares.each {|square| raise RuntimeError unless @peers[square].count == 20 }

        # Iterate through the values and validate.
        return false if values == false
        values.each do |square, value|
            # puts "validate false: zero value" if value.length == 0
            return false if value.length == 0
            @units[square].each do |unit|
                # Fail if any unit has chosen values that repeat numbers (e.g. 11).
                unit_values = unit.collect {|unit_peer| values[unit_peer] if values[unit_peer].length == 1}.compact
                # debugger if unit_values.length != unit_values.uniq.length
                # puts "validate false: failed constraint" if unit_values.length != unit_values.uniq.length
                return false if unit_values.length != unit_values.uniq.length
            end
        end

        return true
    end

    # Parse grid and run constraint propagation.
    def parse_grid_dunagan(grid)
        # Convert grid to squares.
        values = @squares.zip(grid.chars).to_h
        # puts "===================="
        # display_values(values)
        # puts "===================="

        # Populate with possible values.
        values.each { |key, value| values[key] = [".", "0"].include?(value) ? "123456789" : value}
        return false if self.validate(values) == false # Fail fast.
    
        # Constraint Propagation (1): Remove impossible values in squares.
        values = self.eliminate_dunagan(values)
        return false if self.validate(values) == false # Fail fast.
        # Constraint Propagation (2): Assign values if only one possible place.
        values = self.assign_dunagan(values)
        return false if self.validate(values) == false # Fail fast.

        return values
    end

    def display_values(values)
        values.values.each_slice(9).to_a.each_with_index do |row, i|
            log row[0..2].collect {|r| r.center(9)}.join(" ") + "|" + row[3..5].collect {|r| r.center(9)}.join(" ") + "|" + row[6..8].collect {|r| r.center(9)}.join(" ")
            log "-----------------------------+-----------------------------+-----------------------------" if i % 3 == 2 && i < 8
        end
        log ""
    end

    # Constraint Propagation (1): Remove impossible values in squares.
    def eliminate_dunagan(values)
        # For every square with a single value, eliminate that value from its peers.
        values.each do |square, value|
            if value.length == 1
                # Iterate through peers.
                @peers[square].each do |peer|
                    if values[peer].include?(value) && values[peer].length > 1
                        # Delete value from peer.
                        values[peer].delete!(value)
                        if values[peer].length == 1
                            # Peer has single value, so propagate constraint.
                            self.eliminate_dunagan(values)
                        end
                    end
                end
            end
        end
    end

    # Constraint Propagation (2): Assign values if only one possible place.
    def assign_dunagan(values)
        values.each do |square, value|
            @units[square].each do |unit|
                # Collect all values of peers.
                peer_values = unit.reject{|unit_square| unit_square == square}.collect{|unit_square| values[unit_square]}.join.split("").uniq.sort.join
                value.chars.each do |char|
                    if !peer_values.include?(char) && values[square].length > 1
                        # Peer values do not include this number, so this number must be in this space.
                        values[square] = char

                        # Propagate contraint. Re-eliminate and re-assign now that we've made an assignment.
                        self.eliminate_dunagan(values)
                        self.assign_dunagan(values)
                    end
                end
            end
        end
    end

    # Backtracking Depth-First Search (BDFS): Search depth-first by each square value, starting with the smallest valued square.
    def search_dunagan(grids)
        # Iterate over possible grids.
        new_grids = []
        grids = [grids] if grids.class != Array
        grids.each do |grid|
            # Parse grid into values with elimination and assignment.
            values = self.parse_grid_dunagan(grid)

            if values != false && !@valid_grids.include?(grid)
                # This is a valid grid.
                @moves += 1

                # log "[BDFS] #{grid} #{@moves} moves (#{self.elapsed_ms}ms)"

                if SudokuAI.is_final_values(values) # <= This should test parsed grid, after elimination.
                    # This is the final grid.
                    @final_grid = SudokuAI.convert_values_to_grid(values)
                    return @final_grid
                else
                    # This is not the final grid.
                    # Find square with smallest set of possible values to generate new grids from.
                    min_length = 2
                    chosen_square = nil
                    chosen_value = nil
                    while min_length <= 9 && chosen_square == nil && chosen_value == nil
                        values.each do |square, value|
                            if value.length == min_length && chosen_square == nil && chosen_value == nil
                                chosen_square = square
                                chosen_value = value
                            end
                        end

                        # Increase length of minimum possible values.
                        min_length += 1
                    end

                    # Generate new grids based on chosen square's values.
                    chosen_value.chars.each do |char|
                        # Stop if a different iteration already found the final grid.
                        return @final_grid if @final_grid != nil

                        # Clone to ensure we do not clobber a different recursion.
                        new_values = values.clone
                        # Assign new potential number, convert to grid, and search it.
                        new_values[chosen_square] = char
                        new_grid = SudokuAI.convert_values_to_grid(new_values)
                        new_grids << new_grid if !@invalid_grids.include?(new_grid)
                    end
                end
            end
        end

        self.search_dunagan(new_grids)
    end

    def parse_grid_norvig(grid)
        # Convert grid to squares.
        values = @squares.collect {|square| [square, @digits]}.to_h
        grid_values = @squares.zip(grid.chars).to_h
        grid_values.each do |square, value|
            if @digits.include?(value) && !self.assign_norvig(values, square, value)
                return false
            end
        end

        return values
    end

    def assign_norvig(values, square, value)
        other_values = values[square].gsub(value, "")
        if other_values.chars.all? {|other_value| self.eliminate_norvig(values, square, other_value)}
            return values
        else
            return false
        end
    end

    def eliminate_norvig(values, square, value)
        return values if !values[square].include?(value)
        values[square] = values[square].gsub(value, "")
        # display_values(values)
        # 1) Propagate elimination of single value to peers.
        if values[square].length == 0
            return false
        elsif values[square].length == 1
            other_value = values[square]
            if !@peers[square].all? {|peer| self.eliminate_norvig(values, peer, other_value) }
                return false
            end
        end
        # 2) If a unit has only one place for value, assign it.
        @units[square].each do |unit|
            squares_with_value = unit.collect {|unit_square| unit_square if values[unit_square].include?(value)}.compact
            if squares_with_value.length == 0
                return false
            elsif squares_with_value.length == 1
                if !self.assign_norvig(values, squares_with_value[0], value)
                    return false
                end
            end
        end
        
        return values
    end

    def some(seq)
        seq.each do |e|
            if e != false
                return e
            end
        end
        return false
    end

    def search_norvig(values)
        if values == false
            return false
        elsif values.keys.all? {|square| values[square].length == 1}
            @final_grid = SudokuAI.convert_values_to_grid(values)
            return values
        else
            square_with_smallest_values = values.keys.collect {|square| square if values[square].length > 1}.compact.min {|a, b| values[a].length <=> values[b].length}
            square_with_smallest_values = square_with_smallest_values[0] if square_with_smallest_values.class == Array
            # display_values(values)
            return self.some(values[square_with_smallest_values].chars.collect {|value| @final_grid != nil ? nil : self.search_norvig(self.assign_norvig(values.clone, square_with_smallest_values, value))})
        end
    end

    def search(grid, search_type = "Norvig", move_limit = 200)
        @move_limit = move_limit
        if search_type == "Dunagan"
            final_grid = search_dunagan(grid)
            # Convert back into values.
            self.parse_grid_dunagan(final_grid)
        else
            search_norvig(grid)
        end
    end
end

# Read in list of Sudoku puzzles.
headers = ["Grid", "Solution", "Dunagan Time (ms)", "Norvig Time (ms)", "Name", "Source"]
csv = CSV.read("sudoku.csv", headers: true)

# Iterate through each puzzle.
results = []
csv.each do |row|
    grid = row[headers[0]]
    name = row[headers[4]]
    source = row[headers[5]]

    #
    # Solve the puzzle using the selected search with move limit supplied.
    #

    # Use Python port.
    s = SudokuAI.new()
    # s.display_values(s.parse_grid(grid))
    final_grid_values = s.search(s.parse_grid_norvig(grid), "Norvig", 2000)
    debugger if final_grid_values == nil
    final_grid = SudokuAI.convert_values_to_grid(final_grid_values)
    python_moves = final_grid != nil ? s.moves : "-"
    python_time = s.elapsed_ms
    puts "[Norvig]  #{grid} - #{python_time}ms (#{name} - #{source})"

    # Use backtracking depth-first search.
    s = SudokuAI.new()
    # s.display_values(s.parse_grid_dunagan(grid))
    final_grid_values = s.search(grid, "Dunagan", 2000)
    debugger if final_grid_values == nil
    final_grid = SudokuAI.convert_values_to_grid(final_grid_values)
    bdfs_moves = final_grid != nil ? s.moves : "-"
    bdfs_time = s.elapsed_ms
    puts "[Dunagan] #{grid} - #{bdfs_time}ms (#{name} - #{source})"

    # Store result.
    results << [grid, final_grid, bdfs_time, python_time, name, source]
end

# Store results.
CSV.open("sudoku.csv", "wb") do |csv|
    csv << headers
    results.each do |result|
        csv << result
    end
end
