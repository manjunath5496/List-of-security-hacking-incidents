Require Import String.
(* Examples by Adam Chlipala. Used with permission. *)
(** * Warm-up: natural numbers *)

Inductive nat := O | S (n : nat).

Fixpoint plus (n m : nat) : nat :=
  match n with
    | O => m
    | S n' => S (plus n' m)
  end.

(* TACTICS:
 * [reflexivity]: prove an equality goal that follows by normalizing terms.
 *)

Lemma O_plus : forall n,
  plus O n = n.
Proof.
  reflexivity.
Qed.

(* TACTICS:
 * [induction x]: prove goal by induction on quantified variable [x].
 *    CAVEATS: All variables appearing _before_ [x] will remain _fixed_ throughout the induction!
 * [simpl]: apply standard heuristics for computational simplification in conclusion.
 * [rewrite H]: use (potentially quantified) equality [H] to rewrite in the conclusion.
 *)

Lemma plus_O : forall n,
  plus n O = n.
Proof.
  induction n.

  reflexivity.

  simpl.
  rewrite IHn.
  reflexivity.
Qed.

(* TACTICS:
 * [intros]: move quantified variables and/or hypotheses "above the double line."
 *)

Theorem plus_assoc : forall n m o,
  plus (plus n m) o = plus n (plus m o).
Proof.
  induction n.

  simpl.
  reflexivity.

  simpl.
  intros.
  rewrite IHn.
  reflexivity.
Qed.

Lemma plus_S : forall n m,
  S (plus n m) = plus n (S m).
Proof.
  induction n.

  simpl.
  reflexivity.

  simpl.
  intros.
  rewrite IHn.
  reflexivity.
Qed.

(* TACTICS:
 * [apply thm]: apply a named theorem, reducing the goal into one new subgoal
 *              for each of the theorem's hypotheses, if any.
 *)

Theorem plus_comm : forall n m,
  plus n m = plus m n.
Proof.
  induction n.

  simpl.
  intros.
  rewrite plus_O.
  reflexivity.

  simpl.
  intros.
  rewrite IHn.
  apply plus_S.
Qed.

