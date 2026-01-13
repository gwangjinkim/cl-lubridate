(in-package #:cl-lubridate-tests)

(def-suite :cl-lubridate-tests
  :description "The master suite of all cl-lubridate tests.")

(in-suite :cl-lubridate-tests)

(defun run-tests ()
  (run! :cl-lubridate-tests))

(test dummy-test
  (is (equal 1 1)))

(test parsing-ymd
  (let ((ts (ymd "2023-01-01")))
    (is (= 2023 (local-time:timestamp-year ts)))
    (is (= 1 (local-time:timestamp-month ts)))
    (is (= 1 (local-time:timestamp-day ts))))
  (let ((ts (ymd "2023/02/03")))
    (is (= 2023 (local-time:timestamp-year ts)))
    (is (= 2 (local-time:timestamp-month ts)))
    (is (= 3 (local-time:timestamp-day ts))))
  (let ((ts (ymd "20230304")))
    (is (= 2023 (local-time:timestamp-year ts)))
    (is (= 3 (local-time:timestamp-month ts)))
    (is (= 4 (local-time:timestamp-day ts)))))

(test parsing-dmy
  (let ((ts (dmy "01-02-2023")))
    (is (= 2023 (local-time:timestamp-year ts)))
    (is (= 2 (local-time:timestamp-month ts)))
    (is (= 1 (local-time:timestamp-day ts)))))

(test parsing-mdy
  (let ((ts (mdy "02-01-2023")))
    (is (= 2023 (local-time:timestamp-year ts)))
    (is (= 2 (local-time:timestamp-month ts)))
    (is (= 1 (local-time:timestamp-day ts)))))

(test parsing-hms
  (let ((ts (ymd-hms "2023-01-01 12:30:45")))
    (is (= 12 (local-time:timestamp-hour ts)))
    (is (= 30 (local-time:timestamp-minute ts)))
    (is (= 45 (local-time:timestamp-second ts)))))

(test components-accessors
  (let ((ts (ymd-hms "2023-10-31 12:34:56")))
    (is (= 2023 (year ts)))
    (is (= 10 (month ts)))
    (is (= 31 (day ts)))
    (is (= 31 (mday ts)))
    (is (= 12 (hour ts)))
    (is (= 34 (minute ts)))
    (is (= 56 (second ts)))
    ;; 2023-10-31 is a Tuesday.
    ;; local-time: 0=Sunday, 1=Monday, 2=Tuesday.
    ;; cl-lubridate: 1=Sunday, 2=Monday, 3=Tuesday.
    (is (= 3 (wday ts))) 
    (is (= 4 (qday ts)))))

(test components-setters
  (let ((ts (ymd "2023-01-01")))
    ;; Test user modification of variable
    (setf (year ts) 2024)
    (is (= 2024 (year ts)))
    
    (setf (month ts) 2)
    (is (= 2 (month ts)))
    
    (setf (day ts) 28)
    (is (= 28 (day ts)))
    
    (setf (hour ts) 10)
    (is (= 10 (hour ts)))
    
    ;; Test logic with valid changes
    (setf (month ts) 1)
    (setf (day ts) 31)
    ;; Setting month to 2 for Jan 31 matches strict local-time behavior (fail)
    ;; So we won't test invalid dates here until we decide on a rollover strategy.
    ;; (setf (month ts) 2)
    ))

(test timezones-basics
  (let ((local-time:*default-timezone* local-time:+utc-zone+))
    (let ((ts (ymd-hms "2023-01-01 12:00:00")))
      ;; Default is UTC now.
      ;; with-tz should change display hour.
      ;; UTC+1 (CET)
      (let ((cet (with-tz ts "Europe/Paris")))
        (is (= 2023 (year cet)))
        ;; 12:00 UTC is 13:00 CET
        (is (= 13 (hour cet)))
        (is (= 12 (hour ts))) ;; Original unchanged
        
        ;; Force-tz should keep clock time (12:00) but change instant
        (let ((forced (force-tz ts "Europe/Paris")))
          (is (= 12 (hour forced)))
          ;; Instant should contain offset. 12:00 CET is 11:00 UTC.
          (is (not (local-time:timestamp= (zoned-timestamp-impl forced) ts)))
          (is (= 11 (local-time:timestamp-hour (zoned-timestamp-impl forced) :timezone local-time:+utc-zone+))))))))

(test zoned-timestamp-accessors
  (let ((local-time:*default-timezone* local-time:+utc-zone+))
    (let* ((ts (ymd-hms "2023-06-01 12:00:00"))
           (zts (with-tz ts "America/New_York")))
      ;; 12:00 UTC is 08:00 EDT
      (is (= 8 (hour zts)))
      (is (= 6 (month zts)))
      (is (= 2023 (year zts))))))

(test arithmetic-duration
  (let ((ts (ymd-hms "2023-01-01 00:00:00")))
    (is (= (local-time:timestamp-to-unix (time+ ts (dseconds 60)))
           (+ (local-time:timestamp-to-unix ts) 60)))
    (is (= (local-time:timestamp-to-unix (time+ ts (dhours 1)))
           (+ (local-time:timestamp-to-unix ts) 3600)))
    (is (= (local-time:timestamp-to-unix (time- ts (dminutes 1)))
           (- (local-time:timestamp-to-unix ts) 60)))
    
    (let ((diff (time- (time+ ts (dhours 1)) ts)))
      (is (typep diff 'duration))
      (is (= 3600 (slot-value diff 'seconds))))))

(test arithmetic-period
  (let ((ts (ymd-hms "2023-01-01 00:00:00")))
    ;; Add 1 month
    (let ((ts2 (time+ ts (months 1))))
      (is (= 2 (month ts2)))
      (is (= 2023 (year ts2))))
    
    ;; Add 1 year
    (let ((ts3 (time+ ts (years 1))))
      (is (= 2024 (year ts3))))
    
    ;; Chained period
    (let ((p (add (months 1) (days 1))))
      (let ((ts4 (time+ ts p)))
        (is (= 2 (month ts4)))
        (is (= 2 (day ts4)))))))

(test arithmetic-rollover
  (let ((ts (ymd "2023-01-31")))
    ;; Jan 31 + 1 month -> Feb 28 (or 29) or March?
    ;; Local-time timestamp+ simply increments unit.
    ;; Local-time timestamp+ behavior:
    ;; Adding 1 month to Jan 31 results in Feb 28 (clipped to end of month), 
    ;; NOT rolling over to March.
    (let ((res (time+ ts (months 1))))
      (is (= 2 (month res)))
      (is (= 28 (day res))))))

(test intervals-basic
  (let ((s (ymd "2023-01-01"))
        (e (ymd "2023-01-10")))
    (let ((int (%--% s e)))
      (is (typep int 'interval))
      (is (local-time:timestamp= s (int-start int)))
      (is (local-time:timestamp= e (int-end int)))
      (is (= (* 9 86400) (int-length int)))
      
      ;; %within%
      (is (%within% (ymd "2023-01-01") int))
      (is (%within% (ymd "2023-01-05") int))
      (is (not (%within% (ymd "2023-01-10") int))) ; half-open
      (is (not (%within% (ymd "2022-12-31") int))))))

(test intervals-overlaps
  (let ((i1 (%--% (ymd "2023-01-01") (ymd "2023-01-10")))
        (i2 (%--% (ymd "2023-01-05") (ymd "2023-01-15")))
        (i3 (%--% (ymd "2023-01-10") (ymd "2023-01-20")))
        (i4 (%--% (ymd "2023-01-15") (ymd "2023-01-25"))))
    (is (int-overlaps i1 i2))
    (is (int-overlaps i2 i3))
    (is (not (int-overlaps i1 i3))) ; Touching at boundary is not overlap
    (is (not (int-overlaps i1 i4)))))

(test rounding-basics
  (let ((ts (ymd-hms "2023-01-15 12:34:56")))
    ;; Floor
    (let ((f-month (floor-date ts :month)))
      (is (= 1 (month f-month)))
      (is (= 1 (day f-month)))
      (is (= 0 (hour f-month))))
    
    (let ((f-year (floor-date ts :year)))
      (is (= 2023 (year f-year)))
      (is (= 1 (month f-year)))
      (is (= 1 (day f-year))))
    
    ;; Ceiling
    (let ((c-month (ceiling-date ts :month)))
      (is (= 2 (month c-month)))
      (is (= 1 (day c-month))))
    
    ;; Round
    (let ((r1 (round-date (ymd "2023-01-10") :month)))
      (is (= 1 (month r1))))
    (let ((r2 (round-date (ymd "2023-01-20") :month)))
      (is (= 2 (month r2))))))

(test rounding-zoned
  (let* ((ts (with-tz (ymd-hms "2023-01-01 23:50:00") "Europe/Paris")))
    ;; 23:50 Paris is fine. Ceiling to day should be next day.
    (let ((c (ceiling-date ts :day)))
      (is (= 2 (day c)))
      (is (= 0 (hour c)))
      (is (typep c 'zoned-timestamp)))))

(test integration-missing-api
  (let ((ts (ymd-hms "2023-01-15 12:34:56")))
    (is (string= "January" (month-name ts)))
    (is (string= "Jan" (month-name ts :abbr t)))
    (is (string= "Sunday" (wday-name (ymd "2023-01-01")))) ; 2023-01-01 was Sunday
    (is (string= "Sun" (wday-name (ymd "2023-01-01") :abbr t)))
    
    (is (typep (tz ts) 'local-time::timezone))
    (is (= 2023 (isoyear ts)))
    
    ;; Parsers
    (let ((ts2 (ymd-hm "2023-01-15 12:34")))
      (is (= 12 (hour ts2)))
      (is (= 34 (minute ts2))))
    
    (let ((ts3 (make-date :year 2024 :month 2 :day 29)))
      (is (= 2024 (year ts3)))
      (is (= 29 (day ts3))))
    
    (let ((ts4 (make-datetime :year 2023 :month 1 :day 1 :tz "Europe/Paris")))
      ;; Use internal symbol for test verification if not exported
      (is (string= "Europe/Paris" (local-time::timezone-name (tz ts4)))))))

(test printing-polish
  (let ((zts (make-datetime :year 2023 :month 1 :day 1 :hour 12 :tz "Europe/Paris")))
    (let ((s (with-output-to-string (stream)
               (print-object zts stream))))
      ;; Check for format <YYYY-MM-DD HH:MM:SS ZONE>
      (is (ppcre:scan "<2023-01-01 12:00:00 [A-Z]+>" s)))))

(test sugar-api
  (let ((n (now)))
    (is (typep n 'local-time:timestamp)))
  (let ((z (now "UTC")))
    (is (typep z 'zoned-timestamp)))
  (let ((t-day (today)))
    (is (= 0 (hour t-day)))
    (is (= 0 (minute t-day)))))

(test lispy-sugar
  ;; Universal Time
  (let* ((ts (ymd "2023-01-01"))
         (ut (to-universal-time ts)))
    (is (integerp ut))
    (is (local-time:timestamp= ts (from-universal-time ut))))
  
  ;; Iterators
  (let* ((start (ymd "2023-01-01"))
         (end (ymd "2023-01-04"))
         (dates (map-dates start end (days 1) #'identity)))
    (is (= 3 (length dates)))
    (is (= 1 (day (nth 0 dates))))
    (is (= 2 (day (nth 1 dates))))
    (is (= 3 (day (nth 2 dates)))))
  
  ;; Dynamic context
  (with-timezone "Europe/Paris"
    (let ((ts (ymd-hms "2023-01-01 12:00:00")))
      ;; Should be 12:00 in Paris
      (is (= 12 (hour ts)))))
  
  ;; Reader Macro
  (enable-lubridate-syntax)
  (let ((ts (read-from-string "#d\"2023-01-01\"")))
    (is (= 2023 (year ts)))
    (is (= 1 (month ts)))
    (is (= 1 (day ts)))))





