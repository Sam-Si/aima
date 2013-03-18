#!/usr/bin/env chicken-scheme

;; [[file:~/prg/scm/aima/aima.org::*Non-determinism%20and%20random-walk][Non-determinism-and-random-walk:1]]

(include "online-navigation.scm")

(use heap)

(define (make-agent-random-walk start next-frame)
  (make-agent
   start
   0
   (let ((state->action->states (make-hash-table))
         (state->state->actions (make-hash-table))
         (previous-state #f)
         (previous-action #f)
         (expectations 0)
         (met-expectations 0)
         (expected-states (make-stack)))
     (define (update-statistics! state)
       (hash-table-update!
        state->action->states
        previous-state
        (lambda (action->states)
          (hash-table-update!
           action->states
           previous-action
           (lambda (states)
             (if (heap-member? states state)
                 (heap-change-key! states
                                   state
                                   (add1 (heap-key states state)))
                 (heap-insert! states
                               1
                               state))
             states)
           (lambda () (make-max-heap)))
          action->states)
        ;; Too bad we don't have multi-dimensional hash-tables.
        (lambda () (make-hash-table)))
       (hash-table-update!
        state->state->actions
        previous-state
        (lambda (state->actions)
          (hash-table-update!
           state->actions
           state
           (lambda (actions)
             (if (heap-member? actions previous-action)
                 (heap-change-key! actions
                                   previous-action
                                   (add1 (heap-key actions previous-action)))
                 (heap-insert! actions
                               1
                               previous-action))
             actions)
           (lambda () (make-max-heap)))
          state->actions)
        (lambda () (make-hash-table))))
     (define (not-unexpected-state? state)
       (let* ((possible-states
               (hash-table-ref/default
                (hash-table-ref/default
                 state->action->states
                 previous-state
                 (make-hash-table))
                previous-action
                (make-max-heap)))
              (expected-state
               (and (not (heap-empty? possible-states))
                    (heap-extremum possible-states))))
         (or (not expected-state)
             (equal? state expected-state))))
     (define (expected-state)
       (let* ((possible-states
               (hash-table-ref/default
                (hash-table-ref/default
                 state->action->states
                 previous-state
                 (make-hash-table))
                previous-action
                (make-max-heap))))
         (and (not (heap-empty? possible-states))
              (heap-extremum possible-states))))
     (define (not-unexpected-state? expected-state state)
       (or (not expected-state)
           (equal? state expected-state)))
     (define (reset!)
       (set! previous-state #f)
       (set! previous-action #f)
       (set! expected-states (make-stack)))
     (define (move-randomly state)
       (debug "Moving randomly.")
       (let ((action (list-ref state (random (length state)))))
         (set! previous-state state)
         (set! previous-action action)
         (debug action)
         action))
     (define (move-backwards-or-randomly state)
       (let* ((return
               (hash-table-ref/default
                (hash-table-ref/default
                 state->state->actions
                 state
                 (make-hash-table))
                previous-state
                (make-max-heap)))
              (return
               (and (not (heap-empty? return))
                    (heap-extremum return))))
         (if return
             (begin
               (debug "Attempting to return.")
               (debug return)
               (set! previous-state state)
               (set! previous-action return)
               return)
             (begin
               (debug "Can't return.")
               (move-randomly state)))))
     (define (try-to-backtrack expected-state state)
       (move-backwards-or-randomly state))
     (define (iterate-over-goals goal? state)
       (debug state)
       (if (stack-empty? expected-states)
           (begin
             (debug "There are no expected states.")
             (if goal?
                 (begin
                   (debug "Found goal.")
                   (reset!)
                   zero-motion)
                 (let ((expected-state (expected-state)))
                   (if (not-unexpected-state? expected-state state)
                       (begin
                         (debug "This state is not unexpected.")
                         (move-randomly state))
                       (begin
                         (debug "This state is statistically anomolous.")
                         (debug "Pushing the expected-state unto expected-states.")
                         (debug expected-state)
                         (stack-push! expected-states expected-state)
                         (unless (equal? previous-state state)
                           (debug "Pushing the previous-state unto expected-states.")
                           (debug previous-state)
                           (stack-push! expected-states previous-state))
                         (try-to-backtrack expected-state state))))))
           (begin
             (debug (stack->list expected-states))
             (let ((expected-state (stack-peek expected-states)))
               (if (equal? state expected-state)
                   (begin
                     (debug "We're at the expected state; popping expected states.")
                     (stack-pop! expected-states)
                     (iterate-over-goals goal? state))
                   (begin
                     (debug "We're not at the expected state; trying to backtrack.")
                     (try-to-backtrack expected-state state)))))))
     (lambda (state goal? score)
       (if previous-action             ; Implied: previous-state, too.
           (begin
             (update-statistics! state)
             (iterate-over-goals goal? state))
           (move-randomly state))))))

(simulate-navigation make-agent-random-walk
                     n-points: 100
                     n-steps: 200
                     p-slippage: 0.3
                     animation-file: #f)

;; Non-determinism-and-random-walk:1 ends here