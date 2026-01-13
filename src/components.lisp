(in-package #:cl-lubridate)

;;; Components
;;; wrappers around local-time accessors, but with R-like names and semantics.

(defun year (timestamp)
  (local-time:timestamp-year timestamp))

(defun month (timestamp)
  (local-time:timestamp-month timestamp))

(defun day (timestamp)
  (local-time:timestamp-day timestamp))

(defun mday (timestamp)
  (day timestamp))

(defun hour (timestamp)
  (local-time:timestamp-hour timestamp))

(defun minute (timestamp)
  (local-time:timestamp-minute timestamp))

(defun second (timestamp)
  (local-time:timestamp-second timestamp))

(defun wday (timestamp)
  "Day of week. Returns integer 1-7 (Sun-Sat? R is Sun=1).
   local-time:timestamp-day-of-week returns 0=Sunday, 6=Saturday.
   Lubridate defaults to 1=Sunday, 7=Saturday."
  (let ((wd (local-time:timestamp-day-of-week timestamp)))
    ;; 0->1, 6->7
    (1+ wd)))

(defun qday (timestamp)
  "Quarter of the year (1-4)."
  (ceiling (month timestamp) 3))

(defun dst (timestamp)
  "Returns boolean if DST is active."
  ;; local-time doesn't expose this directly on timestamp-subtimezone easily without timezone
  ;; but timestamp-maximum-offset etc exist.
  ;; Actually local-time:timestamp-maximize-part ... NO.
  ;; We need to decode with the timezone attached to the timestamp.
  ;; local-time:timestamp-subtimezone gives (offset dst-p abbrev).
  (multiple-value-bind (sec minute hour day month year wday dst-p tz)
      (local-time:decode-timestamp timestamp)
    (declare (ignore sec minute hour day month year wday tz))
    dst-p))

;;; Setters
;;; Implementing setf-expanders or methods that return a NEW timestamp (functional update) vs mutating?
;;; R's lubridate functions like year(x) <- 2020 MUTATE the object in place (conceptually in R).
;;; But in Lisp, local-time timestamps are immutable-ish (slots are read-only-ish?).
;;; Actually local-time timestamps are standard objects but considered immutable values?
;;; Let's check local-time. It has no writers exported.
;;; So we probably want functional update users or a wrapper object?
;;; "Backing Library: Use local-time as the backend for timestamp storage."
;;; If we want (setf (year x) 2020) to work, X must be mutable or we return a new value and the user must use it?
;;; Setf must modify the PLACE. If the place is a variable holding a timestamp, we can update the variable to a new timestamp.
;;; So (defun (setf year) (new-val timestamp)) ... wait, that doesn't modify the variable holding timestamp if it's passed by value?
;;; No, (setf (year x) y) expands effectively to (setf x (update-year x y)) if we define it right?
;;; No, standard (defun (setf year) (val obj)) expects OBJ to be mutable.
;;; If OBJ is a timestamp instance, we can't mutate it easily if local-time locks it down.
;;; BUT, we can make `cl-lubridate` return its own wrapper class if needed, OR just accept that local-time timestamps are immutable and
;;; provide `update-year` functional setters.
;;; HOWEVER, R users expect mutation or re-binding.
;;; Common Lisp setf of accessors implies mutation of the object.
;;; Let's check if we can mutate local-time timestamps.
;;; local-time:timestamp has slots day and nsec.
;;; Accessors like timestamp-year work by decoding. You can't just set year, you have to recalculate day/nsec.
;;; So, to support (setf (year ts) 2020), TS would need to be a mutable wrapper, OR we implement functional updates.
;;; BUT, standard CL `(setf (year place) val)` works if we define a setf expander that expands to `(setf place (update-year place val))`.
;;; That works if place is a variable.
;;; Let's implement that approach: Functional update under the hood of setf.

(defun update-timestamp (timestamp &key year month day hour minute second nsec)
  (multiple-value-bind (nsec-old sec-old min-old hour-old day-old month-old year-old wday dst-p tz)
      (local-time:decode-timestamp timestamp)
    (declare (ignore wday dst-p))
    (let ((args (list (or nsec nsec-old)
                      (or second sec-old)
                      (or minute min-old)
                      (or hour hour-old)
                      (or day day-old)
                      (or month month-old)
                      (or year year-old))))
      (if (integerp tz)
          (apply #'local-time:encode-timestamp (append args (list :offset tz :timezone local-time:+utc-zone+)))
          (apply #'local-time:encode-timestamp (append args (list :timezone tz)))))))

;;; Functional setf expander helper
(defmacro define-component-setf (accessor-name component-keyword)
  `(define-setf-expander ,accessor-name (place &environment env)
     (multiple-value-bind (vars vals store-vars writer-form reader-form)
         (get-setf-expansion place env)
       (let ((new-val (gensym "NEW-VAL"))
             (temp (gensym "TEMP-TS")))
         (values vars
                 vals
                 (list new-val)
                 `(let ((,temp ,reader-form))
                    (setq ,temp (update-timestamp ,temp ,',component-keyword ,new-val))
                    (let ((,(first store-vars) ,temp))
                      ,writer-form))
                 `(,',accessor-name ,reader-form))))))

(define-component-setf year :year)
(define-component-setf month :month)
(define-component-setf day :day)
(define-component-setf mday :day)
(define-component-setf hour :hour)
(define-component-setf minute :minute)
(define-component-setf second :second)

;; wday is read-only usually, changing it implies changing the day?
;; R allows wday(x) <- 1 (Move to next Sunday?).
;; That's complex logic. Let's defer "setting by weekday" for now or implement as:
;; Find the date in the same week with that weekday.
