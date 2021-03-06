(** Sets of disequalities over terms. *)
(** it is guaranteed that for any pair (x,y) in the set, x<=y re [Sl_term.compare].*)

include Utilsigs.OrderedContainer with type elt = Sl_tpair.t

val parse : (Sl_tpair.t, 'a) MParser.parser
val subst : Sl_subst.t -> t -> t

val terms : t -> Sl_term.Set.t
val vars : t -> Sl_term.Set.t

val to_string_list : t -> string list
val to_melt : t -> Latex.t

val unify_partial : ?inverse:bool -> t Sl_unifier.t
(** [unify_partial Option.some (Sl_subst.empty, ()) d d'] computes a 
    substitution [theta] such that [d[theta]] is a subset of [d']. 
    If the optional argument [~inverse:false] is set to [true] then a 
    substitution is computed such that [d] is a subset of [d'[theta]]. *)

val subsumed : Sl_uf.t -> t -> t -> bool
(** [subsumed eqs d d'] is true iff [d] can be rewritten using the equalities
    in [eqs] such that it becomes a subset of [d']. *)

val norm : Sl_uf.t -> t -> t
(** Rename all variables involved by their representative in the UF structure 
    and re-order pair members if necessary. *) 