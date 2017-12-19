#lang racket
; Helper functions

(provide (all-defined-out))

(define (path-replace path from to #:all [all? #t])
  (string->path (string-replace (path->string path) from to #:all? all?)))
(define (path-basename path)
  (path-replace path #rx".*/" ""))

(define (path-contains? path contained)
  (string-contains? (path->string path) contained))

(define (path-prefix? path prefix)
  (string-prefix? (path->string path) prefix))

(define (path-suffix? path suffix)
  (string-suffix? (path->string path) suffix))

(define (run-command . lst)
  (system (string-join (flatten lst))))
