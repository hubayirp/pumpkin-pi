open Constrexpr
open Names
open Ltac_plugin

(*
 * Identify an algebraic ornament between two types
 * Define the components of the corresponding equivalence
 * (Don't prove section and retraction)
 *)
val find_ornament : Id.t option -> constr_expr -> constr_expr -> unit

(*
 * Lift the supplied function along the supplied ornament
 * Define the lifted version
 *)
val lift_by_ornament : ?suffix:bool -> Id.t -> constr_expr -> constr_expr -> constr_expr -> unit

(*
  * Lift each module element (constant and inductive definitions) along the given
  * ornament, defining a new module with all the transformed module elements.
  *)
val lift_module_by_ornament : Id.t -> constr_expr -> constr_expr -> Libnames.reference -> unit

(*
 * Unpack sigma types in the functional signature of a constant.
 *
 * This transformation assumes that the input constant was generated by
 * ornamental lifting.
 *)
val do_unpack_constant : Id.t -> Libnames.reference -> unit

(*
 * Lift from a record to a product within a definition or proof
 *)
val do_lift_record_to_product :
  Id.t -> (* name of new definition *)
  constr_expr -> (* record *)
  constr_expr -> (* product version of record *)
  constr_expr -> (* term to lift *)
  unit
