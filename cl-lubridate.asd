(defsystem "cl-lubridate"
  :version "0.1.0"
  :author ""
  :license ""
  :depends-on ("local-time"
               "cl-ppcre")
               ;; "cl-tibble") ;; Integration as requested
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "core")
                 (:file "components")
                 (:file "timezones")
                 (:file "arithmetic")
                 (:file "intervals")
                 (:file "rounding")
                 (:file "sugar")
                 (:file "parsing"))))
  :description "A Common Lisp port of R's lubridate package for date-time manipulation."
  :in-order-to ((test-op (test-op "cl-lubridate/tests"))))

(defsystem "cl-lubridate/tests"
  :author ""
  :license ""
  :depends-on ("cl-lubridate"
               "fiveam")
  :components ((:module "tests"
                :components
                ((:file "package")
                 (:file "main"))))
  :description "Test system for cl-lubridate"
  :perform (test-op (op c) (symbol-call :cl-lubridate-tests :run-tests)))
