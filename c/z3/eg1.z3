(declare-sort Loc)
(declare-sort Rec)
(declare-sort St)
(declare-sort Set)
(declare-fun value (St Loc) Rec)
;; Let's try the approach of defining domain using a function.
(declare-fun dom (St) Set)
;; Set functions
(declare-fun in (Loc Set) Bool)
(declare-const empty Set)
(assert (forall ((l Loc)) (= (in l empty) false)))
(declare-fun remove (Set Set Loc) Bool)
(assert (forall ((s2 Set)(s1 Set)(l Loc)) 
          (= (remove s2 s1 l)
              (and (= (in l s2) false)
                   (forall ((l1 Loc)) 
                      (=> (not (= l1 l))
                          (= (in l1 s2) (in l1 s1))))))))
(declare-fun add (Set Set Loc) Bool)
(assert (forall ((s2 Set)(s1 Set)(l Loc)) 
          (= (add s2 s1 l)
              (and (in l s2)
                   (forall ((l1 Loc)) 
                      (=> (not (= l1 l))
                          (= (in l1 s2) (in l1 s1))))))))
(declare-sort Id)
(declare-sort Str)
;; Declare record attributes
(declare-fun id (Rec) Id)
(declare-fun cbal (Rec) Int)
(declare-fun sbal (Rec) Int)
;; ------ Basic Axioms ---------
;; 1. No two locations point to the same record in any state. 
;; 2. Id is a primary key, hence unique.
(assert (forall ((st St))
          (forall ((l1 Loc)(l2 Loc)) 
            (=> (and (in l1 (dom st)) 
                     (in l2 (dom st))
                     (= (id (value st l1)) 
                        (id (value st l2)))) 
                (and (= l1 l2) )))))
;; Define st2 = st1[l -> r] 
(define-fun bind ((st2 St) (st1 St) (l Loc) (r Rec)) Bool
  (and (add (dom st2) (dom st1) l)
       (= (value st2 l) r)
       (forall ((l1 Loc)) 
          (=> (and (not (= l1 l)) (in l1 (dom st1))) 
              (and (in l1 (dom st2)) 
                   (= (value st2 l1) (value st1 l1)))))))
;; Define I
(define-fun I ((st St)) Bool
  (forall ((l Loc)) 
    (=> (in l (dom st))
        (and (>= (cbal (value st l)) 0)
             (>= (sbal (value st l)) 0)))))
;; Define G1
(declare-fun G1 (St St) Bool)
(assert (forall ((st1 St)(st2 St)) 
          (= (G1 st1 st2)
             (exists ((l Loc)(r1 Rec)(r2 Rec)) 
                (and (in l (dom st1)) 
                     (in l (dom st2))
                     (= (value st1 l) r1)
                     (= (id r2) (id r1))
                     (= (sbal r2) (sbal r1)) 
                     (>= (cbal r2) 0)
                     (bind st2 st1 l r2))))))
;; G2 is same as G1.
;; Define G3
(declare-fun G3 (St St) Bool)
(assert (forall ((st1 St)(st2 St)) 
          (= (G3 st1 st2) 
             (exists ((l Loc)(r1 Rec)(r2 Rec)) 
                (and (in l (dom st1)) 
                     (in l (dom st2))
                     (= (value st1 l) r1)
                     (= (id r2) (id r1))
                     (>= (sbal r2) 0) 
                     (>= (cbal r2) 0)
                     (bind st2 st1 l r2) )))))
;; Define R = G1 ∪ G2 ∪ G3
(declare-fun R (St St) Bool)
(assert (forall ((st1 St)(st2 St)) 
          (= (R st1 st2) 
             (or (G1 st1 st2) (G3 st1 st2)))))
;; Define Ir for SI 
(define-fun Ir ((stl St)(stg1 St)(stg2 St)) Bool
  (= stg1 stg2))
;; Define Ic for SI
(define-fun Ic ((stl St)(stg1 St)(stg2 St)) Bool
  (forall ((l Loc)) 
    (=> (and (in l (dom stl)) (in l (dom stg1)))
        (and (in l (dom stg2)) 
             (= (value stg1 l) (value stg2 l)) )))) 
;; Define Rl
(define-fun Rl ((stl St)(stg1 St)(stg2 St)) Bool
  (and (Ir stl stg1 stg2) (R stg1 stg2)))
;; Define Rc
(define-fun Rc ((stl St)(stg1 St)(stg2 St)) Bool
  (and (Ic stl stg1 stg2) (R stg1 stg2)))
;; Define σl>>σg
(declare-fun flush (St St) St)
(assert (forall ((stl St)(stg St))
          (forall ((l Loc)) 
            (= (in l (dom (flush stl stg))) 
               (or (in l (dom stl)) (in l (dom stg)))))))
(assert (forall ((stl St)(stg St)) 
          (forall ((l Loc)) 
            (ite (in l (dom stl)) 
                  (= (value (flush stl stg) l) 
                     (value stl l)) 
                  (ite (in l (dom stg)) 
                       (= (value (flush stl stg) l) 
                          (value stg l))
                       true)))))
;; Define Q(stl,stg)
(define-fun Q ((stl St)(stg St)) Bool
  (G1 stl (flush stl stg)))
; Checking the stability of Q
(push)
(declare-const stableQ Bool)
(assert (= stableQ
           (forall ((stl St)(stg1 St)(stg2 St)) 
              (=> (and (Q stl stg1) (Rc stl stg1 stg2)) 
                  (Q stl stg2)))))
(assert (not stableQ))
(check-sat)
(pop)

;; Define what is means to update user balance for user whose id is 
;; u_id
(declare-const u_id Id)
(declare-const user Rec)
(declare-const amt Int)
(declare-fun updated (St St St) Bool)
(assert (forall ((stg St) (st1 St)(st2 St)) 
          (= (updated stg st1 st2)
              (forall ((l Loc)) 
                (ite (and (in l (dom (flush st1 stg))) 
                          (= (id (value (flush st1 stg) l)) u_id))
                     (and (in l (dom st2)) 
                          (= (id (value st2 l)) u_id)
                          (= (sbal (value st2 l)) (sbal (value (flush st1 stg) l)))
                          (= (cbal (value st2 l)) (+ (cbal user) amt)))
                     (ite (in l (dom st1)) 
                          (and (in l (dom st2))
                               (= (value st2 l) (value st1 l))) 
                          (not (in l (dom st2)))))))))

;; Define Q1
(define-fun Q1 ((stl St)(stg St)) Bool
  (forall ((stl1 St )) 
    (=> (updated stg stl stl1) (Q stl1 stg))))
;; Checking the stability of Q1
(push)
(declare-const stableQ1 Bool)
(assert (= stableQ1
           (forall ((stl St)(stg1 St)(stg2 St)) 
              (=> (and (Q1 stl stg1) (Rl stl stg1 stg2)) 
                  (Q1 stl stg2)))))
; Checking the stability of Q1
(assert (not stableQ1))
(check-sat)
(pop)
