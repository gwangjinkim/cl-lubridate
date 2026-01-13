# cl-lubridate

> "Make dealing with dates a little bit easier."

`cl-lubridate` is a Common Lisp port of R's `lubridate` package. It provides a user-friendly, high-level API for date-time manipulation, built on top of the robust `local-time` library.

## Table of Contents
- [Parsing](#parsing)
- [Components & Setters](#components--setters)
- [Arithmetic: Durations vs Periods](#arithmetic-durations-vs-periods)
- [Time Zones](#time-zones)
- [Intervals](#intervals)
- [Rounding](#rounding)
- [Lisp-Specific DSL & Macros](#lisp-specific-dsl--macros)
- [Iterators](#iterators)

---

## Parsing
Parsing is flexible and supports various formats (strings, dense numbers, etc.).

```lisp
(ymd "2023-01-15")        ; => #<TIMESTAMP 2023-01-15T00:00:00.000000Z>
(mdy "01/15/2023")        ; => Month-Day-Year
(dmy "15-01-2023")        ; => Day-Month-Year
(ymd-hms "20230115 12:34:56") ; Standard datetime
(ymd-hm "2023-01-15 12:34")   ; Year-Month-Day Hour:Minute
```

### Manual Construction
```lisp
(make-date :year 2024 :month 2 :day 29)
(make-datetime :year 2023 :month 1 :day 1 :hour 12 :tz "Europe/Paris")
```

---

## Components & Setters
Get or update specific parts of a timestamp. Setters are functional and return a *new* object.

```lisp
(defvar *ts* #d"2023-01-15")

(year *ts*)  ; => 2023
(month *ts*) ; => 1
(day *ts*)   ; => 15
(wday *ts*)  ; => 1 (Sunday)
(month-name *ts*) ; => "January"

;; Functional Setters
(setf (year *ts*) 2025)  ; Returns new timestamp in 2025
(setf (month *ts*) 12)    ; Returns new timestamp in December
```

---

## Arithmetic: Durations vs Periods
This is a key distinction from R's lubridate:
- **Durations**: Exact time spans measured in seconds (86400s per day).
- **Periods**: Calendrical time spans (e.g., "1 month" which might be 28, 30, or 31 days).

```lisp
;; Durations (prefixed with 'd')
(time+ (ymd "2023-01-01") (ddays 1)) ; Jan 2nd

;; Periods (standard names)
(time+ (ymd "2023-01-31") (months 1)) ; => Feb 28th (clipping behavior)

;; Convenience Aliases
(t+ *ts* (hours 5))
(t- *ts* (dminutes 30))
```

---

## Time Zones
Handled via `zoned-timestamp`, which wraps a UTC instant with a preferred timezone for display and access.

```lisp
(defvar *paris* (with-tz (now) "Europe/Paris"))
(hour *paris*) ; Returns the hour in Paris

;; force-tz: Keep the clock time but change the instant
(force-tz #d"2023-01-01 12:00:00" "America/New_York")
;; Interprets "12:00" as being in NY, not UTC.
```

---

## Intervals
Represent a span of time between two specific points.

```lisp
(defvar *vacation* (%--% (ymd "2023-07-01") (ymd "2023-07-15")))

(%within% (ymd "2023-07-05") *vacation*) ; => T
(int-overlaps *vacation* (%--% (ymd "2023-07-10") (ymd "2023-07-20"))) ; => T
```

---

## Rounding
```lisp
(floor-date (now) :month)    ; First day of current month
(ceiling-date (now) :year)   ; First day of next year
(round-date (now) :hour)     ; Nearest hour
```

---

## Lisp-Specific DSL & Macros

### Reader Macro
Enable concise literals for interactive development.
```lisp
(enable-lubridate-syntax)
(defvar *ts* #d"2023-01-01")
```

### `with-time` Destructuring
A powerful macro to grab multiple components at once.
```lisp
(with-time (now :year y :month m :day d :tz zone)
  (format t "Today is day ~A of month ~A in year ~A (~A)" d m y zone))
```

### `with-timezone` Scope
Set the default timezone dynamically for a block.
```lisp
(with-timezone "America/Los_Angeles"
  (hour (now))) ; returns LA hour
```

### Comparison Predicates
Convenient aliases that handle both standard and zoned timestamps.
`t<`, `t>`, `t<=`, `t>=`, `t=`
```lisp
(when (t< (yesterday) (today))
  (print "Time flows forward"))
```

### Universal Time Interop
```lisp
(to-universal-time (now))
(from-universal-time 3881452800)
```

---

## Iterators
Easily generate ranges of dates.

```lisp
;; Every Monday for 3 weeks
(map-dates (ymd "2023-01-02") (ymd "2023-01-23") (weeks 1) #'identity)
```

---

## Usage Scenarios

### Log Analysis
```lisp
(loop for line in logs
      for ts = (ymd-hms (extract-ts line))
      when (%within% ts (days-ago 7))
      collect ts)
```

### Business Reports
```lisp
(with-time (today :month m :year y)
  (generate-report :period (format nil "~A-~A" y m)))
```
