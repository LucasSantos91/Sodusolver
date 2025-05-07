const std = @import("std");

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
        _ = fmt; // autofix
        _ = options; // autofix
        if (self.status() == .invalid) try writer.writeAll(" invalid ");
        for (0..digit_count) |index| {
            if (self.possible.isSet(index))
                try std.fmt.format(writer, "{}", .{index + 1})
            else
                try writer.writeAll(" ");
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
    };
    fn coordToIndex(coord: Coord) CellIndex {
        return @as(CellIndex, coord.row) * digit_count + coord.column;
    }
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
        const offset = coordToIndex(.{ .row = row, .column = 0 });
        for (offset..offset + digit_count) |index| {
            if (self.ruleOutAndCheckIfInvalid(@intCast(index), digit, complete))
                return .invalid;
        }
        return .ok;
    }
    fn ruleOutColumn(self: *@This(), column: Digit, digit: Digit, complete: *CellSet) Status {
        for (0..digit_count) |n| {
            const index = coordToIndex(.{ .row = @intCast(n), .column = column });
            if (self.ruleOutAndCheckIfInvalid(@intCast(index), digit, complete))
                return .invalid;
        }
        return .ok;
    }
    fn ruleOutSquare(self: *@This(), row: SquareIndex, column: SquareIndex, digit: Digit, complete: *CellSet) Status {
        var index = coordToIndex(.{ .row = row, .column = column }) * square_side;
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

    pub fn propagate(self: *@This(), index_arg: CellIndex) Status {
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

    pub fn mark(self: *@This(), coord: Coord, digit: Digit) Status {
        const index = coordToIndex(coord);
        self.cells[index].set(digit);
        self.complete.set(index);
        return self.propagate(index);
    }

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; // autofix
        _ = options; // autofix

        try writer.writeAll(" ");
        const offset = (digit_count + 1) / 2;
        const pad = " " ** offset;
        var i: u8 = 1;
        for (0..square_side) |_| {
            try writer.writeAll(" ");
            for (0..square_side) |_| {
                try writer.writeAll(pad);
                try std.fmt.format(writer, "{}", .{i});
                try writer.writeAll(pad[0 .. pad.len - 1]);
                i += 1;
            }
        }
        try writer.writeAll("\n");
        const separator = " " ++ "-" ** ((digit_count + 1) * digit_count + 2 + square_side) ++ "\n";
        var index: CellIndex = 0;
        var row: u8 = 0;
        for (0..square_side) |_| {
            try writer.writeAll(separator);
            for (0..square_side) |_| {
                try std.fmt.format(writer, separator ++ "{c}", .{@as(u8, @intCast('A' + row))});
                for (0..square_side) |_| {
                    try writer.writeAll("|");
                    for (0..square_side) |_| {
                        try std.fmt.format(writer, "|{}", .{self.cells[index]});
                        index += 1;
                    }
                }
                try writer.writeAll("||\n");
                row += 1;
            }
        }
        try writer.writeAll(separator ++ separator);
    }
};

const Guess = struct {
    const CellIndex = Grid.CellIndex;
    grid: Grid,
    cell: CellIndex,
};

const Clue = struct {
    cell: Grid.CellIndex,
    digit: Cell.Digit,

    fn readByte(reader: anytype) !?u8 {
        var char: [1]u8 = undefined;
        const count = try reader.read(&char);
        return if (count == 0) null else char[0];
    }
    fn isWhitespace(c: u8) bool {
        return c < 0x20;
    }
    fn readOneNonWhitespace(reader: anytype) !?u8 {
        while (true) {
            const c = try readByte(reader) orelse return null;
            if (!isWhitespace(c)) return c;
        }
    }

    const RowError = error{InvalidRow};
    fn parseRow(letter: u8) RowError!Cell.Digit {
        if (letter >= 'A' and letter < 'A' + Cell.last_digit)
            return @intCast(letter - 'A');
        if (letter >= 'a' and letter < 'a' + Cell.last_digit)
            return @intCast(letter - 'a');
        return RowError.InvalidRow;
    }

    const DigitError = error{InvalidDigit};
    fn parseDigit(num: u8) DigitError!Cell.Digit {
        if (num >= '1' and num < '1' + Cell.last_digit)
            return @intCast(num - '1');
        return DigitError.InvalidDigit;
    }

    const ClueError = error{ UnexpectedEnd, InvalidColumn } || RowError || DigitError;
    fn ParseClue(reader: anytype) ClueError!?Clue {
        const row_letter = try readOneNonWhitespace(reader) orelse return null;
        const row = try parseRow(row_letter);
        const column_digit = try readByte(reader) orelse return ClueError.UnexpectedEnd;
        const column = parseDigit(column_digit) catch |err| return if (err == DigitError.InvalidDigit)
            ClueError.InvalidColumn
        else
            err;
        const digit_char = try readByte(reader) orelse return ClueError.UnexpectedEnd;
        const digit = try parseDigit(digit_char);
        return .{
            .cell = Grid.rowColToIndex(row, column),
            .digit = digit,
        };
    }
};

fn setInitialGrid() void {
    const stdin = std.io.getStdIn();
    var buffered_stdin = std.io.bufferedReader(stdin.reader());
    const reader = buffered_stdin.reader();
    _ = reader; // autofix
}
pub fn main() !void {
    var a: Grid = .{};
    for ([_]u8{ 0, 3, 5 }) |i| a.cells[30].possible.unset(i);
    _ = a.mark(.{ .row = 1, .column = 3 }, 4);
    const stdout = std.io.getStdOut();
    var buffered = std.io.bufferedWriter(stdout.writer());
    const writer = buffered.writer();
    try std.fmt.format(writer, "{}", .{a});
    try buffered.flush();
}
