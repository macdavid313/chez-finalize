;;;; finalizer
(library (finalize)
  (export finalize set-collect-limit!)
  (import (chezscheme))
  
  (define %finalizers (make-weak-eq-hashtable))

  (define %collect-limit 0)
  
  (define garbage-pool (make-guardian))

  (define (set-collect-limit! limit)
    (unless (and (fixnum? limit) (fx>=? limit 1))
      (assertion-violationf 'set-%collect-limit "Invalid limit: ~a" limit))
    (set! %collect-limit limit))

  (define (finalize object free)
    (unless (and (procedure? free)
                 (logbit? 1 (procedure-arity-mask free)))
      (assertion-violationf 'finalize "~a is not a unary procedure" free))
    (unless (hashtable-ref %finalizers object #f)
      ;; when the entry doesn't exist,
      ;; send the object to guardian and store the free function
      (garbage-pool object)
      (hashtable-set! %finalizers object free))
    object)

  (collect-request-handler
   (lambda ()
     (collect)
     (do ([x (garbage-pool) (garbage-pool)]
          [i 0 (fx1+ i)])
         ((or (not x)
              (and (not (fxzero? %collect-limit))
                   (fx=? i %collect-limit))))
       (let ([free (hashtable-ref %finalizers x #f)])
         (when free (free x))))))

  ) ;; end of library
