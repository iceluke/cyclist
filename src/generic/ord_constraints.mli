(** A structure representing a set of constraints on ordinal-valued variables.
    The structure may be queried to test whether the constraint set entails
    particular relationships between pairs of ordinal variables.
 *)

module Elt : sig
  include Util.BasicType
  val tags : t -> Util.Tags.t
end

include Util.OrderedContainer with type elt = Elt.t

val inconsistent : t -> bool

val tags : t -> Util.Tags.t

val subst_tags : Util.TagPairs.t -> t -> t

val generate : Util.Tags.elt -> Util.Tags.t -> t
(** [generate t ts] returns a constraint set that constitutes an inductive hypothesis
    corresponding to a case in the unfolding of a predicate tagged with [t] that
    recursively depends on predicate instances tagged by labels in [ts].  
*)

val close : t -> t
(** [close cs] generates the set of all constraints entailed by [cs] *)

val all_pairs : t -> Util.TagPairs.t
(** [tracepairs cs] returns the trace pairs contained in [cs] *)

val prog_pairs : t -> Util.TagPairs.t
(** [prog_tracepairs cs] returns all the progressing trace pairs contained in [cs] *)

val subsumed : t -> t -> bool
(** [subsumed cs cs'] checks whether every constraint in [cs'] also occurs in [cs] *)

val unify : 
  ?inverse:bool -> 
    ?update_check:((Util.TagPairs.t * Util.TagPairs.t) Fun.predicate) ->
      (Util.TagPairs.t, 'a, t) Unification.cps_unifier
(** [unify inverse check cs cs' cont init_state] 
    calculates a (minimal) extension theta of [init_state] such that 
    [subsumed cs' (subst_tags theta cs)] returns [true] then passes it to [cont]
    and returns the resulting (optional) value. 
    If the value of the optional argument [inverse=false] is set to [true] then 
    it returns theta such that [subsumed (subst_tags theta cs') cs] returns 
    [true] instead.
**)

val mk_update_check : 
  (Util.TagPairs.t * (Util.Tags.Elt.t * Util.Tags.Elt.t)) Fun.predicate 
    -> (Util.TagPairs.t * Util.TagPairs.t) Fun.predicate

val parse : (t, 'a) MParser.parser
val of_string : string -> t

val to_string_list : t -> string list
val to_melt : t -> Latex.t