Reset nat.
(* Going forward, we don't actually want to work with our own custom natural numbers,
 * so let's undo these last definitions. *)


(** * Basic operational semantics & interpreters *)

Module Arithmetic.
  (** Syntax of a language of arithmetic expressions *)
  Inductive exp :=
  | Const (n : nat)
  | Plus (e1 e2 : exp)
  | Times (e1 e2 : exp)
  | IfZero (e1 e2 e3 : exp).

  (** Here's the easiest way to give this language a semantics: with an interpreter. *)
  Fixpoint interpret (e : exp) : nat :=
    match e with
      | Const n => n
      | Plus e1 e2 => interpret e1 + interpret e2
      | Times e1 e2 => interpret e1 * interpret e2
      | IfZero e1 e2 e3 =>
        match interpret e1 with
          | O => interpret e2
          | S _ => interpret e3
        end
    end.

  (** We'll need explicit operational semantics for fancier languages,
    * so let's practice on this simple one. *)
  Inductive bigStep : exp -> nat -> Prop :=
  | BigConst : forall n,
    bigStep (Const n) n
  | BigPlus : forall e1 e2 n1 n2,
    bigStep e1 n1
    -> bigStep e2 n2
    -> bigStep (Plus e1 e2) (n1 + n2)
  | BigTimes : forall e1 e2 n1 n2,
    bigStep e1 n1
    -> bigStep e2 n2
    -> bigStep (Times e1 e2) (n1 * n2)
  | BigIfZeroO : forall e1 e2 e3 n,
    bigStep e1 O
    -> bigStep e2 n
    -> bigStep (IfZero e1 e2 e3) n
  | BigIfZeroS : forall e1 e2 e3 n1 n2,
    bigStep e1 (S n1)
    -> bigStep e3 n2
    -> bigStep (IfZero e1 e2 e3) n2.

  (* TACTICS:
   * [destruct E]: Do case analysis on the constructor used to build term [E].
   * [eapply thm]: Like [apply], but leaves placeholders for theorem parameters that are not known yet.
   * [assumption]: Prove a conclusion that matches a known hypothesis.
   * [eassumption]: Like [assumption], but also learns values for placeholders in the process.
   *)

  Lemma interpToBig : forall e,
    bigStep e (interpret e).
  Proof.
    induction e.

    simpl.
    apply BigConst.

    simpl.
    apply BigPlus.
    assumption.
    assumption.

    simpl.
    apply BigTimes.
    assumption.
    assumption.

    simpl.
    destruct (interpret e1).

    apply BigIfZeroO.
    assumption.
    assumption.

    eapply BigIfZeroS.
    eassumption.
    assumption.
  Qed.

  (* TACTICS:
   * [induction N]: Induction on the derivation of the [N]th hypothesis in the conclusion
   *                (numbering goes left to right and starts at 1).
   * [rewrite <- H]: Like [rewrite], but rewrites right-to-left.
   *)

  Lemma bigToInterp : forall e n,
    bigStep e n
    -> n = interpret e.
  Proof.
    induction 1.

    simpl.
    reflexivity.

    simpl.
    rewrite <- IHbigStep1.
    rewrite <- IHbigStep2.
    reflexivity.

    simpl.
    rewrite <- IHbigStep1.
    rewrite <- IHbigStep2.
    reflexivity.

    simpl.
    rewrite <- IHbigStep1.
    assumption.

    simpl.
    rewrite <- IHbigStep1.
    assumption.
  Qed.

  (* TACTICS:
   * [generalize thm1,...,thmN]: Bring the statements of a set of theorems into the goal explicitly,
   *                             so that other tactics don't need to deduce them manually.
   * [firstorder]: Magic heuristic procedure for proofs based on first-order logic rules.
   *               (It's undecidable in general, so don't get too excited.)
   *)

  Theorem bigAndInterp : forall e n,
    bigStep e n <-> n = interpret e.
  Proof.
    generalize interpToBig, bigToInterp.
    firstorder.
    rewrite H1.
    firstorder.
  Qed.
End Arithmetic.


(** * Lambda-calculus *)

Definition var := string.

Module BasicLambdaCalculus.
  (** Syntax of terms in general *)
  Inductive exp :=
  | Var (x : var)
  (* Variable *)

  | App (e1 e2 : exp)
  (* Function application *)

  | Abs (x : string) (e1 : exp)
  (* Function abstraction, which is another name for "lambda" *).

  (** Syntax of values *)
  Inductive val :=
  | VAbs (x : string) (e1 : exp).

  (** Convert a value back into a general expression *)
  Definition toExp (v : val) : exp :=
    match v with
      | VAbs x e1 => Abs x e1
    end.

  (** Substitution.  We don't need to work hard to avoid capture because of
    * how we'll use substitution below. *)
  Fixpoint subst (e e' : exp) (x : var) : exp :=
    match e with
      | Var y => if string_dec y x then e' else Var y
      | App e1 e2 => App (subst e1 e' x) (subst e2 e' x)
      | Abs y e1 => Abs y (if string_dec y x then e1 else subst e1 e' x)
    end.

  (** * Call-by-value evaluation *)
  Module CallByValue.
    (** Big-step operational semantics *)
    Inductive bigStep : exp -> val -> Prop :=
    | BigAbs : forall x e1,
      bigStep (Abs x e1) (VAbs x e1)
    | BigApp : forall e1 e2 x e1' v v',
      bigStep e1 (VAbs x e1')
      -> bigStep e2 v
      -> bigStep (subst e1' (toExp v) x) v'
      -> bigStep (App e1 e2) v'.

    (** Small-step operational semantics *)
    Inductive smallStep : exp -> exp -> Prop :=
    | SmallBeta : forall x e v,
      smallStep (App (Abs x e) (toExp v)) (subst e (toExp v) x)
    | SmallApp1 : forall e1 e2 e1',
      smallStep e1 e1'
      -> smallStep (App e1 e2) (App e1' e2)
    | SmallApp2 : forall v e e',
      smallStep e e'
      -> smallStep (App (toExp v) e) (App (toExp v) e').

    (** Transitive-reflexive closure *)
    Inductive smallStepStar : exp -> exp -> Prop :=
    | StarRefl : forall e,
      smallStepStar e e
    | StarStep : forall e e' e'',
      smallStep e e'
      -> smallStepStar e' e''
      -> smallStepStar e e''.

    (* TACTICS:
     * [inversion_clear H]: case analysis on which rule was used to prove hypothesis [H]
     * [tac1; tac2]: run [tac1], then run [tac2] on all generated subgoals.
     *)

    (** Now, let's prove equivalence of the two semantics! *)
    Lemma smallToBig' : forall e e',
      smallStep e e'
      -> forall v, bigStep e' v
        -> bigStep e v.
    Proof.
      induction 1; intros.

      destruct v.
      eapply BigApp.
      apply BigAbs.
      apply BigAbs.
      assumption.

      inversion_clear H0.
      eapply BigApp.
      apply IHsmallStep.
      eassumption.
      eassumption.
      assumption.

      inversion_clear H0.
      eapply BigApp.
      eassumption.
      apply IHsmallStep.
      eassumption.
      eassumption.
    Qed.

    (* TACTICS:
     * [subst]: eliminate any equations like [x = E], by replacing [x] by [E] everywhere.
     *)

    Theorem smallToBig : forall e e',
      smallStepStar e e'
      -> forall v, e' = toExp v
        -> bigStep e v.
    Proof.
      induction 1; intros; subst.

      destruct v.
      apply BigAbs.

      eapply smallToBig'.
      eassumption.
      apply IHsmallStepStar.
      reflexivity.
    Qed.

    Lemma SmallApp1Star : forall e1 e1' e2,
      smallStepStar e1 e1'
      -> smallStepStar (App e1 e2) (App e1' e2).
    Proof.
      induction 1.

      apply StarRefl.

      eapply StarStep.
      apply SmallApp1.
      eassumption.
      assumption.
    Qed.

    Lemma SmallApp2Star : forall e e' v,
      smallStepStar e e'
      -> smallStepStar (App (toExp v) e) (App (toExp v) e').
    Proof.
      induction 1.

      apply StarRefl.

      eapply StarStep.
      apply SmallApp2.
      eassumption.
      assumption.
    Qed.

    Lemma smallStepStar_trans : forall e e' e'',
      smallStepStar e e'
      -> smallStepStar e' e''
      -> smallStepStar e e''.
    Proof.
      induction 1; intros.

      assumption.

      eapply StarStep.
      eassumption.
      apply IHsmallStepStar.
      assumption.
    Qed.

    Theorem bigToSmall : forall e v,
      bigStep e v
      -> smallStepStar e (toExp v).
    Proof.
      induction 1.

      apply StarRefl.

      eapply smallStepStar_trans.
      apply SmallApp1Star.
      eassumption.
      eapply smallStepStar_trans.
      apply SmallApp2Star.
      eassumption.
      eapply StarStep.
      apply SmallBeta.
      assumption.
    Qed.

    Theorem bigAndSmall : forall e v,
      bigStep e v <-> smallStepStar e (toExp v).
    Proof.
      generalize smallToBig, bigToSmall.
      firstorder.
    Qed.

    (** Now... let's see how the proof changes when we use evaluation contexts. *)

    (** Evaluation contexts for small-step semantics *)
    Inductive context :=
    | Hole
    | App1 (C : context) (e : exp)
    | App2 (v : val) (C : context).

    (** How to plug an expression into a context *)
    Fixpoint plug (C : context) (e : exp) : exp :=
      match C with
        | Hole => e
        | App1 C e' => App (plug C e) e'
        | App2 v C => App (toExp v) (plug C e)
      end.

    (** The small-step semantics itself (now just one rule!) *)
    Inductive contextStep : exp -> exp -> Prop :=
    | ContextBeta : forall C x e v,
      contextStep (plug C (App (Abs x e) (toExp v))) (plug C (subst e (toExp v) x)).

    (** Transitive-reflexive closure *)
    Inductive contextStepStar : exp -> exp -> Prop :=
    | CStarRefl : forall e,
      contextStepStar e e
    | CStarStep : forall e e' e'',
      contextStep e e'
      -> contextStepStar e' e''
      -> contextStepStar e e''.

    (** Now, let's prove equivalence with the other small-step semantics. *)

    (** We'll want a notion of context composition to get there. *)
    Fixpoint compose (C1 C2 : context) : context :=
      match C1 with
        | Hole => C2
        | App1 C1 e => App1 (compose C1 C2) e
        | App2 v C1 => App2 v (compose C1 C2)
      end.

    Lemma compose_correct : forall C1 C2 e,
      plug C1 (plug C2 e) = plug (compose C1 C2) e.
    Proof.
      induction C1; simpl; intros.

      reflexivity.

      rewrite IHC1.
      reflexivity.

      rewrite IHC1.
      reflexivity.
    Qed.

    Lemma descend : forall C e e',
      contextStep e e'
      -> contextStep (plug C e) (plug C e').
    Proof.
      destruct 1; intros.

      rewrite compose_correct.
      rewrite compose_correct.
      apply ContextBeta.
    Qed.

    (* Here is a derived form that is helpful to simplify proofs with Coq 8.3. *)
    Lemma descend' : forall C e e' e1 e2,
      contextStep e e'
      -> e1 = plug C e
      -> e2 = plug C e'
      -> contextStep e1 e2.
    Proof.
      intros; subst; apply descend; assumption.
    Qed.

    (* TACTICS:
     * [apply (thm arg1 ... argN)]: Apply a theorem while giving explicit instantiations for
     *                              its first [N] quantified variables.
     *)

    Lemma smallToContext : forall e e',
      smallStep e e'
      -> contextStep e e'.

    (* Here's a longer proof that is necessary to appease Coq 8.3.  8.4 version follows. *)
    Proof.
      induction 1; intros.

      apply (ContextBeta Hole).

      eapply (descend' (App1 Hole e2)).
      eassumption.
      reflexivity.
      reflexivity.

      eapply (descend' (App2 v Hole)).
      eassumption.
      reflexivity.
      reflexivity.
    Qed.

    (* Here's the simpler 8.4 version, which takes advantage of smarter matching of lemmas with goals.
    Proof.
      induction 1; intros.

      apply (ContextBeta Hole).

      apply (descend (App1 Hole e2)).
      assumption.

      apply (descend (App2 v Hole)).
      assumption.
    Qed.*)

    (* TACTICS:
     * [destruct N]: Like [destruct E], but on the [N]th hypothesis in the conclusion.
     *               Applied to propositions, it acts like a more primitive form of [inversion_clear].
     *               If crazy things happen, try [inversion_clear] instead.
     *)
                   
    Lemma contextToSmall : forall e e',
      contextStep e e'
      -> smallStep e e'.
    Proof.
      destruct 1; intros.

      induction C; simpl.

      apply SmallBeta.

      apply SmallApp1.
      assumption.

      apply SmallApp2.
      assumption.
    Qed.

    Lemma smallToContextStar : forall e e',
      smallStepStar e e'
      -> contextStepStar e e'.
    Proof.
      induction 1.

      apply CStarRefl.

      eapply CStarStep.
      apply smallToContext.
      eassumption.
      assumption.
    Qed.

    Lemma contextToSmallStar : forall e e',
      contextStepStar e e'
      -> smallStepStar e e'.
    Proof.
      induction 1.

      apply StarRefl.

      eapply StarStep.
      apply contextToSmall.
      eassumption.
      assumption.
    Qed.

    (* TACTICS:
     * [firstorder eauto]: Slightly beefed up version of [firstorder].  Don't ask. ;-)
     *)

    Theorem bigAndContext : forall e v,
      bigStep e v <-> contextStepStar e (toExp v).
    Proof.
      generalize smallToBig, bigToSmall, smallToContextStar, contextToSmallStar.
      firstorder eauto.
    Qed.
  End CallByValue.

  (** * Now let's see what changes going to call-by-name. *)
  Module CallByName.
    (** Big-step operational semantics *)
    Inductive bigStep : exp -> val -> Prop :=
    | BigAbs : forall x e1,
      bigStep (Abs x e1) (VAbs x e1)
    | BigApp : forall e1 e2 x e1' v,
      bigStep e1 (VAbs x e1')
      -> bigStep (subst e1' e2 x) v
      -> bigStep (App e1 e2) v.

    (** Small-step operational semantics *)
    Inductive smallStep : exp -> exp -> Prop :=
    | SmallBeta : forall x e1 e2,
      smallStep (App (Abs x e1) e2) (subst e1 e2 x)
    | SmallApp1 : forall e1 e2 e1',
      smallStep e1 e1'
      -> smallStep (App e1 e2) (App e1' e2).

    (** Transitive-reflexive closure *)
    Inductive smallStepStar : exp -> exp -> Prop :=
    | StarRefl : forall e,
      smallStepStar e e
    | StarStep : forall e e' e'',
      smallStep e e'
      -> smallStepStar e' e''
      -> smallStepStar e e''.

    (** Now, let's prove equivalence of the two semantics! *)
    Lemma smallToBig' : forall e e',
      smallStep e e'
      -> forall v, bigStep e' v
        -> bigStep e v.
    Proof.
      induction 1; intros.

      eapply BigApp.
      apply BigAbs.
      assumption.

      inversion_clear H0.
      eapply BigApp.
      apply IHsmallStep.
      eassumption.
      eassumption.
    Qed.

    Theorem smallToBig : forall e e',
      smallStepStar e e'
      -> forall v, e' = toExp v
        -> bigStep e v.
    Proof.
      induction 1; intros; subst.

      destruct v.
      apply BigAbs.

      eapply smallToBig'.
      eassumption.
      apply IHsmallStepStar.
      reflexivity.
    Qed.

    Lemma SmallApp1Star : forall e1 e1' e2,
      smallStepStar e1 e1'
      -> smallStepStar (App e1 e2) (App e1' e2).
    Proof.
      induction 1.

      apply StarRefl.

      eapply StarStep.
      apply SmallApp1.
      eassumption.
      assumption.
    Qed.

    Lemma smallStepStar_trans : forall e e' e'',
      smallStepStar e e'
      -> smallStepStar e' e''
      -> smallStepStar e e''.
    Proof.
      induction 1; intros.

      assumption.

      eapply StarStep.
      eassumption.
      apply IHsmallStepStar.
      assumption.
    Qed.

    Theorem bigToSmall : forall e v,
      bigStep e v
      -> smallStepStar e (toExp v).
    Proof.
      induction 1.

      apply StarRefl.

      eapply smallStepStar_trans.
      apply SmallApp1Star.
      eassumption.
      eapply StarStep.
      apply SmallBeta.
      assumption.
    Qed.

    Theorem bigAndSmall : forall e v,
      bigStep e v <-> smallStepStar e (toExp v).
    Proof.
      generalize smallToBig, bigToSmall; firstorder.
    Qed.

    (** Now... let's see how the proof changes when we use evaluation contexts. *)

    (* Evaluation contexts for small-step semantics *)
    Inductive context :=
    | Hole
    | App1 (C : context) (e : exp).

    (* How to plug an expression into a context *)
    Fixpoint plug (C : context) (e : exp) : exp :=
      match C with
        | Hole => e
        | App1 C e' => App (plug C e) e'
      end.

    (* The small-step semantics itself (now just one rule!) *)
    Inductive contextStep : exp -> exp -> Prop :=
    | ContextBeta : forall C x e1 e2,
      contextStep (plug C (App (Abs x e1) e2)) (plug C (subst e1 e2 x)).

    (** Transitive-reflexive closure *)
    Inductive contextStepStar : exp -> exp -> Prop :=
    | CStarRefl : forall e,
      contextStepStar e e
    | CStarStep : forall e e' e'',
      contextStep e e'
      -> contextStepStar e' e''
      -> contextStepStar e e''.

    (** Now, let's prove equivalence with the other small-step semantics. *)

    Fixpoint compose (C1 C2 : context) : context :=
      match C1 with
        | Hole => C2
        | App1 C1 e => App1 (compose C1 C2) e
      end.

    Lemma compose_correct : forall C1 C2 e,
      plug C1 (plug C2 e) = plug (compose C1 C2) e.
    Proof.
      induction C1; simpl; intros.

      reflexivity.

      rewrite IHC1.
      reflexivity.
    Qed.

    Lemma descend : forall C e e',
      contextStep e e'
      -> contextStep (plug C e) (plug C e').
    Proof.
      destruct 1; intros.

      rewrite compose_correct.
      rewrite compose_correct.
      apply ContextBeta.
    Qed.

    Lemma descend' : forall C e e' e1 e2,
      contextStep e e'
      -> e1 = plug C e
      -> e2 = plug C e'
      -> contextStep e1 e2.
    Proof.
      intros; subst; apply descend; assumption.
    Qed.

    Lemma smallToContext : forall e e',
      smallStep e e'
      -> contextStep e e'.
    Proof.
      induction 1; intros.

      apply (ContextBeta Hole).

      (* In Coq 8.4, just the following line works, but we'll give a more laborious 8.3 script, too.
      apply (descend (App1 Hole e2)). *)
      eapply (descend' (App1 Hole e2)).
      eassumption.
      reflexivity.
      reflexivity.
    Qed.

    Lemma contextToSmall : forall e e',
      contextStep e e'
      -> smallStep e e'.
    Proof.
      destruct 1; intros.

      induction C; simpl.

      apply SmallBeta.

      apply SmallApp1.
      assumption.
    Qed.

    Lemma smallToContextStar : forall e e',
      smallStepStar e e'
      -> contextStepStar e e'.
    Proof.
      induction 1.

      apply CStarRefl.

      eapply CStarStep.
      apply smallToContext.
      eassumption.
      assumption.
    Qed.

    Lemma contextToSmallStar : forall e e',
      contextStepStar e e'
      -> smallStepStar e e'.
    Proof.
      induction 1.

      apply StarRefl.

      eapply StarStep.
      apply contextToSmall.
      eassumption.
      assumption.
    Qed.

    Theorem bigAndContext : forall e v,
      bigStep e v <-> contextStepStar e (toExp v).
    Proof.
      generalize smallToBig, bigToSmall, smallToContextStar, contextToSmallStar.
      firstorder eauto.
    Qed.
  End CallByName.
End BasicLambdaCalculus.
