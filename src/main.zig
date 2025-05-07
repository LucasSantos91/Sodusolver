const std = @import("std");
const build_params = @import("build_params");

pub const std_options: std.Options = .{
    .log_level = @enumFromInt(@intFromEnum(build_params.log_level)),
};
const Cell = struct {
    pub const digit_count = 9;
    pub const DigitCount = std.math.IntFittingRange(0, digit_count);
    pub const last_digit = digit_count - 1;
    pub const Digit = std.math.IntFittingRange(0, last_digit);
    pub const DigitSet = std.StaticBitSet(digit_count);

    possible: DigitSet = .initFull(),

    pub fn count(self: @This()) DigitCount {
        return @intCast(self.possible.count());
    }
    pub fn set(self: *@This(), digit: Digit) void {
        self.possible = .initEmpty();
        self.possible.set(digit);
    }

    pub const Status = enum {
        ok,
        complete,
        invalid,
    };
    pub fn status(self: @This()) Status {
        return switch (std.math.order(self.count(), 1)) {
            .lt => .invalid,
            .eq => .complete,
            .gt => .ok,
        };
    }
    pub fn isComplete(self: @This()) bool {
        return self.status() == .complete;
    }
    pub fn ruleOut(self: *@This(), digit: Digit) Status {
        self.possible.unset(digit);
        return self.status();
    }
    pub fn getValue(self: @This()) Digit {
        std.debug.assert(self.isComplete());
        return @intCast(self.possible.findFirstSet().?);
    }

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options; // autofix
        const short_mode = comptime blk: {
            if (fmt.len == 0) break :blk true;
            const show_possibilities = std.mem.eql(u8, fmt, "e");
            const short_mode = std.mem.eql(u8, fmt, "s");
            if (!show_possibilities and !short_mode) @compileError("Unknown format option: " ++ fmt);
            break :blk short_mode;
        };

        if (comptime short_mode) {
            const text: u8 = switch (self.status()) {
                .ok => ' ',
                .invalid => '*',
                .complete => @as(u8, '1') + self.getValue(),
            };
            try writer.writeByte(text);
        } else {
            if (self.status() == .invalid) {
                try writer.writeAll(" invalid ");
                return;
            }
            for (0..digit_count) |index| {
                const char = if (self.possible.isSet(index))
                    @as(u8, @intCast(index)) + '1'
                else
                    ' ';
                try writer.writeByte(char);
            }
        }
    }
};

