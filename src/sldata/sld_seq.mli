(** SL sequent, as a pair of SL formulas. 
    NB [equal] ignores RHS tags.
*)

include Util.BasicType with type t = Sld_form.t * Sld_form.t

val equal_upto_tags : t -> t -> bool
(** Like [equal] but ignoring LHS tags as well as RHS ones. *)

val dest : t -> Sld_heap.t * Sld_heap.t
(** If both LHS and RHS are symbolic heaps then return them else raise
    [Sld_form.Not_symheap]. *)

val parse : (t, 'a) MParser.t
val of_string : string -> t

val to_melt : t -> Latex.t

val vars : t -> Sld_term.Set.t

val tags : t -> Util.Tags.t
(** Only LHS tags are returned. *)

val tag_pairs : t -> Util.TagPairs.t
(** Only LHS tag pairs are returned. *)

val subst_tags : Util.TagPairs.t -> t -> t
(** Substitute tags of the LHS. *)

val subst : Sld_term.substitution -> t -> t

val subsumed : t -> t -> bool
(** [subsumed (l,r) (l',r')] is true iff [Sld_form.subsumed l' l] and
    [Sld_form.subsumed_upto_tags r r'] are true. *)
    
val subsumed_upto_tags : t -> t -> bool
(** Like [subsumed] but ignoring all tags. *)

val norm : t -> t
(** Replace all terms with their UF representatives in the respective formulas.` *)