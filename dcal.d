/**
 * D calendar
 *
 * An example of how using component-style programming with ranges simplifies a
 * complex task into manageable pieces. The task is, given a year, to produce a
 * range of lines representing a nicely laid-out calendar of that year.
 *
 * This example shows how something is complex as calendar layout can be
 * written in a clear, readable way that allows individual components to be
 * reused.
 */

import std.algorithm;
import std.conv;
import std.datetime;
import std.functional;
import std.range;
import std.stdio : writeln, writefln, stderr;
import std.string;


/**
 * Returns: A string containing exactly n spaces.
 */
string spaces(size_t n) pure nothrow {
    import std.array : replicate;
    return replicate(" ", n);
}


/**
 * Returns: A range of dates in a given year.
 */
auto datesInYear(int year) pure {
    return Date(year, 1, 1)
        .recurrence!((a,n) => a[n-1] + 1.days)
        .until!(a => a.year > year);
}

unittest {
    auto dates = datesInYear(2013);
    assert(!dates.empty);
    assert(dates.front == Date(2013, 1, 1));

    // Check increment
    dates.popFront();
    assert(dates.front == Date(2013, 1, 2));

    // Check monthly rollover
    foreach (i; 2 .. 31) {
        assert(!dates.empty);
        dates.popFront();
    }
    assert(!dates.empty);
    assert(dates.front == Date(2013, 1, 31));
    dates.popFront();

    assert(!dates.empty);
    assert(dates.front == Date(2013, 2, 1));
}

unittest {
    // Check length of year
    auto dates = datesInYear(2013);
    foreach (i; 0 .. 365) {
        assert(!dates.empty);
        dates.popFront();
    }
    assert(dates.empty);
}


/**
 * Convenience template for verifying that a given range is an input range of
 * Dates.
 */
template isDateRange(R) {
    enum isDateRange = isInputRange!R && is(ElementType!R : Date);
}

static assert(isDateRange!(typeof(datesInYear(1))));


/**
 * Chunks an input range by equivalent elements.
 *
 * This function takes an input range, and splits it up into subranges that
 * contain equivalent adjacent elements, where equivalence is defined by having
 * the same value of attrFun(e) for each element e.
 *
 * Note that equivalent elements separated by an intervening non-equivalent
 * element will appear in separate subranges; this function only considers
 * adjacent equivalence.
 *
 * This is similar to std.algorithm.group, but the latter can't be used when
 * the individual elements in each group must be iterable in the result.
 *
 * Parameters:
 *  attrFun = The function for determining equivalence. The return value must
 *      be comparable using ==.
 *  r = The range to be chunked.
 *
 * Returns: A range of ranges in which all elements in a given subrange share
 * the same attribute with each other.
 */
auto chunkBy(alias attrFun, Range)(Range r)
    if (isInputRange!Range &&
        is(typeof(
            attrFun(ElementType!Range.init) == attrFun(ElementType!Range.init)
        ))
    )
{
    alias attr = unaryFun!attrFun;
    alias AttrType = typeof(attr(r.front));

    static struct Chunk {
        private Range r;
        private AttrType curAttr;
        @property bool empty() {
            return r.empty || !(curAttr == attr(r.front));
        }
        @property ElementType!Range front() { return r.front; }
        void popFront() {
            assert(!r.empty);
            r.popFront();
        }
    }

    static struct ChunkBy {
        private Range r;
        private AttrType lastAttr;
        this(Range _r) {
            r = _r;
            if (!empty)
                lastAttr = attr(r.front);
        }
        @property bool empty() { return r.empty; }
        @property auto front() {
            assert(!r.empty);
            return Chunk(r, lastAttr);
        }
        void popFront() {
            assert(!r.empty);
            while (!r.empty && attr(r.front) == lastAttr) {
                r.popFront();
            }
            if (!r.empty)
                lastAttr = attr(r.front);
        }
        static if (isForwardRange!Range) {
            @property ChunkBy save() {
                ChunkBy copy = this;
                copy.r = r.save;
                return copy;
            }
        }
    }
    return ChunkBy(r);
}

