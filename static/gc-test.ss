#!/usr/bin/env mzscheme
#lang scheme
(require scheme/sandbox)
(require plai/private/sandbox
         plai/private/test)


(define (display-results r)
  (cond
    [(string? r) (display r (current-error-port))]
    [(list? r)
     (for-each (λ (e) (fprintf (current-error-port) "~v~n" e)) r)]
    [else (display r (current-error-port))]))
(sandbox-eval-limits (list false false))
      
(define (run-tests #:collector collector
                   #:mutator mutator
                   #:memory-limit [memory-limit 200]
                   #:cpu-limit [cpu-limit 50]
                   #:heap-viz [heap-viz false]
                   #:abridged-results [abridged-results false])
  (local ([define-values (mutator-base _1 __1) 
            (split-path (path->complete-path mutator))]
          [define-values (collector-base _2 __2) 
            (split-path (path->complete-path collector))])
    (parameterize
        ([use-compiled-file-paths null]
         [sandbox-path-permissions 
          `(,@(if (path? mutator-base) `([exists ,mutator-base]) empty)
            [read ,mutator] [exists ,mutator]
            ,@(if (path? collector-base) `([exists ,collector-base]) empty)
            [read ,collector] 
            [exists ,collector])])
      (local ([define evaluator (make-evaluator 'scheme)])
        (with-handlers
            ([exn?
              (lambda (exn)
                ; If an exception is raised, print the heap to stdout, ...
                (fprintf (current-error-port)
                         "~n~n==========~nYour test suite / solution signaled an error.~n")
                (fprintf (current-error-port)
                         "~nThe error message was: ~a~n" (exn-message exn))
                (fprintf (current-error-port)
                         "~nThe contents of the heap when the error was signalled:~n")
                (display-results
                 (evaluator
                  (if heap-viz '(heap-as-string) 'plai-all-test-results)))
                ; Print 1 to stdout so that the tourney knows we failed, ...
                (display 1)
                ; Print the error message to stderr and signal an error for the tourney.
                (error "\n==========\n"))])
          (evaluator
           (with-limits 
            memory-limit cpu-limit
            `(begin
               (require plai/test-harness
                        plai/private/command-line
                        plai/private/gc-core
                        (for-syntax plai/private/command-line))
               (begin-for-syntax
                 (set-alternate-collector! ,collector))
               (gc-disable-import-gc? true)
               (halt-on-errors true)
               (abridged-test-output ,abridged-results)
               (require ,mutator)
               ,(if heap-viz
                    '(heap-as-string)
                    'plai-all-test-results)))))))))

(when (>  (vector-length (current-command-line-arguments)) 0)
  (local ([define cpu-limit 50]
          [define memory-limit 100]
          [define interface false]
          [define heap-viz true]
          [define abridged-results false]
          [define error-on-errors false]
          [define halt-on-errors false])
    (command-line
     #:once-each
     [("-t" "--cpu-limit") sec "limit CPU usage"
                           (set! cpu-limit (string->number sec))]
     [("-a" "--abridge-results") "don't show expressions in test results"
                                 (set! abridged-results true)]
     [("-p" "--heap-display") "show the heap on failure"
                              (set! heap-viz true)]
     [("-e" "--halt-on-errors") 
      "halt on errors" 
      (set! halt-on-errors true)]
     [("-r" "--error-on-errors")
      "signal an error if any errors occur"
      (set! error-on-errors true)]
     [("-m" "--memory-limit") mb "limit memory usage"
                              (set! memory-limit (string->number mb))]
     [("-i" "--interface") names "names to import from the solution"
                           (set! interface (read (open-input-string
                                                  (string-append "(" names ")"))))]
     #:args (collector mutator)
     (run-tests #:collector collector
                #:mutator mutator
                #:memory-limit memory-limit
                #:cpu-limit cpu-limit
                #:heap-viz heap-viz
                #:abridged-results abridged-results))))