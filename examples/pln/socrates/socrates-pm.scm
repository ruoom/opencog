;; Socrates inference example based on the pattern matcher only. Each
;; step are run manually.

(use-modules (opencog))
(use-modules (opencog atom-types))
(use-modules (opencog exec))
(use-modules (opencog query))
(use-modules (opencog nlp))
(use-modules (opencog nlp chatbot))
(use-modules (opencog nlp relex2logic))
(use-modules (opencog pln))

;; Helper to get the r2l output
(define (get-r2l sent-node)
  (interp-get-r2l-outputs (car (sent-get-interp sent-node))))

(define (mock-pln-input sentence)
  (get-r2l (car (nlp-parse sentence))))

;; ; NOTE: Socrates isn't used b/c link-grammar has issue with it
;; (define input-1 (mock-pln-input "John is a man"))
;; (define input-2 (mock-pln-input "Men breathe air"))

;; Instead of running pln-parse load these files contained atoms
;; generated by nlp-parse with their stv overwritten at hand
(load "john-is-a-man-r2l-output.scm")
(load "men-breathe-air-r2l-output.scm")

;; Load PLN rules
(add-to-load-path "../../../opencog/pln/rules")
(pln-load-rules "term/deduction")
(pln-load-rules "wip/abduction")

;; Add knowledge to deal with SOG Predicates (Simple Observational
;; Grounded Predicates). Here we are gonna assume that all predicates
;; that have a corresponding WordNode are SOG. We also assumes that
;; the predicate has been built based on the complete cartesian
;; product of observations between A and B.
;;
;; What it says is that if P(A, B) holds, A1 inherits from A and B1
;; inherits from B, P(A1, B1) holds as well.
(define sog-hack-decomposition-rule
  (Bind
    (VariableList
      (TypedVariable
        (Variable "$W")
        (Type "WordInstanceNode"))
      (TypedVariable
        (Variable "$P")
        (Type "PredicateNode"))
      (TypedVariable
        (Variable "$A")
        (Type "ConceptNode"))
      (TypedVariable
        (Variable "$B")
        (Type "ConceptNode"))
      (TypedVariable
        (Variable "$A-subset")
        (Type "ConceptNode")))
    (And
      ; The ReferenceLink and the InheritanceLink specify the set specified
      ; by the the predicate (Variable "$P").
      (Reference
        (Variable "$P")
        (Variable "$W"))
      (Inheritance
        (Variable "$A-subset")
        (Variable "$A"))
      (Evaluation
        (Variable "$P")
        (List
          (Variable "$A")
          (Variable "$B"))))
    (Evaluation (stv 1 1)
      (Variable "$P")
      (List
        (Variable "$A-subset")
        (Variable "$B")))))

;; Step 1 - Abduction between
;;
;; (InheritanceLink
;;    (ConceptNode "man@bde8e1a7-d23a-43a8-bb79-bdc8980e4ffe")
;;    (ConceptNode "man"))
;;
;; and
;;
;; (InheritanceLink
;;    (ConceptNode "men@6f7d2525-a8b7-409c-889f-a51de8fd7c80")
;;    (ConceptNode "man"))
;;
;; to infer that
;;
;; (InheritanceLink
;;    (ConceptNode "man@bde8e1a7-d23a-43a8-bb79-bdc8980e4ffe")
;;    (ConceptNode "men@6f7d2525-a8b7-409c-889f-a51de8fd7c80"))
(cog-execute! abduction-inheritance-rule)

;; Step 2 - Deduction between the output of the previous step and
;;
;; (InheritanceLink
;;    (ConceptNode "John@23d1ea16-fe1c-453b-96b6-992a4b390227")
;;    (ConceptNode "man@bde8e1a7-d23a-43a8-bb79-bdc8980e4ffe"))
;;
;; to infer that
;;
;; (InheritanceLink
;;    (ConceptNode "John@23d1ea16-fe1c-453b-96b6-992a4b390227")
;;    (ConceptNode "men@6f7d2525-a8b7-409c-889f-a51de8fd7c80"))
;;
;; Actually it somehow has been produced by the previous step
;;
(cog-execute! deduction-inheritance-rule)

;; Step 3 - Apply sog-hack-decomposition-rule so that the substitutive
;; terms matches
;;
;; (EvaluationLink
;;    (PredicateNode "breathe@6fae8928-1073-4d7c-9a3a-af2f3668e33a")
;;    (ListLink
;;       (ConceptNode "men@6f7d2525-a8b7-409c-889f-a51de8fd7c80")
;;       (ConceptNode "air@768d4dee-8054-453f-8528-8b3c17bc4416")))
;;
;; and
;;
;; (InheritanceLink
;;    (ConceptNode "John@23d1ea16-fe1c-453b-96b6-992a4b390227")
;;    (ConceptNode "men@6f7d2525-a8b7-409c-889f-a51de8fd7c80"))
;;
;; to produce
;;
;; (EvaluationLink
;;    (PredicateNode "breathe@6fae8928-1073-4d7c-9a3a-af2f3668e33a")
;;    (ListLink
;;       (ConceptNode "John@23d1ea16-fe1c-453b-96b6-992a4b390227")
;;       (ConceptNode "air@768d4dee-8054-453f-8528-8b3c17bc4416")))
(cog-execute! sog-hack-decomposition-rule)
