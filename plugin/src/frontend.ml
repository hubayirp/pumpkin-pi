open Constr
open Names
open Globnames
open Lifting
open Caching
open Search
open Lift
open Unpack
open Utilities
open Pp
open Printer
open Coherence
open Equivalence
open Options
open Typehofs
open Constutils
open Nameutils
open Defutils
open Modutils
open Envutils
open Stateutils
open Environ

(* --- Commands --- *)

(*
 * Refresh an environment and get the corresponding state after defining
 * a term
 *)
let refresh_env () : env state =
  let env = Global.env () in
  Evd.from_env env, env

let pr_global_as_constr gref =
  let sigma, env = refresh_env () in
  pr_constr_env env sigma (Universes.constr_of_global gref)

(*
 * If the option is enabled, then prove coherence after find_ornament is called.
 * Otherwise, do nothing.
 *)
let maybe_prove_coherence n inv_n idx_n : unit =
  if is_search_coh () then
    let sigma, env = refresh_env () in
    let (promote, forget) = map_tuple make_constant (n, inv_n) in
    let indexer = make_constant idx_n in
    let orn = { indexer; promote; forget } in
    let coh, coh_typ = prove_coherence env sigma orn in
    let coh_n = with_suffix n "coh" in
    let _ = define_term ~typ:coh_typ coh_n sigma coh true in
    Printf.printf "Defined coherence proof %s\n\n" (Id.to_string coh_n)
  else
    ()

(*
 * If the option is enabled, then prove section, retraction, and adjunction after
 * find_ornament is called. Otherwise, do nothing.
 *)
let maybe_prove_equivalence n inv_n : unit =
  let define_proof suffix ?(adjective=suffix) evd term =
    let ident = with_suffix n suffix in
    let const = define_term ident evd term true |> destConstRef in
    Printf.printf "Defined %s proof %s\n\n" adjective (Id.to_string ident);
    const
  in
  if is_search_equiv () then
    let sigma, env = refresh_env () in
    let (promote, forget) = map_tuple make_constant (n, inv_n) in
    let l = initialize_lifting env sigma promote forget in
    let (section, retraction) = prove_equivalence env sigma l in
    let sect = define_proof "section" sigma section in
    let retr0 = define_proof "retraction" sigma retraction in
    let pre_adj = { orn = l; sect; retr0 } in
    let _ =
      let sigma, env = refresh_env () in
      let (sigma, retraction_adj) = adjointify_retraction env pre_adj sigma in
      define_proof "retraction_adjoint" sigma retraction_adj ~adjective:"adjoint retraction"
    in
    let _ =
      let sigma, env = refresh_env () in
      let (sigma, adjunction) = prove_adjunction env pre_adj sigma in
      define_proof "adjunction" sigma adjunction
    in ()
  else
    ()

