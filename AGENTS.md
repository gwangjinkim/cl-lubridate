# AGENTS.md - cl-lubridate Development Plan

## Milestones

### M0: Infrastructure
-   **Goal**: Initialize the project structure and testing framework.
-   **Tasks**:
    -   Create `cl-lubridate.asd`.
    -   Create `package.lisp` and `core.lisp` (the hard core).
    -   Set up `tests/` directory with a test runner (e.g., `fiveam` or `parachute` to match other `cl-*` libs).

### M1: Core Parsing (Simple)
-   **Goal**: Parse standard date strings into timestamps.
-   **Tasks**:
    -   Implement `ymd()`, `mdy()`, `dmy()`.
    -   Implement `ymd-hms()`.
    -   Support "2023-01-01", "2023/01/01", "20230101".
-   **Tests**: Test with various string formats.

### M2: Timestamp Components
-   **Goal**: Read and modify parts of a date.
-   **Tasks**:
    -   Implement accessors: `year`, `month`, `day`, `wday`, `hour`, `minute`, `second`.
    -   Implement setters (`setf` expanders) for the above.
    -   Ensure 1-based indexing for months/days to match R/human expectations (Time conversion notes: `local-time` is 1-based for day/month, check strictness).

### M3: Time Zones
-   **Goal**: Handle time zone collection and manipulation.
-   **Tasks**:
    -   Implement `with-tz(x tz)`: Return same instant, different timezone.
    -   Implement `force-tz(x tz)`: Return same clock time, different instant.
    -   Helpers for `utc`, `sys-time`.

### M4: Arithmetic (Durations & Periods)
-   **Goal**: Implement the two types of time spans.
-   **Tasks**:
    -   Define `duration` class (seconds).
    -   Define `period` class (years, months, days, etc.).
    -   Implement constructors: `days(n)`, `ddays(n)`, `months(n)`, `weeks(n)`.
    -   Implement arithmetic generic functions: `timestamp + period`, `timestamp + duration`.

### M5: Intervals
-   **Goal**: Range checking.
-   **Tasks**:
    -   Define `interval` class (start, end).
    -   Implement `interval(start, end)`.
    -   Implement `%within%` (or `within-interval-p`) to check if a date falls in an interval.

### M6: Rounding
-   **Goal**: Snap dates to nearest unit.
-   **Tasks**:
    -   Implement `floor-date`, `ceiling-date`, `round-date`.
    -   Support string units like "month", "week", "5 minutes".

### M7: Integration (cl-tibble)
-   **Goal**: Make `cl-lubridate` objects print nicely in tibbles.
-   **Tasks**:
    -   Define `cl-tibble` formatting methods for timestamps (if not already handled) and especially for `duration`, `period`, and `interval` objects.
    -   Ensure tibble columns display useful types (e.g., `<drtn>`, `<prid>`).

### M8: Polish & DSL
-   **Goal**: Final cleanup and syntactic sugar.
-   **Tasks**:
    -   Review API consistency.
    -   Add any "lispier" macros if helpful (e.g., `date-case`?).
    -   Documentation strings.

## Extensibility Note
The `core.lisp` file should define the classes and generic functions. Extensions should add methods. This ensures the "hard core" remains stable while new units or parsers can be added in separate files.
