(** Points-to atom, consisting of a pair of a term and a list of terms. *)

include Util.BasicType with type t = Sl_term.t * Sl_term.FList.t

val subst : Sl_term.substitution -> t -> t
val to_melt : t -> Latex.t
val terms : t -> Sl_term.Set.t
val vars : t -> Sl_term.Set.t

val unify : t Sl_term.unifier
(** Compute substitution that unifies two points-tos. *)