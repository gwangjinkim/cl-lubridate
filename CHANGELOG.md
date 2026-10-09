# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See AGENTS.md
("Change Discipline") for how entries and commits are written.

## [Unreleased]

### Breaking
- **Dates and times are parsed and read in UTC by default** (decision D1,
  as in R's lubridate). New exported special `*default-tz*`
  (default `local-time:+utc-zone+`) is used by the parsers (`ymd`, `dmy`,
  `mdy`, `ymd-hms`, ...), `make-date`, the component accessors (`year`,
  `day`, `hour`, `wday`, ...), rounding and `force-tz`. Previously the
  machine's zone (`local-time:*default-timezone*`) was used, so the same
  code gave different days/hours on different machines and a midnight
  date could fall on the previous day.
  `with-timezone` now binds `*default-tz*` (and `local-time`'s default zone
  for printing). Code that relied on local interpretation should wrap it
  in `(with-timezone "Europe/Berlin" ...)` or set `*default-tz*`
  (topic: UTC default).
- `today` returns the current *calendar date* (system zone, as R's
  `today()`, or `tz` if given) at midnight in `*default-tz*`, so
  `(hour (today))` is 0 and `(day (today))` is today's date. It used to
  return a timestamp floored in the machine's zone (or a zoned timestamp
  when `tz` was given).

### Added
- `second` on a list now returns `(cl:second list)`. cl-lubridate's
  `second` shadows `cl:second`, so in any package that uses cl-lubridate
  (or cl-tidyverse) `(second '(a b c))` used to fail with "no applicable
  method"; now the shadowing is transparent (topic: CL shadowing).

### Fixed
- **Date parsers signalled a type error on missing values.**
  `ymd`, `dmy`, `mdy`, `ymd-hms`, `ymd-hm`, `ymd-h`, `dmy-hms` and
  `mdy-hms` now return `cl-vctrs-lite:*na*` for `NIL` or `*na*` input.
  cl-readr represents blank cells as `*na*`, so `(map 'vector #'ymd col)`
  over a date column with any gap used to fail (topic: NA support).

### Changed
- New dependency on `cl-vctrs-lite`, for the shared missing value `*na*`.
- Stopped tracking `build/` (53 files, 2.0M): the ASDF/Roswell compile
  cache that `make test` writes via `XDG_CACHE_HOME=$(PWD)/build`. It held
  compiled fasls, including Quicklisp internals and absolute local paths.
  `build/` is now in `.gitignore`; local files are untouched. Old copies
  remain in history (topic: repo hygiene).

### Tests
- New `parsing-missing-input-gives-na` (18 checks). Suite: 133/133 pass.
- New `second-on-lists-behaves-like-cl-second` (3 checks). Suite: 136/136.
- `parsing-hms` reads hours in UTC; `rounding-zoned` builds "23:50 in
  Paris" with `force-tz` instead of `with-tz`. New tests
  `dates-are-utc-regardless-of-machine-zone` (simulates a machine in
  America/Los_Angeles) and `with-timezone-rebinds-default-tz`.
