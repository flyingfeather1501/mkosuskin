#lang rackjure
(require json
         threading)

(provide (all-defined-out))

; project-directory : path-string?
(define project-directory "./skin.Retome")
(define cache-directory (build-path project-directory ".cache"))
(unless (directory-exists? cache-directory)
  (make-directory cache-directory))

(define (move-file-to-cache file)
  (system (string-join (list "mv "
                             (path->string file)
                             (path->string cache-directory)))))

; rendered-files is a file with one json list in it

(define (render-directory dir)
  (define render (build-path dir "render"))
  (unless (member 'execute
                  (file-or-directory-permissions render))
    (error 'render-directory (string-append (build-path dir "render") " is not executable")))
  (system* render) ; run the render
  (map move-file-to-cache
       (~> (build-path dir "rendered-files") ; read the file 'rendered-files'
           (file->string _)
           (string->jsexpr _)
           (map #λ(build-path dir %1) _)))) ; read out rendered files

(define directories-to-render
  (~> (directory-list project-directory)
      (map #λ(build-path project-directory %1) _)
      (filter directory-exists? _) ; would be #f for files
      (filter #λ(file-exists? (build-path %1 "render")) _))) ; if dir/render is a file

(define (post-process)
  (system "ls ./skin.Retome/.cache/"))

(void (map render-directory directories-to-render))
