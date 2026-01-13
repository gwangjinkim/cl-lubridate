(in-package #:cl-lubridate)

;;; Arithmetic: Durations and Periods

;;; Generic Functions for Arithmetic
(defgeneric add (a b)
  (:documentation "Add two time objects."))

(defgeneric sub (a b)
  (:documentation "Subtract two time objects."))

;; Aliases
(defun time+ (a b) (add a b))
(defun time- (a b) (sub a b))

(defun t+ (a b) (add a b))
(defun t- (a b) (sub a b))

;;; Duration: Exact time in seconds
(defclass duration ()
  ((seconds :initarg :seconds :accessor duration-seconds :initform 0))
  (:documentation "A duration represents an exact length of time in seconds."))

(defmethod print-object ((obj duration) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "~As" (duration-seconds obj))))

(defun make-duration (seconds)
  (make-instance 'duration :seconds seconds))

;; Duration Constructors
(defun dseconds (x) (make-duration x))
(defun dminutes (x) (make-duration (* x 60)))
(defun dhours (x)   (make-duration (* x 3600)))
(defun ddays (x)    (make-duration (* x 86400)))
(defun dweeks (x)   (make-duration (* x 604800)))
(defun dyears (x)   (make-duration (* x 31536000))) ; 365 days

;;; Period: Calendrical time (years, months, days, etc.)
(defclass period ()
  ((years   :initarg :years   :accessor period-years   :initform 0)
   (months  :initarg :months  :accessor period-months  :initform 0)
   (weeks   :initarg :weeks   :accessor period-weeks   :initform 0)
   (days    :initarg :days    :accessor period-days    :initform 0)
   (hours   :initarg :hours   :accessor period-hours   :initform 0)
   (minutes :initarg :minutes :accessor period-minutes :initform 0)
   (seconds :initarg :seconds :accessor period-seconds :initform 0)
   (nsecs   :initarg :nsecs   :accessor period-nsecs   :initform 0))
  (:documentation "A period represents a calendrical span of time (e.g. 1 month)."))

(defmethod print-object ((obj period) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "~@[~Ay ~]~@[~Am ~]~@[~Aw ~]~@[~Ad ~]~@[~Ah ~]~@[~Am ~]~@[~As~]"
            (if (zerop (period-years obj)) nil (period-years obj))
            (if (zerop (period-months obj)) nil (period-months obj))
            (if (zerop (period-weeks obj)) nil (period-weeks obj))
            (if (zerop (period-days obj)) nil (period-days obj))
            (if (zerop (period-hours obj)) nil (period-hours obj))
            (if (zerop (period-minutes obj)) nil (period-minutes obj))
            (if (zerop (period-seconds obj)) nil (period-seconds obj)))))

(defun make-period (&key (years 0) (months 0) (weeks 0) (days 0) (hours 0) (minutes 0) (seconds 0) (nsecs 0))
  (make-instance 'period :years years :months months :weeks weeks :days days
                 :hours hours :minutes minutes :seconds seconds :nsecs nsecs))

;; Period Constructors (Plural)
(defun seconds (x) (make-period :seconds x))
(defun minutes (x) (make-period :minutes x))
(defun hours (x)   (make-period :hours x))
(defun days (x)    (make-period :days x))
(defun weeks (x)   (make-period :weeks x))
(defun months (x)  (make-period :months x))
(defun years (x)   (make-period :years x))

;;; Arithmetic Methods

;; Duration Arithmetic
(defmethod add ((a duration) (b duration))
  (make-duration (+ (duration-seconds a) (duration-seconds b))))

(defmethod sub ((a duration) (b duration))
  (make-duration (- (duration-seconds a) (duration-seconds b))))

;; Period Arithmetic
(defmethod add ((a period) (b period))
  (make-period :years   (+ (period-years a) (period-years b))
               :months  (+ (period-months a) (period-months b))
               :weeks   (+ (period-weeks a) (period-weeks b))
               :days    (+ (period-days a) (period-days b))
               :hours   (+ (period-hours a) (period-hours b))
               :minutes (+ (period-minutes a) (period-minutes b))
               :seconds (+ (period-seconds a) (period-seconds b))
               :nsecs   (+ (period-nsecs a) (period-nsecs b))))

;; Timestamp Arithmetic Implementation
(defun timestamp+ (ts quantity unit)
  (local-time:timestamp+ ts quantity unit))

;; Timestamp + Duration
(defmethod add ((ts local-time:timestamp) (d duration))
  (local-time:timestamp+ ts (floor (duration-seconds d)) :sec))

(defmethod add ((d duration) (ts local-time:timestamp))
  (add ts d))

(defmethod sub ((ts local-time:timestamp) (d duration))
  (local-time:timestamp- ts (floor (duration-seconds d)) :sec))

;; Timestamp + Period
(defmethod add ((ts local-time:timestamp) (p period))
  ;; We apply units from largest to smallest roughly, but local-time:timestamp+ handles one unit.
  ;; We can chain them.
  (let ((res ts))
    (unless (zerop (period-years p))   (setf res (local-time:timestamp+ res (period-years p) :year)))
    (unless (zerop (period-months p))  (setf res (local-time:timestamp+ res (period-months p) :month)))
    ;; Weeks are days * 7 for timestamp+? local-time doesn't have :week.
    (unless (zerop (period-weeks p))   (setf res (local-time:timestamp+ res (* (period-weeks p) 7) :day)))
    (unless (zerop (period-days p))    (setf res (local-time:timestamp+ res (period-days p) :day)))
    (unless (zerop (period-hours p))   (setf res (local-time:timestamp+ res (period-hours p) :hour)))
    (unless (zerop (period-minutes p)) (setf res (local-time:timestamp+ res (period-minutes p) :minute)))
    (unless (zerop (period-seconds p)) (setf res (local-time:timestamp+ res (period-seconds p) :sec)))
    (unless (zerop (period-nsecs p))   (setf res (local-time:timestamp+ res (period-nsecs p) :nsec)))
    res))

(defmethod add ((p period) (ts local-time:timestamp))
  (add ts p))

;; Timestamp - Timestamp -> Duration
(defmethod sub ((a local-time:timestamp) (b local-time:timestamp))
  (make-duration (local-time:timestamp-difference a b)))

;; Support generic accessors for Period/Duration is optional but nice.
;; For now, slots are accessors.
