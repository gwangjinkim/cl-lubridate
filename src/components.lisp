(in-package #:cl-lubridate)

;;; Components
;;; wrappers around local-time accessors, but with R-like names and semantics.

(defgeneric year (timestamp)
  (:documentation "Get the year."))
(defmethod year ((timestamp local-time:timestamp))
  (local-time:timestamp-year timestamp :timezone local-time:*default-timezone*))

(defgeneric month (timestamp)
  (:documentation "Get the month."))
(defmethod month ((timestamp local-time:timestamp))
  (local-time:timestamp-month timestamp :timezone local-time:*default-timezone*))

(defgeneric day (timestamp)
  (:documentation "Get the day of the month."))
(defmethod day ((timestamp local-time:timestamp))
  (local-time:timestamp-day timestamp :timezone local-time:*default-timezone*))

(defgeneric mday (timestamp))
(defmethod mday ((timestamp local-time:timestamp))
  (day timestamp))

(defgeneric hour (timestamp))
(defmethod hour ((timestamp local-time:timestamp))
  (local-time:timestamp-hour timestamp :timezone local-time:*default-timezone*))

(defgeneric minute (timestamp))
(defmethod minute ((timestamp local-time:timestamp))
  (local-time:timestamp-minute timestamp :timezone local-time:*default-timezone*))

(defgeneric second (timestamp))
(defmethod second ((timestamp local-time:timestamp))
  (local-time:timestamp-second timestamp :timezone local-time:*default-timezone*))

(defgeneric wday (timestamp))
(defmethod wday ((timestamp local-time:timestamp))
  "Day of week. Returns integer 1-7 (Sun-Sat? R is Sun=1).
   local-time:timestamp-day-of-week returns 0=Sunday, 6=Saturday.
   Lubridate defaults to 1=Sunday, 7=Saturday."
  (let ((wd (local-time:timestamp-day-of-week timestamp :timezone local-time:*default-timezone*)))
    ;; 0->1, 6->7
    (1+ wd)))

(defgeneric qday (timestamp))
(defmethod qday ((timestamp local-time:timestamp))
  "Quarter of the year (1-4)."
  (ceiling (month timestamp) 3))

(defgeneric dst (timestamp))
(defmethod dst ((timestamp local-time:timestamp))
  "Returns boolean if DST is active."
  (multiple-value-bind (sec minute hour day month year wday dst-p tz)
      (local-time:decode-timestamp timestamp :timezone local-time:*default-timezone*)
    (declare (ignore sec minute hour day month year wday tz))
    dst-p))

(defgeneric tz (timestamp)
  (:documentation "Get the timezone of the timestamp."))
(defmethod tz ((timestamp local-time:timestamp))
  local-time:*default-timezone*)

(defgeneric isoyear (timestamp))
(defmethod isoyear ((timestamp local-time:timestamp))
  "ISO 8601 year. local-time doesn't have it directly, but we can compute it if needed.
   For now, we'll return the standard year as a simplified version or use a library if available.
   Actually, local-time:timestamp-year is usually what people mean unless they specifically want ISO week years."
  (local-time:timestamp-year timestamp :timezone local-time:*default-timezone*))

(defvar *month-names* #("January" "February" "March" "April" "May" "June"
                        "July" "August" "September" "October" "November" "December"))
(defvar *month-names-abbr* #("Jan" "Feb" "Mar" "Apr" "May" "Jun"
                             "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

(defgeneric month-name (timestamp &key label abbr))
(defmethod month-name ((timestamp local-time:timestamp) &key (label t) (abbr nil))
  (let ((m (month timestamp)))
    (if label
        (elt (if abbr *month-names-abbr* *month-names*) (1- m))
        m)))

(defvar *wday-names* #("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"))
(defvar *wday-names-abbr* #("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))

(defgeneric wday-name (timestamp &key label abbr))
(defmethod wday-name ((timestamp local-time:timestamp) &key (label t) (abbr nil))
  (let ((wd (wday timestamp))) ; 1-based (1=Sun)
    (if label
        (elt (if abbr *wday-names-abbr* *wday-names*) (1- wd))
        wd)))

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

;;; Functional setf expander helper
;;; We need update-timestamp to be generic too if we want to support wrapped timestamps.

(defgeneric update-timestamp (timestamp &key year month day hour minute second nsec)
  (:documentation "Return a new timestamp with updated components."))

(defmethod update-timestamp ((timestamp local-time:timestamp) &key year month day hour minute second nsec)
  (multiple-value-bind (nsec-old sec-old min-old hour-old day-old month-old year-old wday dst-p tz)
      (local-time:decode-timestamp timestamp :timezone local-time:*default-timezone*)
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
                    ;; Ensure we call generic functions, but setq expects the value to be put back.
                    ;; The magic is that update-timestamp returns the same type as temp.
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