const Grid = struct {
    const Digit = Cell.Digit;
    const digit_count = Cell.digit_count;
    const cell_count = digit_count * digit_count;
    const CellCount = std.math.IntFittingRange(0, cell_count);
    const last_cell_index = cell_count - 1;
    const CellIndex = std.math.IntFittingRange(0, last_cell_index);
    const DigitSet = Cell.DigitSet;
    const square_side = std.math.sqrt(digit_count);
    const last_square_index = square_side - 1;
    const SquareIndex = std.math.IntFittingRange(0, last_square_index);
    const CellSet = std.StaticBitSet(cell_count);

    cells: [cell_count]Cell = .{Cell{}} ** cell_count,
    complete: CellSet = .initEmpty(),

    pub const Coord = struct {
        row: Digit,
        column: Digit,

        pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            try std.fmt.format(writer, "{c}{c}", .{ @as(u8, self.row) + 'A', @as(u8, self.column) + '1' });
        }

        pub fn toIndex(self: @This()) CellIndex {
            return @as(CellIndex, self.row) * digit_count + self.column;
        }
        pub fn fromIndex(index: CellIndex) @This() {
            return .{
                .row = @intCast(index / digit_count),
                .column = @intCast(index % digit_count),
            };
        }
    };

    const Status = enum {
        ok,
        invalid,
    };
    fn ruleOutAndCheckIfInvalid(self: *@This(), index: CellIndex, digit: Digit, complete: *CellSet) bool {
        switch (self.cells[index].ruleOut(digit)) {
            .invalid => return true,
            .ok => {},
            .complete => complete.set(index),
        }
        return false;
    }
    fn ruleOutRow(self: *@This(), row: Digit, digit: Digit, complete: *CellSet) Status {
        const offset = (Grid.Coord{ .row = row, .column = 0 }).toIndex();
        for (offset..offset + digit_count) |index| {
            if (self.ruleOutAndCheckIfInvalid(@intCast(index), digit, complete))
                return .invalid;
        }
        return .ok;
    }
    fn ruleOutColumn(self: *@This(), column: Digit, digit: Digit, complete: *CellSet) Status {
        for (0..digit_count) |n| {
            const index = (Grid.Coord{ .row = @intCast(n), .column = column }).toIndex();
            if (self.ruleOutAndCheckIfInvalid(@intCast(index), digit, complete))
                return .invalid;
        }
        return .ok;
    }
    fn ruleOutSquare(self: *@This(), row: SquareIndex, column: SquareIndex, digit: Digit, complete: *CellSet) Status {
        var index = (Grid.Coord.toIndex(.{ .row = row, .column = column })) * square_side;
        for (0..square_side) |_| {
            for (0..square_side) |_| {
                if (self.ruleOutAndCheckIfInvalid(@intCast(index), digit, complete))
                    return .invalid;
                index += 1;
            }
            index += digit_count - square_side;
        }
        return .ok;
    }

    fn propagate(self: *@This(), index_arg: CellIndex) Status {
        var pending: CellSet = .initEmpty();
        var index = index_arg;
        while (true) {
            const cell = &self.cells[index];
            const digit = cell.getValue();

            // Trick to prevent wrong .invalid
            const backup = cell.*;
            cell.* = .{};

            const row: Digit = @intCast(index / digit_count);
            const column: Digit = @intCast(index % digit_count);
            if (self.ruleOutRow(row, digit, &pending) == .invalid) return .invalid;
            if (self.ruleOutColumn(column, digit, &pending) == .invalid) return .invalid;
            if (self.ruleOutSquare(
                @intCast(row / square_side),
                @intCast(column / square_side),
                digit,
                &pending,
            ) == .invalid) return .invalid;

            cell.* = backup;
            self.complete.set(index);
            pending = pending.differenceWith(self.complete);
            const next_index = pending.toggleFirstSet() orelse return .ok;
            index = @intCast(next_index);
        }
    }

    pub fn isComplete(self: *const @This()) bool {
        for (self.cells) |cell| {
            if (!cell.isComplete()) return false;
        }
        return true;
    }

    pub fn set(self: *@This(), index: CellIndex, digit: Digit) Status {
        self.cells[index].set(digit);
        self.complete.set(index);
        return self.propagate(index);
    }
    pub fn setWithCoord(self: *@This(), coord: Coord, digit: Digit) Status {
        return self.set(coord.toIndex(), digit);
    }
    pub fn ruleOut(self: *@This(), index: CellIndex, digit: Digit) Status {
        return switch (self.cells[index].ruleOut(digit)) {
            .ok => .ok,
            .complete => blk: {
                self.complete.set(index);
                break :blk self.propagate(index);
            },
            .invalid => .invalid,
        };
    }
    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options; // autofix
        const short_mode = comptime blk: {
            if (fmt.len == 0) break :blk true;
            const show_possibilities = std.mem.eql(u8, fmt, "e");
            const short_mode = std.mem.eql(u8, fmt, "s");
            if (!show_possibilities and !short_mode) @compileError("Unknown format option: " ++ fmt);
            break :blk short_mode;
        };

        const inner_cell_len = if (comptime short_mode) 1 else digit_count;
        const column_text_size = 1;
        const row_text_size = 1;
        const cell_len = inner_cell_len + column_text_size;

        {
            const pad_left = @divFloor(inner_cell_len, 2);
            const pad_right = inner_cell_len - pad_left;
            var i: u8 = 1;
            try writer.writeAll(" " ** (row_text_size + 1));
            for (0..digit_count) |_| {
                const text = " " ** pad_left ++ "{}" ++ " " ** pad_right;
                try std.fmt.format(writer, text, .{i});
                i += 1;
            }
            try writer.writeAll("\n");
        }
        const writeRow = struct {
            fn writeRowCaption(w: anytype, row: u8) !void {
                try std.fmt.format(
                    w,
                    "{c}*",
                    .{@as(u8, @intCast('A' + row))},
                );
            }
            fn writeRowCell(w: anytype, cell: Cell, sep: u8) !void {
                try std.fmt.format(w, "{" ++ fmt ++ "}{c}", .{ cell, sep });
            }
            fn writeRowSquare(w: anytype, g: *const Grid, square_starting_index: CellIndex) !void {
                const last_offset = square_side - 1;
                for (0..last_offset) |cell_index| {
                    try writeRowCell(w, g.cells[square_starting_index + cell_index], '|');
                }
                try writeRowCell(w, g.cells[square_starting_index + last_offset], '*');
            }

            fn writeRow(w: anytype, g: *const Grid, row: Cell.Digit) !void {
                try writeRowCaption(w, row);
                const row_starting_index = @as(CellIndex, row) * digit_count;
                for (0..square_side) |square_index| {
                    const offset: CellIndex = @intCast(square_index * square_side);
                    const square_starting_index = row_starting_index + offset;
                    try writeRowSquare(w, g, square_starting_index);
                }
                try w.writeAll("\n");
            }
        }.writeRow;

        const square_separator = " " ++ "*" ** (cell_len * digit_count + 1) ++ "\n";
        const row_separator = " " ++ "-" ** (cell_len * digit_count + 1) ++ "\n";
        for (0..square_side) |square_row| {
            try writer.writeAll(square_separator);
            const base_row: Digit = @intCast(square_row * square_side);
            const last_offset = square_side - 1;
            for (0..last_offset) |inner_row| {
                const row: Digit = @intCast(base_row + inner_row);
                try writeRow(writer, self, row);
                try writer.writeAll(row_separator);
            }
            const row = base_row + last_offset;
            try writeRow(writer, self, row);
        }
        try writer.writeAll(square_separator);
    }
};

