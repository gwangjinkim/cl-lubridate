(in-package #:cl-lubridate)

;;; Core definitions will go here.
;;; This file provides the "hard core" of generic functions and classes.

(defvar *default-tz* local-time:+utc-zone+
  "Time zone in which plain (unzoned) timestamps are created and read:
parsing (YMD & co.), MAKE-DATE, component accessors (YEAR, DAY, HOUR, ...)
and rounding. Defaults to UTC, like R's lubridate, so results do not depend
on the machine's zone. Rebind it with WITH-TIMEZONE. Zoned timestamps
(WITH-TZ) always use their own zone.")
