(in-package #:cl-lubridate)

;;; Intervals: A span of time with a specific start and end.

(defclass interval ()
  ((start :initarg :start :accessor int-start
          :documentation "The start of the interval (inclusive).")
   (end   :initarg :end :accessor int-end
          :documentation "The end of the interval (exclusive)."))
  (:documentation "Represents a half-open interval [start, end)."))

(defmethod print-object ((obj interval) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "from ~A to ~A" (int-start obj) (int-end obj))))

(defun make-interval (start end)
  "Create an interval. If start or end are not timestamps, we might want to coerce them."
  (make-instance 'interval :start start :end end))

;; R-style constructor
(defun %--% (start end)
  (make-interval start end))

;;; Accessors
(defun int-length (int)
  "Returns the length of the interval in seconds."
  (local-time:timestamp-difference (int-end int) (int-start int)))

;;; Comparison / Inclusion
(defgeneric %within% (item interval)
  (:documentation "Check if item is within the interval."))

(defmethod %within% (item (int interval))
  "Default method if item is a timestamp."
  (let ((start (int-start int))
        (end (int-end int)))
    (and (local-time:timestamp<= start item)
         (local-time:timestamp< item end))))

(defmethod %within% ((item zoned-timestamp) (int interval))
  "Support zoned-timestamps by using their underlying impl."
  (%within% (zoned-timestamp-impl item) int))

(defun int-overlaps (int1 int2)
  "Check if two intervals overlap."
  (let ((s1 (int-start int1))
        (e1 (int-end int1))
        (s2 (int-start int2))
        (e2 (int-end int2)))
    ;; Overlap if NOT (e1 <= s2 OR e2 <= s1)
    (not (or (local-time:timestamp<= e1 s2)
             (local-time:timestamp<= e2 s1)))))