const GridChain = struct {
    const Guess = struct {
        grid: Grid,
        cell_index: Grid.CellIndex,
        digit: Cell.Digit,

        pub fn ruleOut(self: *@This()) Grid.Status {
            return self.grid.ruleOut(self.cell_index, self.digit);
        }
    };
    guesses: [Grid.cell_count]Guess,

    const GridError = error{InvalidGrid};
    fn findNextGuess(grid: Grid) ?Grid.CellIndex {
        var it = grid.complete.iterator(.{ .kind = .unset });
        const result = it.next() orelse return null;
        return @intCast(result);
    }
    pub fn compute(initial: Grid) GridError!Grid {
        var self: @This() = undefined;
        var guess: [*]Guess = self.guesses[0..].ptr;
        guess[0].grid = initial;
        const limit: [*]const Guess = guess;
        const logger = std.log.scoped(.grid_guessing);

        grid_loop: while (true) {
            const source_grid = &guess[0];
            logger.debug("Current grid:\n{e}", .{source_grid.grid});
            const guess_grid = &guess[1];
            cell_loop: while (true) {
                source_grid.cell_index = findNextGuess(source_grid.grid) orelse {
                    logger.info("Everything complete, success.", .{});
                    return source_grid.grid;
                };
                const cell = &source_grid.grid.cells[source_grid.cell_index];
                source_grid.digit = @intCast(cell.possible.findFirstSet().?);
                guess_loop: while (true) {
                    logger.info(
                        "Evaluating cell {}({}): {}.",
                        .{
                            cell.*,
                            source_grid.cell_index,
                            source_grid.digit,
                        },
                    );
                    guess_grid.grid = source_grid.grid;
                    switch (guess_grid.grid.set(source_grid.cell_index, source_grid.digit)) {
                        .invalid => {
                            logger.info("Invalid guess. Ruling out digit {} at cell {}.", .{ source_grid.digit, cell.* });
                            logger.debug("State after guess:\n{e}", .{guess_grid.grid});
                            switch (source_grid.ruleOut()) {
                                .ok => {
                                    const temp = cell.possible.findFirstSet() orelse {
                                        logger.info("No more guesses for cell {}.", .{cell.*});
                                        continue :cell_loop;
                                    };
                                    source_grid.digit = @intCast(temp);
                                    continue :guess_loop;
                                },
                                .invalid => {
                                    logger.info("Invalid grid. Starting backtracking.", .{});
                                    while (guess != limit) {
                                        guess -= 1;
                                        const previous_grid = &guess[0];
                                        logger.debug("Backtracking to previous grid:\n{e}.", .{previous_grid.grid});
                                        const rule_out_result = previous_grid.ruleOut();
                                        logger.info("Ruling out previous guess: {}: {} -- status: {}.", .{
                                            Grid.Coord.fromIndex(previous_grid.cell_index),
                                            previous_grid.digit,
                                            rule_out_result,
                                        });
                                        switch (rule_out_result) {
                                            .ok => {
                                                logger.info("Found previous good state. Finished backtracking.", .{});
                                                continue :grid_loop;
                                            },
                                            .invalid => {},
                                        }
                                    }
                                    logger.info("Backtracked as far as possible. Invalid grid.", .{});
                                    return GridError.InvalidGrid;
                                },
                            }
                        },
                        .ok => {
                            logger.info("Guess is good so far, advancing.", .{});
                            guess += 1;
                            continue :grid_loop;
                        },
                    }
                }
            }
        }
    }
};