///
unittest {
    auto range = [
        [1, 1],
        [1, 1],
        [1, 2],
        [2, 2],
        [2, 3],
        [2, 3],
        [3, 3]
    ];

    auto byX = chunkBy!(a => a[0])(range);
    auto expected1 = [
        [[1, 1], [1, 1], [1, 2]],
        [[2, 2], [2, 3], [2, 3]],
        [[3, 3]]
    ];
    foreach (e; byX) {
        assert(!expected1.empty);
        assert(e.equal(expected1.front));
        expected1.popFront();
    }

    auto byY = chunkBy!(a => a[1])(range);
    auto expected2 = [
        [[1, 1], [1, 1]],
        [[1, 2], [2, 2]],
        [[2, 3], [2, 3], [3, 3]]
    ];
    foreach (e; byY) {
        assert(!expected2.empty);
        assert(e.equal(expected2.front));
        expected2.popFront();
    }
}


/**
 * Chunks a given input range of dates by month.
 * Returns: A range of ranges, each subrange of which contains dates for the
 * same month.
 */
auto byMonth(InputRange)(InputRange dates)
    if (isDateRange!InputRange)
{
    return dates.chunkBy!(a => a.month());
}

unittest {
    auto months = datesInYear(2013).byMonth();
    int month = 1;
    do {
        assert(!months.empty);
        assert(months.front.front == Date(2013, month, 1));
        months.popFront();
    } while (++month <= 12);

    assert(months.empty);
}


/**
 * Chunks a given input range of dates by week.
 * Returns: A range of ranges, each subrange of which contains dates for the
 * same week. Note that weeks begin on Sunday and end on Saturday.
 */
auto byWeek(InputRange)(InputRange dates) pure nothrow
    if (isDateRange!InputRange)
{
    static struct ByWeek {
        InputRange r;
        @property bool empty() { return r.empty; }
        @property auto front() {
            return until!((Date a) => a.dayOfWeek == DayOfWeek.sat)
                         (r, OpenRight.no);
        }
        void popFront() {
            assert(!r.empty);
            r.popFront();
            while (!r.empty && r.front.dayOfWeek != DayOfWeek.sun)
                r.popFront();
        }
    }
    return ByWeek(dates);
}

unittest {
    auto weeks = datesInYear(2013).byWeek();
    assert(!weeks.empty);
    assert(equal(weeks.front, [
        Date(2013, 1, 1),   // tue
        Date(2013, 1, 2),   // wed
        Date(2013, 1, 3),   // thu
        Date(2013, 1, 4),   // fri
        Date(2013, 1, 5),   // sat
    ]));
    weeks.popFront();

    assert(!weeks.empty);
    assert(equal(weeks.front, [
        Date(2013, 1, 6),   // sun
        Date(2013, 1, 7),   // mon
        Date(2013, 1, 8),   // tue
        Date(2013, 1, 9),   // wed
        Date(2013, 1, 10),  // thu
        Date(2013, 1, 11),  // fri
        Date(2013, 1, 12),  // sat
    ]));
    weeks.popFront();

    assert(!weeks.empty);
    assert(weeks.front.front == Date(2013,1,13));
}


/// The number of columns per day in the formatted output.
enum ColsPerDay = 3;

/// The number of columns per week in the formatted output.
enum ColsPerWeek = 7 * ColsPerDay;


/**
 * Formats a range of weeks into a range of strings.
 *
 * Each day is formatted into the digit representation of the day of the month,
 * padded with spaces to fill up 3 characters.
 *
 * Parameters:
 *  weeks = A range of ranges of Dates, each inner range representing
 *          consecutive dates in a week.
 */
