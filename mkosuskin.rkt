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
  ;; just clean up cache for now
  (map (λ (path) (if (directory-exists? path)
                     (delete-directory path)
                     (delete-file path)))
       (directory-list cache-directory #:build? #t))
  ;; this should be run here, after modules has already been set
  (map render-directory (~> (directory-list (current-project-directory) #:build? #t)
                            (filter directory-exists? _) ; only directories
                            (filter #λ(file-exists? (build-path %1 "render")) _) ; if dir/render is a file
                            (filter (λ (%1)
                                       (if (member 'execute
                                                   (file-or-directory-permissions
                                                     (build-path %1 "render")))
                                         #t
                                         (begin
                                           (displayln (string-append "warning: "
                                                                     (path->string (build-path %1 "render"))
                                                                     " is present but is not executable"))
                                           #f)))
                                    _)
                            (filter default-directories-or-specified-module? _)))
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
  (define (parse-mods path)
    (~> (string-split (path->string path) "%")
        (map (λ (x) (string-split x ".")) _) ; handle a%ja.blend
        (rest) ; first element is path up to first "%". drop it
        (map first _))) ; drop the extension after string-split
  (cond
    ; if path doesn't specify module like path%modname, it should be rendered
    [(not (path-contains? (path-basename path) "%")) #t]
    ; if path does, parse the modules and compare with the 'modules' list
    [(share-some-elements? (parse-mods path)
                           modules) #t]
    [else #f]))

; rendered-files is a file with one json list in it

(define/contract (move-file-to-cache file)
  (-> path? void?)
  (rename-file-or-directory file (build-path cache-directory (path-basename file))))

(define (render-directory dir)
  (define render (build-path dir "render"))
  (unless (member 'execute
                  (file-or-directory-permissions render))
    (error 'render-directory (string-append (path->string (build-path dir "render")) " is not executable")))
  (system* render) ; run the render
  (map move-file-to-cache
       (~> (build-path dir "rendered-files") ; read the file 'rendered-files'
           (file->string _)
           (string->jsexpr _)
           (map #λ(build-path dir %1) _)))) ; read out rendered files

; post-process : path? -> void?
(define (post-process dir)
  ;; (directory-list dir) is run repeatedly because *the folder content changes*
  (map post-process (filter directory-exists? (directory-list dir #:build? #t))) ; subdirectories
  (map resize-@ (filter file-exists? (directory-list dir #:build? #t)))
  (map resize-resizeto (filter file-exists? (directory-list dir #:build? #t)))
  (map crop (filter file-exists? (directory-list dir #:build? #t)))
  (map trim (filter file-exists? (directory-list dir #:build? #t))))

(define (package dir)
  (define skinname (path->string (path-replace (current-project-directory) #rx".*skin\\." "")))
  (define outfile (build-path (current-project-directory)
                              ".out"
                              (string-append skinname " " (current-revision) ".zip")))
  (run-command "7z" "a"
               (path->string outfile)
               (map path->string (directory-list cache-directory #:build? #t)))
  (rename-file-or-directory outfile
                            (path-replace-extension outfile ".osk")
                            ;; overwrite existing file?
                            #t))

(define (optimize-png-in-dir dir)
  (displayln "optimizing png")
  (run-command "pngquant" "--skip-if-larger" "--ext" ".png" "--force"
               (~> (directory-list dir)
                   (filter #λ(path-has-extension? %1 ".png") _)
                   (map #λ(build-path dir %1) _)
                   (map path->string _))))

(unless (= 0 (vector-length (current-command-line-arguments)))
  (main))
