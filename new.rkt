#lang rackjure
(require json
         threading
         "helper.rkt"
         "post-process.rkt")

(provide (all-defined-out)) ; for requiring this file in a repl when developing

(define current-project-directory (make-parameter "skin.Retome"))
(define current-revision (make-parameter "dev"))
(define modules empty)
(command-line
  #:program "mkosuskin"
  #:once-each
  [("-p" "--project") dir
                      "Specify project directory"
                      (current-project-directory dir)]
  [("-r" "--revision") rev
                       "Specify revision string (default is 'dev')"
                       (current-revision rev)]
  #:multi
  [("-m" "--module") mod
                     "Specify extra modules to render"
                     (set! modules (append modules (list mod)))])

;; (define project-directory "./skin.Retome")
(define cache-directory (build-path (current-project-directory) ".cache"))
(unless (directory-exists? cache-directory)
  (make-directory cache-directory))

(define directories-to-render
  (~> (directory-list (current-project-directory))
      (map #λ(build-path (current-project-directory) %1) _)
      (filter directory-exists? _) ; would be #f for files
      (filter #λ(file-exists? (build-path %1 "render")) _))) ; if dir/render is a file

; rendered-files is a file with one json list in it

(define (move-file-to-cache file)
  (system (string-join (list "mv "
                             (path->string file)
                             (path->string cache-directory)))))

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

; post-process : path-string? -> void?
(define (post-process path)
  (resize-@nx path)
  (resize-resizeto path)
  (crop path)
  (trim path)
  (resize-@2x path))

(define (package dir)
  (define skinname (path->string (path-replace (current-project-directory) "skin." "")))
  (define outfile (build-path (current-project-directory)
                              ".out"
                              (string-append skinname (current-revision) ".zip")))
  (run-command "7z a"
               (build-path (current-project-directory) ".out" (string-append skinname ".zip"))
               (map string->path (directory-list cache-directory)))
  (rename-file-or-directory outfile
                            (path-replace-extension outfile ".osk")))

(define (optimize-png-in-dir dir)
  (run-command "pngquant --skip-if-larger --ext .png --force"
               (~> (directory-list dir)
                   (filter #λ(path-has-extension? %1 ".png") _)
                   (map #λ(build-path dir %1) _)
                   (map path->string _))))

(define (main)
  (map render-directory directories-to-render)
  (map post-process (directory-list cache-directory))
  (optimize-png-in-dir cache-directory)
  (package cache-directory))