(*
 * Identify an algebraic ornament between two types
 * Define the components of the corresponding equivalence
 * (Don't prove section and retraction)
 *)
let find_ornament n_o d_old d_new =
  let (sigma, env) = Pfedit.get_current_context () in
  let sigma, def_o = intern env sigma d_old in
  let sigma, def_n = intern env sigma d_new in
  let trm_o = unwrap_definition env def_o in
  let trm_n = unwrap_definition env def_n in
  match map_tuple kind (trm_o, trm_n) with
  | Ind ((m_o, _), _), Ind ((m_n, _), _) ->
    let (_, _, lab_o) = KerName.repr (MutInd.canonical m_o) in
    let (_, _, lab_n) = KerName.repr (MutInd.canonical m_n) in
    let name_o = Label.to_id lab_o in
    let name_n = Label.to_string lab_n in
    let auto_n = with_suffix (with_suffix name_o "to") name_n in
    let n = Option.default auto_n n_o in
    let idx_n = with_suffix n "index" in
    let sigma, orn = search_orn env sigma idx_n trm_o trm_n in
    ignore (define_term idx_n sigma orn.indexer true);
    Printf.printf "Defined indexing function %s.\n\n" (Id.to_string idx_n);
    let promote = define_term n sigma orn.promote true in
    Printf.printf "Defined promotion %s.\n\n" (Id.to_string n);
    let inv_n = with_suffix n "inv" in
    let forget = define_term inv_n sigma orn.forget true in
    Printf.printf "Defined forgetful function %s.\n\n" (Id.to_string inv_n);
    maybe_prove_coherence n inv_n idx_n;
    maybe_prove_equivalence n inv_n;
    (try
       save_ornament (trm_o, trm_n) (promote, forget)
     with _ ->
       Printf.printf "WARNING: Failed to cache ornamental promotion.")
  |_ ->
    failwith "Only inductive types are supported"

(*
 * Lift a definition according to a lifting configuration, defining the lifted
 * definition and declaring it as a lifting of the original definition.
 *)
let lift_definition_by_ornament env sigma n l c_old =
  let sigma, lifted = do_lift_defn env sigma l c_old in
  ignore (define_term n sigma lifted true);
  try
    let old_gref = global_of_constr c_old in
    let new_gref = ConstRef (Lib.make_kn n |> Constant.make1) in
    declare_lifted old_gref new_gref;
  with _ ->
    Printf.printf "WARNING: Failed to cache lifting."

(*
 * Lift an inductive type according to a lifting configuration, defining the
 * new lifted version and declaring type-to-type, constructor-to-constructor,
 * and eliminator-to-eliminator liftings.
 *)
let lift_inductive_by_ornament env sigma n s l c_old =
  let ind, _ = destInd c_old in
  let ind' = do_lift_ind env sigma n s l ind in
  let env' = Global.env () in
  Feedback.msg_notice (str "Defined lifted inductive type " ++ pr_inductive env' ind')

(*
 * Lift the supplied definition or inductive type along the supplied ornament
 * Define the lifted version
 *)
let lift_by_ornament ?(suffix=false) n d_orn d_orn_inv d_old =
  let (sigma, env) = Pfedit.get_current_context () in
  let sigma, c_orn = intern env sigma d_orn in
  let sigma, c_orn_inv = intern env sigma d_orn_inv in
  let sigma, c_old = intern env sigma d_old in
  let n_new = if suffix then suffix_term_name c_old n else n in
  let s = if suffix then Id.to_string n else "_" ^ Id.to_string n in
  let us = map_tuple (unwrap_definition env) (c_orn, c_orn_inv) in
  let are_inds = isInd (fst us) && isInd (snd us) in
  let lookup os = map_tuple Universes.constr_of_global (lookup_ornament os) in
  let ((c_from, c_to), refresh) =
    if are_inds then
      try
        lookup us, false
      with _ ->
        (* Search for ornament if the user never ran Find Ornament *)
        Feedback.msg_notice (str "Searching for ornament first");
        find_ornament None d_orn d_orn_inv;
        lookup us, true
    else
      (c_orn, c_orn_inv), false
  in
  let sigma, env = if refresh then refresh_env () else sigma, env in
  let l = initialize_lifting env sigma c_from c_to in
  let u_old = unwrap_definition env c_old in
  if isInd u_old then
    let from_typ = fst (on_red_type_default (fun _ _ -> ind_of_promotion_type) env sigma l.orn.promote) in
    if not (equal u_old from_typ) then
      lift_inductive_by_ornament env sigma n_new s l c_old
    else
      lift_definition_by_ornament env sigma n_new l c_old
  else
    lift_definition_by_ornament env sigma n_new l c_old

(*
  * Lift each module element (constant and inductive definitions) along the given
  * ornament, defining a new module with all the transformed module elements.
  *)
let lift_module_by_ornament ident d_orn d_orn_inv mod_ref =
  let mod_body =
    qualid_of_reference mod_ref |> Nametab.locate_module |> Global.lookup_module
  in
  let lift_global gref =
    let ident = Nametab.basename_of_global gref in
    try
      lift_by_ornament ident d_orn d_orn_inv (expr_of_global gref)
    with _ ->
      Feedback.msg_warning (str "Failed to lift " ++ pr_global_as_constr gref)
  in
  let _ =
    declare_module_structure
      ident
      (fun () -> iter_module_structure_by_glob lift_global mod_body)
  in
  Feedback.msg_notice (str "Defined lifted module " ++ Id.print ident)

(*
 * Unpack sigma types in the functional signature of a constant.
 *
 * This transformation assumes that the input constant was generated by
 * ornamental lifting.
 *)
let do_unpack_constant ident const_ref =
  let env = Global.env () in
  let sigma = ref (Evd.from_env env) in
  let term =
    qualid_of_reference const_ref |> Nametab.locate_constant |>
    unpack_constant env sigma
  in
  ignore (define_term ident !sigma term true)

(*
 * Lift from a record to a product within a definition or proof
 * WIP: Implementing, whole module version, coherence proofs
 *)
let do_lift_record_to_product n def_o def_n def : unit =
  let (sigma, env) = Pfedit.get_current_context () in
  let sigma, product = intern env sigma def_o in
  let sigma, record = intern env sigma def_n in
  let sigma, trm = intern env sigma def in
  Feedback.msg_warning (str "Not yet implemented")
