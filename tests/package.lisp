(defpackage #:cl-lubridate-tests
  (:use #:cl #:fiveam #:cl-lubridate)
  (:shadowing-import-from #:cl-lubridate #:second)
  (:export #:run-tests
           #:all-tests))