auto formatWeek(Range)(Range weeks) pure nothrow
    if (isInputRange!Range && isInputRange!(ElementType!Range) &&
        is(ElementType!(ElementType!Range) == Date))
{
    struct WeekStrings {
        Range r;
        @property bool empty() { return r.empty; }

        string front()
        out(s) { assert(s.length == ColsPerWeek); }
        body
        {
            auto buf = appender!string();

            // Insert enough filler to align the first day with its respective
            // day-of-week.
            assert(!r.front.empty);
            auto startDay = r.front.front.dayOfWeek;
            buf.put(spaces(ColsPerDay * startDay));

            // Format each day into its own cell and append to target string.
            string[] days = map!((Date d) => " %2d".format(d.day))(r.front)
                           .array;
            assert(days.length <= 7 - startDay);
            days.copy(buf);

            // Insert more filler at the end to fill up the remainder of the
            // week, if it's a short week (e.g. at the end of the month).
            if (days.length < 7 - startDay)
                buf.put(spaces(ColsPerDay * (7 - startDay - days.length)));

            return buf.data;
        }

        void popFront() {
            r.popFront();
        }
    }
    return WeekStrings(weeks);
}

unittest {
    auto jan2013 = datesInYear(2013)
        .byMonth().front  // pick January 2013 for testing purposes
        .byWeek()
        .formatWeek()
        .join("\n");

    assert(jan2013 ==
        "        1  2  3  4  5\n"~
        "  6  7  8  9 10 11 12\n"~
        " 13 14 15 16 17 18 19\n"~
        " 20 21 22 23 24 25 26\n"~
        " 27 28 29 30 31      "
    );
}


/**
 * Formats the name of a month centered on ColsPerWeek.
 */
string monthTitle(Month month) pure nothrow {
    static immutable string[] monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ];
    static assert(monthNames.length == 12);

    // Determine how many spaces before and after the month name we need to
    // center it over the formatted weeks in the month
    auto name = monthNames[month - 1];
    assert(name.length < ColsPerWeek);
    auto before = (ColsPerWeek - name.length) / 2;
    auto after = ColsPerWeek - name.length - before;

    return spaces(before) ~ name ~ spaces(after);
}

unittest {
    assert(monthTitle(Month.jan).length == ColsPerWeek);
}


/**
 * Formats a month.
 * Parameters:
 *  monthDays = A range of Dates representing consecutive days in a month.
 * Returns: A range of strings representing each line of the formatted month.
 */
auto formatMonth(Range)(Range monthDays)
    if (isInputRange!Range && is(ElementType!Range == Date))
in {
    assert(!monthDays.empty);
    assert(monthDays.front.day == 1);
} body {
    return chain(
        [ monthTitle(monthDays.front.month) ],
        monthDays.byWeek().formatWeek());
}

unittest {
    auto monthFmt = datesInYear(2013)
        .byMonth().front    // Pick January as a test case
        .formatMonth()
        .join("\n");

    assert(monthFmt ==
        "       January       \n"~
        "        1  2  3  4  5\n"~
        "  6  7  8  9 10 11 12\n"~
        " 13 14 15 16 17 18 19\n"~
        " 20 21 22 23 24 25 26\n"~
        " 27 28 29 30 31      "
    );
}


/**
 * Formats a range of months.
 * Parameters:
 *  months = A range of ranges, each inner range is a range of Dates in a
 *      month.
 * Returns:
 *  A range of ranges of formatted lines for each month.
 */
auto formatMonths(Range)(Range months) pure nothrow
    if (isInputRange!Range && is(ElementType!(ElementType!Range) == Date))
{
    return months.map!formatMonth;
}


/**
 * Horizontally pastes a forward range of rectangular blocks of characters.
 *
 * Each rectangular block is represented by a range of fixed-width strings. If
 * some blocks are longer than others, the shorter blocks are padded with
 * spaces at the bottom.
 *
 * Parameters:
 *  ror = A range of of ranges of fixed-width strings.
 *  sepWidth = Number of spaces to insert between each month.
 * Returns:
 *  A range of ranges of formatted lines for each month.
 */
