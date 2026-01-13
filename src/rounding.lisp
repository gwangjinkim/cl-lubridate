(in-package #:cl-lubridate)

;;; Rounding functions: floor-date, ceiling-date, round-date

(defun %get-timezone (date)
  (if (typep date 'zoned-timestamp)
      (zoned-timestamp-timezone date)
      local-time:*default-timezone*))

(defun %get-impl (date)
  (if (typep date 'zoned-timestamp)
      (zoned-timestamp-impl date)
      date))

(defun %wrap-result (date impl)
  (if (typep date 'zoned-timestamp)
      (make-instance 'zoned-timestamp :impl impl :timezone (zoned-timestamp-timezone date))
      impl))

(defun floor-date (date unit)
  "Round DATE down to the nearest boundary of UNIT.
   UNIT can be :nsec, :second, :minute, :hour, :day, :week, :month, :year."
  (let* ((impl (%get-impl date))
         (tz (%get-timezone date))
         (res impl))
    (setf res
          (case unit
            (:nsec    impl)
            (:second  (local-time:timestamp-minimize-part impl :nsec :timezone tz))
            (:minute  (local-time:timestamp-minimize-part impl :sec :timezone tz))
            (:hour    (local-time:timestamp-minimize-part impl :minute :timezone tz))
            (:day     (local-time:timestamp-minimize-part impl :hour :timezone tz))
            (:week    (let ((wd (local-time:timestamp-day-of-week impl :timezone tz)))
                        ;; local-time: 0=Sunday. R lubridate usually floors to Sunday?
                        (let ((floored-day (local-time:timestamp-minimize-part impl :hour :timezone tz)))
                          (local-time:timestamp- floored-day wd :day))))
            (:month   (local-time:timestamp-minimize-part impl :day :timezone tz))
            (:year    (local-time:timestamp-minimize-part impl :month :timezone tz))
            (t (error "Unknown unit: ~A" unit))))
    (%wrap-result date res)))

(defun %on-boundary-p (date unit)
  "Check if date is exactly on the boundary of UNIT."
  (local-time:timestamp= (%get-impl date) (%get-impl (floor-date date unit))))

(defun ceiling-date (date unit &key (change-on-boundary nil))
  "Round DATE up to the nearest boundary of UNIT.
   If CHANGE-ON-BOUNDARY is true, even dates on the boundary are moved to the next."
  (let ((floored (floor-date date unit)))
    (if (and (not change-on-boundary)
             (local-time:timestamp= (%get-impl date) (%get-impl floored)))
        date
        (let ((inc-unit (case unit 
                          (:nsec :nsec) 
                          (:second :sec) 
                          (:minute :minute) 
                          (:hour :hour) 
                          (:day :day) 
                          (:week :day)
                          (:month :month)
                          (:year :year)
                          (t (error "Unknown unit: ~A" unit))))
              (qty (if (eq unit :week) 7 1)))
          (%wrap-result date (local-time:timestamp+ (%get-impl floored) qty inc-unit))))))

(defun round-date (date unit)
  "Round DATE to the nearest boundary of UNIT."
  (let* ((prev (floor-date date unit))
         (next (ceiling-date date unit))
         (d-prev (local-time:timestamp-difference (%get-impl date) (%get-impl prev)))
         (d-next (local-time:timestamp-difference (%get-impl next) (%get-impl date))))
    (if (<= d-prev d-next)
        prev
        next)))