const Clue = struct {
    cell: Grid.Coord,
    digit: Cell.Digit,

    fn readByte(reader: anytype) !?u8 {
        var char: [1]u8 = undefined;
        const count = try reader.read(&char);
        return if (count == 0) null else char[0];
    }
    fn isWhitespace(c: u8) bool {
        return c <= 0x20;
    }
    fn readOneNonWhitespace(reader: anytype) !?u8 {
        while (true) {
            const c = try readByte(reader) orelse return null;
            if (!isWhitespace(c)) return c;
        }
    }

    const RowError = error{InvalidRow};
    fn parseRow(letter: u8) RowError!Cell.Digit {
        if (letter >= 'A' and letter <= 'A' + Cell.last_digit)
            return @intCast(letter - 'A');
        if (letter >= 'a' and letter <= 'a' + Cell.last_digit)
            return @intCast(letter - 'a');
        return RowError.InvalidRow;
    }

    const DigitError = error{InvalidDigit};
    fn parseDigit(num: u8) DigitError!Cell.Digit {
        if (num >= '1' and num <= '1' + Cell.last_digit)
            return @intCast(num - '1');
        return DigitError.InvalidDigit;
    }

    const ClueError = error{ UnexpectedEnd, InvalidColumn } || RowError || DigitError;
    pub fn parse(reader: anytype) (ClueError || @TypeOf(reader).Error)!?Clue {
        const logger = std.log.scoped(.parsing_clues);
        const err = logger.err;
        logger.debug("Beginning to parse clue", .{});
        const row_letter = try readOneNonWhitespace(reader) orelse {
            logger.info("Reached end of clues", .{});
            return null;
        };
        const row = parseRow(row_letter) catch |e| {
            if (e == error.InvalidRow)
                err("Invalid row given at clue \"{c}\"", .{row_letter});
            return e;
        };
        const column_digit = try readByte(reader) orelse {
            err("Unexpected end at clue \"{c}\"", .{row_letter});
            return ClueError.UnexpectedEnd;
        };
        const column = parseDigit(column_digit) catch |e| {
            if (e == DigitError.InvalidDigit) {
                err("Invalid column given at clue \"{c}{c}\"", .{ row_letter, column_digit });
                return ClueError.InvalidColumn;
            } else return e;
        };
        const digit_char = try readByte(reader) orelse {
            err("Unexpected end at clue \"{c}{c}\"", .{ row_letter, column_digit });
            return ClueError.UnexpectedEnd;
        };
        const digit = parseDigit(digit_char) catch |e| {
            if (e == error.InvalidDigit)
                err("Invalid digit at clue \"{c}{c}{c}\"", .{ row_letter, column_digit, digit_char });
            return e;
        };
        const result: Clue = .{
            .cell = .{ .row = row, .column = column },
            .digit = digit,
        };
        logger.debug("Parsed clue: {}", .{result});
        return result;
    }

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; // autofix
        _ = options; // autofix
        try std.fmt.format(writer, "{}:{c}", .{ self.cell, @as(u8, self.digit) + '1' });
    }
};

