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
  (local-time:encode-timestamp 0 second minute hour day month year))

(defun ymd (x)
  "Parse date with Year-Month-Day format."
  (multiple-value-bind (y m d h min s) (parse-date-components x :ymd)
    (%make-timestamp-from-components y m d h min s)))

(defun dmy (x)
  "Parse date with Day-Month-Year format."
  (multiple-value-bind (y m d h min s) (parse-date-components x :dmy)
    (%make-timestamp-from-components y m d h min s)))

(defun mdy (x)
  "Parse date with Month-Day-Year format."
  (multiple-value-bind (y m d h min s) (parse-date-components x :mdy)
    (%make-timestamp-from-components y m d h min s)))

(defun ymd-hms (x)
  "Parse year-month-day hour:minute:second."
  (multiple-value-bind (y m d h min s) (parse-date-components x '(:year :month :day :hour :minute :second))
    (%make-timestamp-from-components y m d h min s)))

(defun ymd-hm (x)
  (multiple-value-bind (y m d h min s) (parse-date-components x '(:year :month :day :hour :minute))
    (%make-timestamp-from-components y m d h min s)))

(defun ymd-h (x)
  (multiple-value-bind (y m d h min s) (parse-date-components x '(:year :month :day :hour))
    (%make-timestamp-from-components y m d h min s)))

(defun dmy-hms (x)
  (multiple-value-bind (y m d h min s) (parse-date-components x '(:day :month :year :hour :minute :second))
    (%make-timestamp-from-components y m d h min s)))

(defun mdy-hms (x)
  (multiple-value-bind (y m d h min s) (parse-date-components x '(:month :day :year :hour :minute :second))
    (%make-timestamp-from-components y m d h min s)))

(defun make-date (&key (year 1970) (month 1) (day 1))
  (local-time:encode-timestamp 0 0 0 0 day month year))

(defun make-datetime (&key (year 1970) (month 1) (day 1) (hour 0) (minute 0) (second 0) (nsec 0) (tz "UTC"))
  (let ((zone (find-timezone tz)))
    (with-tz (local-time:encode-timestamp nsec second minute hour day month year :timezone zone) zone)))
