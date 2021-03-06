(*
 * Question from Anders Mortberg
 *)
Require Import Coq.Program.Tactics.
Require Import Ornamental.Ornaments.

Set DEVOID lift type.

Parameter T1 : Type.
Parameter T2 : Type.
Parameter T3 : Type.

Definition A := T1 -> T2 -> T3.
Definition B := T2 -> T1 -> T3.

Program Definition f : A -> B.
Proof.
  unfold A. unfold B. intros a.
  intros t2 t1. apply a; auto.
Defined.

Program Definition g : B -> A.
Proof.
  unfold B. unfold A. intros b.
  intros t1 t2. apply b; auto.
Defined.

Lemma section:
  forall (a : A), g (f a) = a.
Proof.
  intros a. reflexivity.
Defined.

Lemma retraction:
  forall (b : B), f (g b) = b.
Proof.
  intros b. reflexivity.
Defined.

(*
 * We'll need this to deal with lack of type-directed search:
 *)
Definition ignore_A := A.

(*
 * Then we get:
 *)
Definition dep_constr_A_0 (a : ignore_A) : A := a.
Definition dep_constr_B_0 (a : ignore_A) : B := (fun t2 t1 => a t1 t2).

(*
 * Eta is trivial:
 *)
Definition eta_A (a : A) := a.
Definition eta_B (b : B) := b.

(*
 * This gives us dep_elim:
 *)
Program Definition dep_elim_A (P : A -> Type) (f0 : forall (a : A), P (dep_constr_A_0 a)) (a : A) : P (eta_A a).
Proof.
  apply f0.
Defined.

Program Definition dep_elim_B (P : B -> Type) (f0 : forall (a : A), P (dep_constr_B_0 a)) (b : B) : P (eta_B b).
Proof.
  apply f0.
Defined.

(*
 * No inductive cases, so trivial iota:
 *)
Definition iota_A_0 (P : A -> Type) (f0 : forall (a : A), P (dep_constr_A_0 a)) (a : A) (Q : P (dep_constr_A_0 a) -> Type) (H : Q (f0 a)) :=
  H.

Definition iota_B_0 (P : B -> Type) (f0 : forall (a : A), P (dep_constr_B_0 a)) (a : A) (Q : P (dep_constr_B_0 a) -> Type) (H : Q (f0 a)) :=
  H.

(*
 * Then we just save that:
 *)
Save equivalence A B { promote = f; forget = g }.
Configure Lift A B {
  constrs_a = dep_constr_A_0;
  constrs_b = dep_constr_B_0;
  elim_a = dep_elim_A;
  elim_b = dep_elim_B;
  eta_a = eta_A;
  eta_b = eta_B;
  iota_a = iota_A_0;
  iota_b = iota_B_0
}.

(*
 * Note that since we don't have unification
 * heuristics for custom equivalences, for now we'll need to represent the configuration
 * terms explicitly everywhere. And also because the transformation tries to transform
 * _everything_ that matches, but our dependent constructors take B and A respectively as
 * inputs, we need to baby the transformation into understanding when _not_ to lift a B.
 *
 * So I think the answer here is: technically, we can handle this sort of thing, but when
 * it comes to the details of handling it usefully, the usability barriers come up a lot here.
 * In particular all of our notes in the paper about the current lack of:
 * 1) custom unification heuristics, and
 * 2) type-directed search
 * become extremely relevant.
 *)
Module Over_A.
  Definition id (a : A) := a.

  (*
   * The swapping can't happen unless we tell the transformation that this:
   *)
  Definition from_t3_implicit (t3 : T3) : A := fun t1 t2 => t3.
  (*
   * is an application of dep_constr:
   *)
  Definition from_t3_explicit (t3 : T3) : A := dep_constr_A_0 (fun t1 t2 => t3).
End Over_A.

(*
 * opaque says to ignore ignore_A:
 *)
Lift A B in dep_constr_A_0 as dep_constr_A_0_lifted { opaque ignore_A }.