const DoubledClueError = error{
    DoubledClue,
};
fn parseInitialGrid() (std.fs.File.ReadError || Clue.ClueError || DoubledClueError)!Grid {
    const stdin = std.io.getStdIn();
    var buffered_stdin = std.io.bufferedReader(stdin.reader());
    const reader = buffered_stdin.reader();
    var result: Grid = .{};
    const logger = std.log.scoped(.initial_grid_parsing);
    logger.info("Parsing clues", .{});
    while (try Clue.parse(reader)) |clue| {
        logger.info("Got clue: {}", .{clue});
        const index = clue.cell.toIndex();
        const cell = &result.cells[index];
        if (cell.isComplete()) {
            logger.err("Doubled clue for {}", .{clue.cell});
            return DoubledClueError.DoubledClue;
        }
        cell.set(clue.digit);
        result.complete.set(index);
        logger.debug("Current grid state:\n{}", .{result});
    }
    logger.info("Finished parsing initial grid:\n{}", .{result});
    return result;
}

fn applyClues(initial_grid: Grid) GridChain.GridError!Grid {
    var result: Grid = .{};
    var it = initial_grid.complete.iterator(.{ .kind = .set });
    const logger = std.log.scoped(.initial_grid_processing);
    logger.info("Starting processing of initial grid:\n{}", .{initial_grid});
    while (it.next()) |index| {
        const digit = initial_grid.cells[index].getValue();
        const status = result.set(@intCast(index), digit);
        logger.info("Applying clue: {} -- status: {}", .{
            Clue{ .cell = Grid.Coord.fromIndex(@intCast(index)), .digit = digit },
            status,
        });
        logger.debug("\n{e}", .{result});
        switch (status) {
            .ok => {},
            .invalid => return GridChain.GridError.InvalidGrid,
        }
    }
    logger.info("Finished processing initial grid:\n{e}", .{result});
    return result;
}
pub fn main() !void {
    const stdout = std.io.getStdOut();
    const example_grid = comptime blk: {
        var buffer: [512]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        std.fmt.format(writer, "{}", .{Grid{}}) catch unreachable;
        break :blk buffer[0..stream.pos].*;
    };
    try stdout.writeAll("Pass clues in the format RowColumnNumber, like this: A12.\n" ++ example_grid ++ "\n");
    var buffered_stdout = std.io.bufferedWriter(stdout.writer());
    defer buffered_stdout.flush() catch {};
    const writer = buffered_stdout.writer();
    const initial_grid = try parseInitialGrid();
    try std.fmt.format(writer, "Given grid:\n{}\n", .{initial_grid});
    const Instant = std.time.Instant;
    const backup_instant: Instant = .{ .timestamp = 0 };
    const starting_time: Instant = Instant.now() catch backup_instant;
    const validated_grid = applyClues(initial_grid) catch |err| {
        const finish_time: Instant = Instant.now() catch backup_instant;
        const time_delta = finish_time.since(starting_time);
        try std.fmt.format(writer, "There is no solution.\nTime taken: {} ms.", .{time_delta / std.time.ns_per_ms});
        return err;
    };
    const final_grid_or_error = GridChain.compute(validated_grid);
    const finish_time: Instant = Instant.now() catch backup_instant;
    const result: GridChain.GridError!void = if (final_grid_or_error) |final_grid| {
        try std.fmt.format(writer, "The solution is:\n{}", .{final_grid});
    } else |e| blk: {
        try std.fmt.format(writer, "There is no solution.", .{});
        break :blk e;
    };

    const time_delta = finish_time.since(starting_time);
    try std.fmt.format(writer, "\nTime taken: {} ms.", .{time_delta / std.time.ns_per_ms});
    return result;
}
