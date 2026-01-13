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
