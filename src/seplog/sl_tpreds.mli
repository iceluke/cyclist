(** Multiset of tagged predicates. 
    NB no check is made for the uniqueness of tags within set. 
    However, that uniqueness is required if [tagged_unify_partial] is to return
    a set of tag pairs that describes an injective function.
    *)
include Utilsigs.OrderedContainer with type elt = Sl_tpred.t

val equal_upto_tags : t -> t -> bool
(** Test whether the two arguments are the equal ignoring tags. *) 

val subst : Sl_subst.t -> t -> t

val subst_tags : Tagpairs.t -> t -> t
(** Substitute tags according to the function represented by the set of 
    tag pairs provided. *)


val terms : t -> Sl_term.Set.t
val vars : t -> Sl_term.Set.t
val tags : t -> Tags.t

val idents : t -> Sl_predsym.MSet.t
(** Return multiset of identifiers present. *)

val strip_tags : t -> Sl_pred.MSet.t
(** Remove tags. *)

val to_string_list : t -> string list
val to_melt : t -> Latex.t

val freshen_tags : t -> t -> t
(** Rename tags in second argument so that they are disjoint to those in the first. *)

val subsumed_upto_tags : ?total:bool -> Sl_uf.t -> t -> t -> bool
(** Test whether the two arguments are the same modulo the provided equalities. 
    NB the comparison ignores tags.  
    If the optional argument [~total=true] is set to [false] then 
    check if the first multiset is a subset of the second modulo equalities. *)
val subsumed : ?total:bool -> Sl_uf.t -> t -> t -> bool
(** Test whether the two arguments are the same modulo the provided equalities. 
    Contrary to [subsumed] this includes tags. 
    If the optional argument [~total=true] is set to [false] then 
    check if the first multiset is a subset of the second modulo equalities. *)

val unify : ?total:bool -> ?tagpairs:bool -> t Sl_unifier.t
(** Compute substitution that makes the two multisets equal up to tags. 
- If the optional argument [~total=true] is set to [false] then 
  compute substitution that makes the first multiset a subset of the second.
- If the optional argument [~tagpairs=false] is set to [true] then return 
  in addition to the substitution the pairs of tags of predicates unified. *)

val norm : Sl_uf.t -> t -> t
(** Replace all terms with their UF representative. NB this may replace [nil] 
    with a variable. *)
 