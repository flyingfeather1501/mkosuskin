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

;; run-command : ListOf String -> Void
;; each argument is a seperate argument on command line
(define (run-command . lst)
  (system (string-join (map quote-string-for-shell (flatten lst)))))

; Thanks https://stackoverflow.com/questions/47908137/checking-if-lists-share-one-or-more-elements-in-racket
(define (share-some-elements? . sets)
  (not (empty? (apply set-intersect sets))))

(define (quote-string-for-shell string)
  (string-replace string " " "\\ "))
