(in-package #:cl-lubridate)

;;; Time zone handling
;;; ZonedTimestamp wrapper to carry timezone information for display/access.

(defclass zoned-timestamp ()
  ((impl :initarg :impl :accessor zoned-timestamp-impl
         :documentation "The underlying local-time:timestamp (UTC).")
   (timezone :initarg :timezone :accessor zoned-timestamp-timezone
             :documentation "The local-time:timezone to use for display/access."))
  (:documentation "A timestamp object that carries its own timezone for display and component access."))

(defmethod print-object ((obj zoned-timestamp) stream)
  "Pretty print for zoned-timestamp in format <YYYY-MM-DD HH:MM:SS ZONE>."
  (let ((local-time:*default-timezone* (zoned-timestamp-timezone obj)))
    (multiple-value-bind (nsec sec minute hour day month year wday dst-p tz-obj offset zone-name)
        (local-time:decode-timestamp (zoned-timestamp-impl obj) :timezone (zoned-timestamp-timezone obj))
      (declare (ignore nsec wday dst-p tz-obj offset))
      (format stream "<~D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D ~A>"
              year month day hour minute sec zone-name))))

;;; Wrap accessors for zoned-timestamp
(defmethod year ((tz zoned-timestamp))
  (local-time:timestamp-year (zoned-timestamp-impl tz)
                             :timezone (zoned-timestamp-timezone tz)))

(defmethod month ((tz zoned-timestamp))
  (local-time:timestamp-month (zoned-timestamp-impl tz)
                              :timezone (zoned-timestamp-timezone tz)))

(defmethod day ((tz zoned-timestamp))
  (local-time:timestamp-day (zoned-timestamp-impl tz)
                            :timezone (zoned-timestamp-timezone tz)))

(defmethod hour ((tz zoned-timestamp))
  (local-time:timestamp-hour (zoned-timestamp-impl tz)
                             :timezone (zoned-timestamp-timezone tz)))

(defmethod minute ((tz zoned-timestamp))
  (local-time:timestamp-minute (zoned-timestamp-impl tz)
                               :timezone (zoned-timestamp-timezone tz)))

(defmethod second ((tz zoned-timestamp))
  (local-time:timestamp-second (zoned-timestamp-impl tz)
                               :timezone (zoned-timestamp-timezone tz)))

(defmethod wday ((tz zoned-timestamp))
  (1+ (local-time:timestamp-day-of-week (zoned-timestamp-impl tz)
                                        :timezone (zoned-timestamp-timezone tz))))

(defmethod dst ((tz zoned-timestamp))
  (multiple-value-bind (sec minute hour day month year wday dst-p zone)
      (local-time:decode-timestamp (zoned-timestamp-impl tz)
                                   :timezone (zoned-timestamp-timezone tz))
    (declare (ignore sec minute hour day month year wday zone))
    dst-p))

(defmethod tz ((tz zoned-timestamp))
  (zoned-timestamp-timezone tz))

(defmethod isoyear ((tz zoned-timestamp))
  (local-time:timestamp-year (zoned-timestamp-impl tz)
                             :timezone (zoned-timestamp-timezone tz)))

(defmethod month-name ((tz zoned-timestamp) &key (label t) (abbr nil))
  (let ((m (month tz)))
    (if label
        (elt (if abbr *month-names-abbr* *month-names*) (1- m))
        m)))

(defmethod wday-name ((tz zoned-timestamp) &key (label t) (abbr nil))
  (let ((wd (wday tz)))
    (if label
        (elt (if abbr *wday-names-abbr* *wday-names*) (1- wd))
        wd)))

;;; Update-timestamp for zoned-timestamp
(defmethod update-timestamp ((tz zoned-timestamp) &key year month day hour minute second nsec)
  ;; Decode using stored timezone
  (multiple-value-bind (nsec-old sec-old min-old hour-old day-old month-old year-old wday dst-p zone)
      (local-time:decode-timestamp (zoned-timestamp-impl tz)
                                   :timezone (zoned-timestamp-timezone tz))
    (declare (ignore wday dst-p))
    (let ((args (list (or nsec nsec-old)
                      (or second sec-old)
                      (or minute min-old)
                      (or hour hour-old)
                      (or day day-old)
                      (or month month-old)
                      (or year year-old))))
      ;; Encode back using the same timezone
      (let ((new-impl 
              (if (integerp zone)
                  (apply #'local-time:encode-timestamp (append args (list :offset zone :timezone local-time:+utc-zone+)))
                  (apply #'local-time:encode-timestamp (append args (list :timezone zone))))))
        (make-instance 'zoned-timestamp :impl new-impl :timezone (zoned-timestamp-timezone tz))))))


;;; API: with-tz and force-tz

(defvar *timezones-loaded* nil)

(defun ensure-timezones-loaded ()
  (unless *timezones-loaded*
    (let ((sys-zoneinfo #p"/usr/share/zoneinfo/"))
      (when (probe-file sys-zoneinfo)
        (setf local-time::*default-timezone-repository-path* sys-zoneinfo)))
    (local-time:reread-timezone-repository)
    (setf *timezones-loaded* t)))

(defun find-timezone (tz)
  "Resolve TZ to a local-time:timezone. TZ can be string or timezone object."
  (typecase tz
    (local-time::timezone tz)
    (string 
     (let ((zone (local-time:find-timezone-by-location-name tz)))
       (unless zone
         (ensure-timezones-loaded)
         (setf zone (local-time:find-timezone-by-location-name tz)))
       (or zone (error "Timezone not found: ~A" tz))))
    (t (error "Unknown timezone specifier: ~A" tz))))

(defun with-tz (time tz)
  "Return a zoned-timestamp pointing to the same instant as TIME, but with TZ as display zone."
  (let ((zone (find-timezone tz)))
    (if (typep time 'zoned-timestamp)
        (make-instance 'zoned-timestamp :impl (zoned-timestamp-impl time) :timezone zone)
        (make-instance 'zoned-timestamp :impl time :timezone zone))))

(defun force-tz (time tz)
  "Return a zoned-timestamp with the same clock time as TIME, but interpreted in TZ.
   This changes the instant."
  (let ((zone (find-timezone tz))
        (src-zone (if (typep time 'zoned-timestamp)
                      (zoned-timestamp-timezone time)
                      local-time:*default-timezone*))
        (impl (if (typep time 'zoned-timestamp)
                  (zoned-timestamp-impl time)
                  time)))
    ;; Decode in source zone
    (multiple-value-bind (nsec sec minute hour day month year wday dst-p)
        (local-time:decode-timestamp impl :timezone src-zone)
      (declare (ignore wday dst-p))
      ;; Encode in target zone
      (let ((new-impl (local-time:encode-timestamp nsec sec minute hour day month year :timezone zone)))
        (make-instance 'zoned-timestamp :impl new-impl :timezone zone)))))
