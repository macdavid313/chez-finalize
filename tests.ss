;;;; tests.ss
(import (chezscheme) (finalize))

(define-record-type (c-u8-array mk-c-u8-array c-u8-array?)
  (fields ptr len))

(define counts 0)

(define (report total)
  (display (format "~d c-u8-array allocated, ~d has been properly released.~%"
                   total counts )))

(define (free-c-u8-array array)
  (foreign-free (c-u8-array-ptr array))
  (set! counts (fx1+ counts)))

(define (make-c-u8-array lst)
  (let* ([len (length lst)]
         [ptr (foreign-alloc (fx* len (foreign-sizeof 'unsigned-8)))])
    (do ([lst lst (cdr lst)]
         [i 0 (fx1+ i)])
        ((fx=? i len))
      (foreign-set! 'unsigned-8 ptr i (car lst)))
    (finalize (mk-c-u8-array ptr len)
              free-c-u8-array)))

(make-c-u8-array (list 1 2 3 4 5))
(collect-rendezvous)
(report 1)

(set! counts 0)
(newline)
(time (do ([i 0 (fx1+ i)])
          ((fx=? i (expt 10 6)))
        (make-c-u8-array (list (random 256) (random 256) (random 256)))))
(newline)
(collect-rendezvous)
(report (expt 10 6))
