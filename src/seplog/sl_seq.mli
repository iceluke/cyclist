(** SL sequent, as a pair of SL formulas. 
    NB [equal] ignores RHS tags.
*)

include Utilsigs.BasicType with type t = Sl_form.t * Sl_form.t

val equal_upto_tags : t -> t -> bool
(** Like [equal] but ignoring LHS tags as well as RHS ones. *)

val dest : t -> Sl_heap.t * Sl_heap.t
(** If both LHS and RHS are symbolic heaps then return them else raise
    [Sl_form.Not_symheap]. *)

val parse : ?null_is_emp:bool -> (t, 'a) MParser.t
val of_string : ?null_is_emp:bool -> string -> t

val to_melt : t -> Latex.t

val vars : t -> Sl_term.Set.t

val tags : t -> Tags.t
(** Only LHS tags are returned. *)

val tag_pairs : t -> Tagpairs.t
(** Only LHS tag pairs are returned. *)

val subst_tags : Tagpairs.t -> t -> t
(** Substitute tags of the LHS. *)

val subst : Sl_subst.t -> t -> t

val subsumed : t -> t -> bool
(** [subsumed (l,r) (l',r')] is true iff [Sl_form.subsumed l' l] and
    [Sl_form.subsumed_upto_tags r r'] are true. *)
    
val subsumed_upto_tags : t -> t -> bool
(** Like [subsumed] but ignoring all tags. *)

val norm : t -> t
(** Replace all terms with their UF representatives in the respective formulas.` *)
