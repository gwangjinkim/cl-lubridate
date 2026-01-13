(in-package #:cl-lubridate-tests)

(def-suite :cl-lubridate-tests
  :description "The master suite of all cl-lubridate tests.")

(in-suite :cl-lubridate-tests)

(defun run-tests ()
  (run! :cl-lubridate-tests))

(test dummy-test
  (is (equal 1 1)))
