#lang racket
; Helper functions

(require threading (for-syntax racket/base syntax/parse))

; http://docs.racket-lang.org/syntax-parse-example/index.html?q=rec%2Fc#%28part._rec_c%29
(define-syntax-rule (rec/c t ctc)
  (letrec ([rec-ctc
            (let-syntax ([t (syntax-parser (_:id #'(recursive-contract rec-ctc)))])
              ctc)])
      rec-ctc))

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

;; each argument is a seperate argument on command line
(define/contract (run-command . lst)
  (->* () () #:rest (rec/c t (or/c string? (listof t))) boolean?) ; system returns a boolean
  (system (~> (flatten lst)
              (map (λ (x) (string-replace x " " "\\ ")) _)
              string-join)))

; Thanks https://stackoverflow.com/questions/47908137/checking-if-lists-share-one-or-more-elements-in-racket
(define (share-some-elements? . sets)
  (not (empty? (apply set-intersect sets))))

(define (quote-string-for-shell string)
  (string-replace string " " "\\ "))