Lift Module A B in Over_A as Over_B.
Print Over_B.from_t3_explicit.
(* Over_B.from_t3_explicit
     : T3 -> B *)

(* Why not this though? *)

(*
 * Then we get:
 *)
Definition ignore_A_constr (t3 : T3) : A := (fun t1 t2 => t3).
Definition ignore_B_constr (t3 : T3) : B := (fun t2 t1 => t3).

Definition dep_constr_A_0' (a : A) : A := a.
Definition dep_constr_A_1' (t3 : T3) : A := (fun t1 t2 => t3).

Definition dep_constr_B_0' (b : B) : B := b.
Definition dep_constr_B_1' (t3 : T3) : B := (fun t2 t1 => t3).

(*
 * Eta is trivial:
 *)
Definition eta_A' (a : A) := a.
Definition eta_B' (b : B) := b.

(*
 * This gives us dep_elim:
 *)
Program Definition dep_elim_A' (P : A -> Type) (f0 : forall (a : A), P (dep_constr_A_0' a)) (a : A) : P (eta_A' a).
Proof.
  apply f0.
Defined.

Program Definition dep_elim_B' (P : B -> Type) (f0 : forall (b : B), P (dep_constr_B_0' b)) (b : B) : P (eta_B' b).
Proof.
  apply f0.
Defined.

(*
 * No inductive cases, so trivial iota:
 *)
Definition iota_A_0' (P : A -> Type) (f0 : forall (a : A), P (dep_constr_A_0' a)) (a : A) (Q : P (dep_constr_A_0' a) -> Type) (H : Q (f0 a)) :=
  H.

Definition iota_B_0' (P : B -> Type) (f0 : forall (b : B), P (dep_constr_B_0' b)) (b : B) (Q : P (dep_constr_B_0' b) -> Type) (H : Q (f0 b)) :=
  H.

(*
 * Then we just save that:
 *)
Save equivalence A B { promote = f; forget = g }.
Configure Lift A B {
  constrs_a = dep_constr_A_0' dep_constr_A_1';
  constrs_b = dep_constr_B_0' dep_constr_B_1';
  elim_a = dep_elim_A';
  elim_b = dep_elim_B';
  eta_a = eta_A';
  eta_b = eta_B';
  iota_a = iota_A_0';
  iota_b = iota_B_0'
}.

(*
 * Note that since we don't have unification
 * heuristics for custom equivalences, for now we'll need to represent the configuration
 * terms explicitly everywhere. And also because the transformation tries to transform
 * _everything_ that matches, but our dependent constructors take B and A respectively as
 * inputs, we need to baby the transformation into understanding when _not_ to lift a B.
 *
 * So I think the answer here is: technically, we can handle this sort of thing, but when
 * it comes to the details of handling it usefully, the usability barriers come up a lot here.
 * In particular all of our notes in the paper about the current lack of:
 * 1) custom unification heuristics, and
 * 2) type-directed search
 * become extremely relevant.
 *)
Module Over_A_2.
  Definition id (a : A) := a.

  (*
   * The swapping can't happen unless we tell the transformation that this:
   *)
  Definition from_t3_implicit (t3 : T3) : A := fun t1 t2 => t3.
  (*
   * is an application of dep_constr:
   *)
  Definition from_t3_explicit (t3 : T3) t1 t2 : T3 := dep_constr_A_1' t3 t1 t2.
End Over_A_2.

(*
 * Ah, the issue here seems to be eta expansion when we don't want it to expand.
 *)

Lift A B in dep_constr_A_0' as dep_constr_A_0_lifted'.
Lift A B in dep_constr_A_1' as dep_constr_A_1_lifted'.
Print dep_constr_A_1_lifted'.

Unset DEVOID lift type. (* it's some bug at the type level *)
Lift Module A B in Over_A_2 as Over_B_2.
Print Over_B_2.from_t3_explicit.
Print whatever.
(* Over_B_2.from_t3_explicit = fun t3 : T3 => dep_constr_A_1_lifted' t3
     : T3 -> B
 *)

(* this works! *)


