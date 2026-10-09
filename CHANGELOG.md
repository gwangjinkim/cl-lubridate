# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See AGENTS.md
("Change Discipline") for how entries and commits are written.

## [Unreleased]

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
