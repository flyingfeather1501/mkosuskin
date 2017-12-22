#lang racket
(require threading
         "helper.rkt")

(provide resize-@ resize-@2x resize-resizeto crop trim get-@-size)

; orig, target : path?
; ratio : number?
(define (resize-vips orig target ratio)
  (run-command "vips resize"
               (path->string orig)
               (path->string target)
               (number->string (exact->inexact ratio))))

; orig, target : path?
; size : string?
(define (resize-im orig target size)
  (run-command "convert -resize"
               size
               (path->string orig)
               (path->string target)))

;; get-@-size : string -> number
(define (get-@-size string)
  (~> (string-replace string #rx".*@" "")
      (string-replace _ #rx"x.*" "")
      (string->number _)))

(define (resize-@ path)
  (define base-path (path-basename path))
  (cond [(not (regexp-match #px".*@[[:digit:]]+x.*" (path->string base-path))) #f]
        [(not (file-exists? path)) #f]
        [(regexp-match #rx".*@2x.*" (path->string base-path)) (resize-@2x path)]
        [else
          (define target (path-replace path #px"@[[:digit:]]+x" "@2x"))
          (define orig-size (get-@-size (path->string path))) ; parse the n in @_n_x
          (resize-vips path target (/ 2 orig-size))
          (resize-@2x target) ; target is always @2x. resize it to SD here
          (delete-file path) ; we don't want left over @4x's
          ;; return the target path
          target]))

(define (resize-@2x path)
  (define base-path (path-basename path))
  (cond [(not (regexp-match #rx".*@2x.*" (path->string base-path))) #f]
        [(not (file-exists? path)) #f]
        [else
          (define target (path-replace path #rx"@2x" ""))
          (resize-vips path target 0.5)
          ;; return target path
          target]))

(define (resize-resizeto path)
  (define base-path (path-basename path))
  (cond [(not (or (regexp-match #px"resizeto[[:digit:]]+x[[:digit:]]+" (path->string base-path))
                  (regexp-match #px"resizeto[[:digit:]]+%" (path->string base-path))))
         #f]
        [(not (file-exists? path)) #f]
        [else
          (define target (path-replace path #rx"_resizeto.*.png$" ".png"))
          (define size (~> (path->string path)
                           (string-replace _ #rx"^.*resizeto" "")
                           (string-replace _ #rx"\\..*" "")))
          (resize-im path target size)
          (delete-file path)
          ;; return target
          target]))

(define (crop path)
  (define base-path (path-basename path))
  (cond [(not (regexp-match #px"tocrop" (path->string base-path))) #f]
        [(not (file-exists? path)) #f]
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
          (delete-file path)
          ;; return target
          target]))

(define (trim path)
  (define base-path (path-basename path))
  (cond [(not (regexp-match #px"totrim" (path->string base-path))) #f]
        [(not (file-exists? path)) #f]
        [else
          (define target (path-replace path "_totrim" ""))
          (run-command "convert -trim +repage"
                       (path->string path)
                       (path->string target))
          (delete-file path)
          ;; return target
          target]))