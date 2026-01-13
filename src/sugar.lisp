(in-package #:cl-lubridate)

;;; Universal Time Interoperability
(defun to-universal-time (ts)
  "Convert cl-lubridate timestamp or zoned-timestamp to CL universal time (UTC)."
  (let ((impl (%get-impl ts)))
    (local-time:timestamp-to-universal impl)))

(defun from-universal-time (ut &optional tz)
  "Create a timestamp from CL universal time. If TZ is provided, returns a zoned-timestamp."
  (let ((ts (local-time:universal-to-timestamp ut)))
    (if tz
        (with-tz ts tz)
        ts)))

;;; Dynamic Context
(defmacro with-timezone (tz &body body)
  "Execute BODY with local-time:*default-timezone* bound to TZ."
  `(let ((local-time:*default-timezone* (find-timezone ,tz)))
     ,@body))

;;; Iterators
(defun map-dates (start end period func)
  "Map FUNC over dates from START to END (exclusive), incrementing by PERIOD."
  (let ((current start)
        (results nil))
    (loop while (local-time:timestamp< (%get-impl current) (%get-impl end))
          do (push (funcall func current) results)
             (setf current (add current period)))
    (nreverse results)))

;;; Reader Macro
(defun %date-reader (stream subchar arg)
  (declare (ignore subchar arg))
  (let ((str (read stream t nil t)))
    (unless (stringp str)
      (error "#d expects a string literal, e.g., #d\"2023-01-01\""))
    ;; Try parsing as ymd-hms or ymd
    (handler-case
        (ymd-hms str)
      (error () (ymd str)))))

(defun enable-lubridate-syntax ()
  "Enable #d\"...\" reader macro for date literals."
  (set-dispatch-macro-character #\# #\d #'%date-reader))

;;; Relative Helpers
(defun tomorrow (&optional tz)
  "Get the date for tomorrow."
  (add (today tz) (days 1)))

(defun yesterday (&optional tz)
  "Get the date for yesterday."
  (sub (today tz) (days 1)))

;;; Comparison Aliases
(defgeneric t< (a b))
(defmethod t< (a b) (local-time:timestamp< (%get-impl a) (%get-impl b)))

(defgeneric t> (a b))
(defmethod t> (a b) (local-time:timestamp> (%get-impl a) (%get-impl b)))

(defgeneric t<= (a b))
(defmethod t<= (a b) (local-time:timestamp<= (%get-impl a) (%get-impl b)))

(defgeneric t>= (a b))
(defmethod t>= (a b) (local-time:timestamp>= (%get-impl a) (%get-impl b)))

(defgeneric t= (a b))
(defmethod t= (a b) (local-time:timestamp= (%get-impl a) (%get-impl b)))

;;; Destructuring Macro
(defmacro with-time ((ts &key year month day hour minute second nsec wday tz) &body body)
  "Bind components of TS to local variables.
   Example: (with-time (now :year y :month m) (format t \"~A/~A\" m y))"
  (let ((ts-var (gensym "TS")))
    `(let ((,ts-var ,ts))
       (let ,(remove nil
                     (list (when year `(,year (year ,ts-var)))
                           (when month `(,month (month ,ts-var)))
                           (when day `(,day (day ,ts-var)))
                           (when hour `(,hour (hour ,ts-var)))
                           (when minute `(,minute (minute ,ts-var)))
                           (when second `(,second (second ,ts-var)))
                           (when nsec `(,nsec (local-time:nsec-of (%get-impl ,ts-var))))
                           (when wday `(,wday (wday ,ts-var)))

                           (when tz `(,tz (tz ,ts-var)))))
         ,@body))))

;;; Pretty printing - ensuring we can read back?
;;; Common Lisp convention for readable objects is #. or a custom macro.
;;; If we want (read-from-string (format nil "~S" ts)) to work, we need to print it nicely.
;;; However, #<...> is standard for non-readable.
;;; We will stick to the reader macro for user convenience.
