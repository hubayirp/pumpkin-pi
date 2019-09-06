open Constr
open Names
open Environ
open Evd
open Lifting

(* --- Automatically generated equivalence proofs about search components --- *)

(*
 * Prove section and retraction
 * Return the section term and the retraction term
 * (Don't return the types, since Coq can infer them without issue)
 *)
val prove_equivalence : env -> evar_map -> lifting -> (types * types)

type pre_adjoint = {
  orn : lifting;
  sect : Constant.t;
  retr0 : Constant.t
}

(*
 * Augment the initial retraction proof in order to prove adjunction.
 *)
val adjointify_retraction : env -> evar_map -> pre_adjoint -> evar_map * constr

(*
 * Prove adjunction.
 *
 * TODO: Return a companion type expressed in terms of the augmented retraction
 * proof.
 *)
val prove_adjunction : env -> evar_map -> pre_adjoint -> evar_map * constr
