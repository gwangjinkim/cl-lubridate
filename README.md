# cl-lubridate

> "Make dealing with dates a little bit easier."

`cl-lubridate` is a Common Lisp port of R's famous `lubridate` package. It provides a user-friendly, high-level API for date-time manipulation, built on top of the robust `local-time` library.

## Features

- **Intuitive Parsing**: `ymd`, `dmy`, `mdy`, and more.
- **Clock-time manipulation**: `(setf (year ts) 2025)` functional updates.
- **Time Zones**: `zoned-timestamp` objects that remember their zone.
- **Duration vs Period**: Exact seconds vs. calendrical time blocks.
- **Intervals**: Start/end spans with `%within%` checks.
- **Rounding**: `floor-date`, `ceiling-date`, `round-date`.
- **Lispy Idioms**: Reader macro `#d"2023-01-01"`, universal time interop, and more.

## Quick Start

```lisp
(ql:quickload :cl-lubridate)
(use-package :cl-lubridate)

;; Parsing
(defvar *ts* (ymd "2023-01-01"))

;; Components
(year *ts*) ; => 2023
(month *ts*) ; => 1

;; Functional Updates
(setf (month *ts*) 12) ; Returns new timestamp in December

;; Arithmetic
(time+ *ts* (months 1)) ; => Feb 1st (calendrical)
(time+ *ts* (ddays 1))  ; => Jan 2nd (exact 86400s)

;; Time Zones
(with-tz *ts* "America/New_York") ; Display in NY time

;; Rounding
(floor-date (ymd "2023-01-15") :month) ; => 2023-01-01

;; Literals (Enable Syntax)
(enable-lubridate-syntax)
(defvar *literal* #d"2023-01-01")
```

## Installation

Currently available via local-projects or soon on Ultralisp.

## License

MIT
