#lang racket
(require threading
         "helper.rkt")


; orig, target : path?
; ratio : number?
(define (resize-vips orig target ratio)
  (run-command "vips resize"
               (path->string orig)
               (path->string target)
               (number->string (exact->inexact ratio)))
  (delete-file orig))

; orig, target : path?
; size : string?
(define (resize-im orig target size)
  (run-command "convert -resize"
               size
               (path->string orig)
               (path->string target))
  (delete-file orig))

(define (get-@-size string)
  (~> (string-replace string #rx".*@" "")
      (string-replace _ #rx"x.*" "")
      (string->number _)))

(define (resize-@nx path)
  (cond [(not (regexp-match #px".*@[[:digit:]]+x.*" (path->string path))) #f]
        [(regexp-match #rx".*@2x.*" (path->string path)) #f]
        [else
          (define target (path-replace path #px"@[[:digit:]]+x" "@2x"))
          (define orig-size (get-@-size (path->string path)))
          (resize-vips path target (/ 2 orig-size))]))

(define (resize-@2x path)
  (cond [(not (regexp-match #rx".*@2x.*" (path->string path))) #f]
        [else
          (define target (path-replace path #rx"@2x" ""))
          (resize-vips path target 0.5)]))

(define (resize-resizeto path)
  (cond [(not (or (regexp-match #px"resizeto[[:digit:]]+x[[:digit:]]+" (path->string path))
                  (regexp-match #px"resizeto[[:digit:]]+%" (path->string path))))
         #f]
        [else
          (define target (path-replace path #rx"_resizeto.*.png$" ".png"))
          (define size (~> (path->string path)
                           (string-replace _ #rx"^.*resizeto" "")
                           (string-replace _ #rx"\\..*" "")))
          (resize-im path target size)]))

(define (crop path)
  (cond [(not (regexp-match #px"tocrop" (path->string path))) #f]
        [else
          (define crop-dimention
            (~> (path->string path)
                (regexp-match #px"[[:digit:]]+x[[:digit:]]+\\+[[:digit:]]+\\+[[:digit:]]" _)
                (first _))) ; regexp-match returns a list of matching substrings
          (define target (path-replace path (string-append "_tocrop" crop-dimention) ""))
          (run-command "convert -crop"
                       crop-dimention
                       (path->string path)
                       (path->string target))
          (delete-file path)]))

#|
autotrim () {}
  echoreport trimming $1 ...
  convert -trim +repage $1 "$(echo $1 | sed 's/totrim\.png/.png/g')"
  rm $1
; export -f autotrim
|#
