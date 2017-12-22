#lang rackjure
(require json
         threading
         "helper.rkt"
         "post-process.rkt")

(define current-project-directory (make-parameter
                                   (build-path (current-directory)
                                               "skin.Retome")))
(define current-revision (make-parameter "dev"))
(define modules empty)
(define cache-directory (build-path (current-project-directory) ".cache"))

(define (main)
  (parse-arguments)
  (unless (directory-exists? cache-directory)
    (make-directory cache-directory))
  (map render-directory directories-to-render)
  (post-process cache-directory)
  (optimize-png-in-dir cache-directory)
  (package cache-directory))

(define (parse-arguments)
  (command-line
   #:program "mkosuskin"
   #:once-each
   [("-p" "--project") dir
                       "Specify project directory"
                       (current-project-directory (build-path dir))]
   [("-r" "--revision") rev
                        "Specify revision string (default is 'dev')"
                        (current-revision rev)]
   #:multi
   [("-m" "--module") mod
                      "Specify extra modules to render"
                      (set! modules (append modules (list mod)))]))

(define (default-directories-or-specified-module? path)
  (cond
    ; if path doesn't specify module like path%modname, it should be rendered
    [(not (path-contains? (path-basename path) "%"))
     #t]
    ; if path does, parse the modules and compare with the 'modules' list
    [(share-some-elements? (~> (string-split (path->string path) "%")
                               (map (λ (x) (string-split x ".")) _) ; handle a%ja.blend
                               (rest) ; first element is path up to first %. drop it
                               (map first _)) ; drop the extension after string-split
                           modules)
     #t]
    [else #f]))

(define directories-to-render
  (~> (directory-list (current-project-directory))
      (map #λ(build-path (current-project-directory) %1) _)
      (filter directory-exists? _) ; would be #f for files
      (filter #λ(file-exists? (build-path %1 "render")) _) ; if dir/render is a file
      (filter default-directories-or-specified-module? _)))

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

(unless (= 0 (vector-length (current-command-line-arguments)))
  (main))