auto pasteBlocks(Range)(Range ror, int sepWidth)
    if (isForwardRange!Range && is(ElementType!(ElementType!Range) : string))
{
    struct Lines {
        Range  ror;
        string sep;
        size_t[] colWidths;
        bool   _empty;

        this(Range _ror, string _sep) {
            ror = _ror;
            sep = _sep;
            _empty = ror.empty;

            // Store the widths of each column so that we can insert fillers if
            // one of the subranges run out of data prematurely.
            foreach (r; ror.save) {
                colWidths ~= r.empty ? 0 : r.front.length;
            }
        }

        @property bool empty() { return _empty; }

        @property auto front() {
            return
                // Iterate over ror and colWidths simultaneously
                zip(ror.save, colWidths)

                // Map each subrange to its front element, or empty fillers if
                // it's already empty.
                .map!(a => a[0].empty ? spaces(a[1]) : a[0].front)

                // Join them together to form a line
                .join(sep);
        }

        /// Pops an element off each subrange.
        void popFront() {
            assert(!empty);
            _empty = true;  // assume no more data after popping (we're lazy)
            foreach (ref r; ror) {
                if (!r.empty) {
                    r.popFront();
                    if (!r.empty)
                        _empty = false; // well, there's still data after all
                }
            }
        }
    }
    static assert(isInputRange!Lines);

    string separator = spaces(sepWidth);
    return Lines(ror, separator);
}

unittest {
    // Make a beautiful, beautiful row of months. How's that for a unittest? :)
    auto row = datesInYear(2013).byMonth().take(3)
              .formatMonths()
              .array()
              .pasteBlocks(1)
              .join("\n");
    assert(row ==
        "       January              February                March        \n"~
        "        1  2  3  4  5                  1  2                  1  2\n"~
        "  6  7  8  9 10 11 12   3  4  5  6  7  8  9   3  4  5  6  7  8  9\n"~
        " 13 14 15 16 17 18 19  10 11 12 13 14 15 16  10 11 12 13 14 15 16\n"~
        " 20 21 22 23 24 25 26  17 18 19 20 21 22 23  17 18 19 20 21 22 23\n"~
        " 27 28 29 30 31        24 25 26 27 28        24 25 26 27 28 29 30\n"~
        "                                             31                  "
    );
}


// The following block is a simple replacement of std.range.chunks to work
// around a limitation in its implementation in 2.063 and earlier, that does
// not allow it to be used with a non-sliceable range. This limitation has been
// lifted in 2.064, so this block is only compiled for 2.063 or earlier.
static if (__VERSION__ < 2064L) {
    auto chunks(Range)(Range r, size_t n) {
        struct Chunks {
            Range r;
            size_t n;

            @property bool empty() { return r.empty; }
            @property auto front() { return r.save.take(n); }
            void popFront() {
                size_t count = n;
                while (count-- > 0 && !r.empty)
                    r.popFront();
            }
        }
        return Chunks(r, n);
    }

    unittest {
        auto r = [1, 2, 3, 4, 5, 6, 7];
        auto c = r.chunks(3);
        assert(c.equal([[1,2,3],[4,5,6],[7]]));
    }
}


/**
 * Formats a year.
 * Parameters:
 *  year = Year to display calendar for.
 *  monthsPerRow = How many months to fit into a row in the output.
 * Returns: A range of strings representing the formatted year.
 */
auto formatYear(int year, int monthsPerRow)
{
    enum colSpacing = 1;

    return
        // Start by generating all dates for the given year
        datesInYear(year)

        // Group them by month
        .byMonth()

        // Group the months into horizontal rows
        .chunks(monthsPerRow)

        // Format each row
        .map!(r =>
                // By formatting each month
                r.formatMonths()
                 // Storing each month's formatting in a row buffer
                 .array()

                 // Horizontally pasting each respective month's lines together
                 .pasteBlocks(colSpacing)
                 .join("\n"))

        // Insert a blank line between each row
        .join("\n\n");
}


int main(string[] args) {
    // This is as simple as it gets: parse the year from the command-line:
    if (args.length < 2) {
        stderr.writeln("Please specify year");
        return 1;
    }
    int year = to!int(args[1]);

    // Print the calender
    enum MonthsPerRow = 3;
    writeln(formatYear(year, MonthsPerRow));

    return 0;
}

// vim:set sw=4 ts=4 et:
