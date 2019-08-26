# chez-finalize

[![Build Status](https://travis-ci.com/macdavid313/chez-finalize.svg?branch=master)](https://travis-ci.com/macdavid313/chez-finalize)

`finalize` facility for Chez Scheme.

## APIs

This library exports only 2 APIs, `finalize` and `set-collect-limit!`. **APIs might be changed in the future.**

### finalize

procedure: (finalize object free)\
returns: the given object\
libraries: (finalize)

Basically, `finalize` creates a hook that is executed after a given object has been reclaimed by the garbage collector. `object` is a Scheme object, `free` is a procedure that takes only one argument. When collections happen, `free` procedure will be called on `object`.

### set-collect-limit!

procedure: (set-collect-limit! limit)\
returns: unspecified\
libraries: (finalize)

`set-collect-limit!` specifies how many objects will be "released" during a single collect. `limit` must be a non-negative fixnum; when 0 is give, it means no limit at all.

## Example

Suppose we have written definitions to represent C byte arrays:

```scheme
(define-record-type (c-u8-array mk-c-u8-array c-u8-array?)
  ;; ptr is the C pointer heading to the array
  ;; len is the array's length
  (fields ptr len))
```

Now we want to construct `c-u8-array` from a list:

```scheme
(define (make-c-u8-array lst)
  (let* ([len (length lst)]
         [ptr (foreign-alloc (fx* (foreign-sizeof 'unsigned-8)))])
    (do ([lst lst (cdr lst)]
         [i 0 (fx1+ i)])
        ((fx=? i len) (mk-c-u8-array ptr len))
      (foreign-set! 'unsigned-8 ptr i (car lst)))))

(define array (make-c-u8-array (list 1 2 3)))
```

To properly "destroy" a `c-u8-array` object, Chez Scheme's GC will release everything from its heap once the object it proven to be inaccessible. However, it only release `ptr` from heap -- **it has no idea that it should also release the memory we allocated**, e.g.:

```scheme
(foreign-free (c-u8-array-ptr array))
```

So it's the case where we should use `finalize`:

```scheme
(define (free-c-u8-array array)
  (foreign-free (c-u8-array-ptr array))
  ;; to demostrate, display some information
  (display (format "Memory @~x has been properly released.~%" (c-u8-array-ptr array))))

(define (make-c-u8-array lst)
  (let* ([len (length lst)]
         [ptr (foreign-alloc (fx* (foreign-sizeof 'unsigned-8)))])
    (do ([lst lst (cdr lst)]
         [i 0 (fx1+ i)])
        ((fx=? i len))
      (foreign-set! 'unsigned-8 ptr i (car lst)))
    (finalize (mk-c-u8-array ptr len)
              free-c-u8-array)))
```

By `finalize`, now the GC will know to call `free-c-u8-array` when collecting a `c-u8-array` object. Now if you run this code in your REPL:

```scheme
;;; allocate 1000,000 c-u8-array objects and immediately drop it at each time
(do ([i 0 (fx1+ i)])
    ((fx=? i (expt 10 6)))
  (make-c-u8-array (list (random 256) (random 256) (random 256))))
;;; massive outputs e.g. "Memory @1A6AE155C70 has been properly released."
```
