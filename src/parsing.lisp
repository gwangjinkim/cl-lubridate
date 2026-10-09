(in-package #:cl-lubridate)

;;; Basic tokens for date parsing
;;; We loosely follow the ymd/dmy patterns.

(defun parse-date-components (string pattern)
  "Parse STRING according to PATTERN (e.g., :ymd, :dmy, :mdy).
   Returns (values year month day hour minute second)."
  ;; This is a simplified implementation. Real lubridate uses C++ parsers that are very robust.
  ;; We will use regexes to find numbers and assign them based on the pattern.
  
  ;; Extract all number sequences
  (let* ((matches (cl-ppcre:all-matches-as-strings "\\d+" string))
         (nums (mapcar #'parse-integer matches))
         (n (length nums)))
    
    ;; Handle dense formats (e.g. "20230101") if we didn't get enough parts
    (when (< n 3)
      (let ((clean (apply #'concatenate 'string matches)))
        (cond
          ((= (length clean) 8)
           ;; Assume 4-2-2 or 2-2-4 or 2-4-2 depending on pattern
           ;; But Y usually takes 4 digits.
           (when (keywordp pattern)
             (ecase pattern
               (:ymd (setf nums (list (parse-integer clean :start 0 :end 4)
                                      (parse-integer clean :start 4 :end 6)
                                      (parse-integer clean :start 6 :end 8))))
               (:dmy (setf nums (list (parse-integer clean :start 0 :end 2)
                                      (parse-integer clean :start 2 :end 4)
                                      (parse-integer clean :start 4 :end 8))))
               (:mdy (setf nums (list (parse-integer clean :start 0 :end 2)
                                      (parse-integer clean :start 2 :end 4)
                                      (parse-integer clean :start 4 :end 8))))
               (:ydm (setf nums (list (parse-integer clean :start 0 :end 4)
                                      (parse-integer clean :start 4 :end 6)
                                      (parse-integer clean :start 6 :end 8))))
               (:dym (setf nums (list (parse-integer clean :start 0 :end 2)
                                      (parse-integer clean :start 2 :end 6)
                                      (parse-integer clean :start 6 :end 8))))
               (:myd (setf nums (list (parse-integer clean :start 0 :end 2)
                                      (parse-integer clean :start 2 :end 6)
                                      (parse-integer clean :start 6 :end 8))))))
           (setf n (length nums)))
          ((= (length clean) 6)
           ;; Assume 2-2-2
           (setf nums (list (parse-integer clean :start 0 :end 2)
                            (parse-integer clean :start 2 :end 4)
                            (parse-integer clean :start 4 :end 6)))
           (setf n 3)))))

    (unless (>= n 3)
      (error "Cannot parse date from ~S: found fewer than 3 numbers." string))
    
    (let (year month day hour minute second)
      ;; Assign Y M D
      (if (listp pattern)
          (loop for p in pattern
                for val in nums
                do (case p
                     (:year (setf year val))
                     (:month (setf month val))
                     (:day (setf day val))
                     (:hour (setf hour val))
                     (:minute (setf minute val))
                     (:second (setf second val))))
          (ecase pattern
            (:ymd (setf year (first nums) month (nth 1 nums) day (third nums)))
            (:dmy (setf day (first nums) month (nth 1 nums) year (third nums)))
            (:mdy (setf month (first nums) day (nth 1 nums) year (third nums)))
            (:ydm (setf year (first nums) day (nth 1 nums) month (third nums)))
            (:dym (setf day (first nums) year (nth 1 nums) month (third nums)))
            (:myd (setf month (first nums) year (nth 1 nums) day (third nums)))))

      ;; Handle 2-digit years (naive 1900/2000 heuristic if needed, or just let local-time handle it?)
      ;; Lubridate defaults: "68" -> 2068, "69" -> 1969.
      ;; For now, let's assume 4 digit years from user or pass as-is if local-time handles it?
      ;; local-time:encode-timestamp expects full year.
      (when (< year 100)
        (setf year (+ 2000 year))) ;; Naive 2000s assumption for now

      ;; Assign H M S if available
      ;; Assign H M S if available (only if not already assigned by list pattern)
      (unless hour (when (> n 3) (setf hour (nth 3 nums))))
      (unless minute (when (> n 4) (setf minute (nth 4 nums))))
      (unless second (when (> n 5) (setf second (nth 5 nums))))

      (values year month day (or hour 0) (or minute 0) (or second 0)))))

(defun %make-timestamp-from-components (year month day hour minute second)
  (local-time:encode-timestamp 0 second minute hour day month year
                               :timezone *default-tz*))

;;; Parsing the user-facing way, like R's lubridate (decision D2):
;;;  - X may be one value or a vector/list of values; a sequence gives a
;;;    simple-vector of results, so (ymd column) works on a whole column.
;;;  - Missing input (NIL or cl-vctrs-lite:*na*, which cl-readr produces for
;;;    blank cells) gives *na*.
;;;  - Input that cannot be parsed gives *na*, and one DATE-PARSE-FAILURE
;;;    warning is signalled per call ("2 failed to parse"). To make
;;;    failures fatal: (handler-bind ((date-parse-failure #'error)) ...).

(define-condition date-parse-failure (warning)
  ((count :initarg :count :reader date-parse-failure-count)
   (inputs :initarg :inputs :reader date-parse-failure-inputs
           :documentation "The inputs that failed, in order (at most 10)."))
  (:report (lambda (c stream)
             (format stream "~d failed to parse~@[: ~{~s~^, ~}~]~:[~;, ...~]."
                     (date-parse-failure-count c)
                     (date-parse-failure-inputs c)
                     (> (date-parse-failure-count c)
                        (length (date-parse-failure-inputs c)))))))

(defun %missing-input-p (x)
  (or (null x) (cl-vctrs-lite:na-p x)))

(defun %parse-dates (x parse-one)
  "Apply PARSE-ONE to X (a value or a non-string sequence of values),
mapping missing input to *NA* and parse errors to *NA* plus one
DATE-PARSE-FAILURE warning for the whole call."
  (let ((failures '())
        (n-failed 0))
    (flet ((one (e)
             (if (%missing-input-p e)
                 cl-vctrs-lite:*na*
                 (handler-case (funcall parse-one e)
                   (error ()
                     (incf n-failed)
                     (when (< (length failures) 10) (push e failures))
                     cl-vctrs-lite:*na*)))))
      (let ((result (if (and (typep x 'sequence)
                             (not (stringp x))
                             (not (null x))) ; NIL is a missing value, not ()
                        (map 'simple-vector #'one x)
                        (one x))))
        (when (plusp n-failed)
          (warn 'date-parse-failure :count n-failed :inputs (nreverse failures)))
        result))))

(defmacro define-date-parser (name pattern &optional doc)
  `(defun ,name (x)
     ,(format nil "~@[~a~%~]Parse X (a string, or a sequence of strings) with pattern ~(~s~).
Missing input gives *NA*; unparseable input gives *NA* and a
DATE-PARSE-FAILURE warning." doc pattern)
     (%parse-dates x (lambda (s)
                       (multiple-value-bind (y m d h min sec)
                           (parse-date-components s ',pattern)
                         (%make-timestamp-from-components y m d h min sec))))))

(define-date-parser ymd :ymd "Parse date with Year-Month-Day format.")
(define-date-parser dmy :dmy "Parse date with Day-Month-Year format.")
(define-date-parser mdy :mdy "Parse date with Month-Day-Year format.")
(define-date-parser ymd-hms (:year :month :day :hour :minute :second)
  "Parse year-month-day hour:minute:second.")
(define-date-parser ymd-hm (:year :month :day :hour :minute))
(define-date-parser ymd-h (:year :month :day :hour))
(define-date-parser dmy-hms (:day :month :year :hour :minute :second))
(define-date-parser mdy-hms (:month :day :year :hour :minute :second))

(defun make-date (&key (year 1970) (month 1) (day 1))
  (local-time:encode-timestamp 0 0 0 0 day month year :timezone *default-tz*))

(defun make-datetime (&key (year 1970) (month 1) (day 1) (hour 0) (minute 0) (second 0) (nsec 0) (tz "UTC"))
  (let ((zone (find-timezone tz)))
    (with-tz (local-time:encode-timestamp nsec second minute hour day month year :timezone zone) zone)))

(defun now (&optional tz)
  "Get the current time. If TZ is provided, returns a zoned-timestamp."
  (if tz
      (with-tz (local-time:now) tz)
      (local-time:now)))

(defun today (&optional tz)
  "Current date, like R's today(): the calendar date in the system time
zone (or in TZ if given), returned as a timestamp at midnight in
*DEFAULT-TZ*, so (hour (today)) is 0 and (day (today)) is today's date."
  (multiple-value-bind (nsec sec minute hour day month year)
      (local-time:decode-timestamp (local-time:now)
                                   :timezone (if tz
                                                 (find-timezone tz)
                                                 local-time:*default-timezone*))
    (declare (ignore nsec sec minute hour))
    (make-date :year year :month month :day day)))

(defun here ()
  "Get current time in system's local timezone."
  (with-tz (local-time:now) local-time:*default-timezone*))
