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
                                    (parse-integer clean :start 6 :end 8)))) ;; ambiguous d/m
             (:dym (setf nums (list (parse-integer clean :start 0 :end 2)
                                    (parse-integer clean :start 2 :end 6)
                                    (parse-integer clean :start 6 :end 8))))
             (:myd (setf nums (list (parse-integer clean :start 0 :end 2)
                                    (parse-integer clean :start 2 :end 6)
                                    (parse-integer clean :start 6 :end 8)))))
           (setf n 3))
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
      (ecase pattern
        (:ymd (setf year (first nums) month (second nums) day (third nums)))
        (:dmy (setf day (first nums) month (second nums) year (third nums)))
        (:mdy (setf month (first nums) day (second nums) year (third nums)))
        (:ydm (setf year (first nums) day (second nums) month (third nums)))
        (:dym (setf day (first nums) year (second nums) month (third nums)))
        (:myd (setf month (first nums) year (second nums) day (third nums))))

      ;; Handle 2-digit years (naive 1900/2000 heuristic if needed, or just let local-time handle it?)
      ;; Lubridate defaults: "68" -> 2068, "69" -> 1969.
      ;; For now, let's assume 4 digit years from user or pass as-is if local-time handles it?
      ;; local-time:encode-timestamp expects full year.
      (when (< year 100)
        (setf year (+ 2000 year))) ;; Naive 2000s assumption for now

      ;; Assign H M S if available
      (when (> n 3) (setf hour (nth 3 nums)))
      (when (> n 4) (setf minute (nth 4 nums)))
      (when (> n 5) (setf second (nth 5 nums)))

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
  "Parse date with Year-Month-Day Hour:Minute:Second format.
   Actually ymd() handles extra components by default, but this makes it explicit."
  (ymd x))
