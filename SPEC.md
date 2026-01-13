# SPEC.md - cl-lubridate

> "Make dealing with dates a little bit easier."

## 1. Philosophy
`cl-lubridate` aims to be the standard date-time manipulation library for the `cl-tidyverse` ecosystem. It mirrors the API of the R `lubridate` package, providing a consistent, user-friendly interface for parsing, manipulating, and computing with dates and times.

It adheres to the following principles:
-   **User-Centric**: Default behavior should be what the user expects (DWIM).
-   **Consistent**: Similar functions should share similar signatures and behaviors.
-   **Robust**: Handle edge cases (leap years, DST) correctly.
-   **Extensible**: Built on top of `local-time` but provides a higher-level abstraction.

## 2. Architecture & Dependencies

### Backend
-   **Primary**: `local-time` (The de facto standard for rigorous date/time in CL).
-   **Integration**: `cl-tibble` (For printing and column support).

### Data Structures
We will define wrapper classes or use `local-time:timestamp` directly where appropriate, but likely we need our own types for:
-   `Period`: Human time units (e.g., "1 month", "2 days").
-   `Duration`: Exact time spans in seconds.
-   `Interval`: A span of time with a specific start and end.

## 3. Core API Specification

### 3.1 Parsing
Flexible parsers that handle heterogenous input (strings, numbers).
-   `ymd(x)`, `ydm(x)`, `mdy(x)`, `myd(x)`, `dmy(x)`, `dym(x)`
-   `ymd-hms(x)`, `ymd-hm(x)`, `ymd-h(x)`
-   `make-date(year month day)`
-   `make-datetime(year month day hour minute second tz)`

### 3.2 Components (Accessors & Setters)
Getters and `setf` methods for timestamp components.
-   `year(x)`, `isoyear(x)`, `epiyear(x)`
-   `month(x)` (returns integer), `month-name(x)` ? (R has `label = TRUE`)
-   `day(x)` (day of month), `mday(x)`
-   `wday(x)` (day of week), `qday(x)` (quarter)
-   `hour(x)`, `minute(x)`, `second(x)`
-   `tz(x)`: Time zone.
-   `dst(x)`: Boolean.

### 3.3 Arithmetic: Periods vs Durations
R's distinction is critical:
-   **Durations**: Exact seconds.
    -   `ddays(x)`, `dhours(x)`, `dminutes(x)`, `dseconds(x)`, `dweeks(x)`, `dyears(x)`
    -   Representation: Seconds (rational/float).
-   **Periods**: Human units (respect DST and leap years).
    -   `days(x)`, `hours(x)`, `minutes(x)`, `seconds(x)`, `weeks(x)`, `years(x)`, `months(x)`
    -   Representation: A structure storing `{years, months, days, seconds}`.

Operations:
-   `timestamp + period` (Uses calendar arithmetic).
-   `timestamp + duration` (Uses exact seconds arithmetic).

### 3.4 Intervals
-   `interval(start end)`: Creates an interval.
-   `%within% (date interval)`: Check if date is inside interval (infix equivalent macro or function `within-interval-p`).
-   `int-start(x)`, `int-end(x)`, `int-length(x)`.

### 3.5 Time Zones
-   `with-tz(time tz)`: Change the display time zone (instant remains the same).
-   `force-tz(time tz)`: Change the underlying instant to match the clock time in the new time zone.

### 3.6 Rounding
-   `floor-date(x unit)`
-   `ceiling-date(x unit)`
-   `round-date(x unit)`
    -   Unit examples: "month", "year", "5 mins".

## 4. Implementation Details
-   **Package**: `cl-lubridate`
-   **Core**: `core.lisp` should contain the fundamental CLOS definitions and generic functions to ensure extensibility.
-   **Safety**: Validations for invalid dates.
