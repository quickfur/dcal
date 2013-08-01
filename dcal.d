/**
 * D calendar: an example of how using component-style programming with ranges
 * simplifies a complex task into manageable pieces. The task is, given a year,
 * to produce a range of lines representing a nicely laid-out calendar of that
 * year.
 */

import std.algorithm;
import std.conv;
import std.datetime;
import std.functional;
import std.range;
import std.stdio;


/**
 * Returns: a range of dates in a given year.
 */
auto datesInYear(int year) {
    static struct DateRange {
        private int year;   /// so that we know when to stop
        this(int _year) {
            year = _year;
            front = Date(year, 1, 1);
        }

        /// Generate dates only up to the end of the starting year
        @property bool empty() { return front.year() > year; }

        /// Current date
        Date front;

        /// Generate the next date in the year.
        void popFront() { front += dur!"days"(1); }
    }
    static assert(isInputRange!DateRange);

    return DateRange(year);
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
 * Chunks an input range by the given element attribute.
 *
 * This function takes an input range, and splits it up into subranges that
 * contain elements that share the same value of a given attribute. This
 * attribute is defined by the compile-time parameter attrFun, which maps an
 * element of the input range to any value type that can be compared with ==.
 *
 * The resulting range will contain subranges that contain adjacent elements
 * from the original range that map to the same value.
 *
 * Parameters:
 *  attrFun = A function that maps each element to the attribute to be
 *      grouped by.
 *  r = The range to be chunked.
 *
 * Returns: a range of ranges in which all elements in a given subrange share
 * the same attribute with each other.
 */
auto chunkBy(alias attrFun, Range)(Range r)
    if (isInputRange!Range &&
        is(typeof(
            unaryFun!attrFun(ElementType!Range.init) ==
            unaryFun!attrFun(ElementType!Range.init)
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
    }
    return ChunkBy(r);
}

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

    auto byX = chunkBy!"a[0]"(range);
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

    auto byY = chunkBy!"a[1]"(range);
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
 * Returns: a range of ranges, each subrange of which contains dates for the
 * same month.
 */
auto byMonth(InputRange)(InputRange dates)
    if (isDateRange!InputRange)
{
    static struct ByMonth {
        private Date curDate;
        this(InputRange range) {
            empty = range.empty;
        }
        bool empty;
        auto front() {
            struct MonthlyDates {
            }
        }
    }
    return ByMonth(dates);
}


/**
 * Chunks a given input range of dates by week.
 * Returns: a range of ranges, each subrange of which contains dates for the
 * same week.
 */
auto byWeek(InputRange)(InputRange dates)
    if (isDateRange!InputRange)
{
    // TBD
}

int main(string[] args) {
    // This is as simple as it gets: parse the year from the command-line:
    if (args.length < 2) {
        stderr.writeln("Please specify year");
        return 1;
    }
    int year = to!int(args[1]);

    // Then generate the calendar, which returns a range of lines to be
    // printed out.
    writeln(datesInYear(year));

    return 0;
}

// vim:set sw=4 ts=4 et:
