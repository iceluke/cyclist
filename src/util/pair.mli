(** Operations on pairs. *)

val mk : 'a -> 'b -> 'a * 'b
(** Pair constructor. *)
val map : ('a -> 'b) -> 'a * 'a -> 'b * 'b
(** Apply a function to both members individually and put results in a new pair. *)
val apply : ('a -> 'b -> 'c) -> 'a * 'b -> 'c 
(** Apply a function taking two arguments to the members of a pair. *)
val conj : bool * bool -> bool 
(** Compute the conjunction of a pair of booleans. *)
val disj : bool * bool -> bool 
(** Compute the disjunction of a pair of booleans. *)
val swap : 'a * 'b -> 'b * 'a
(** Swap around the members of a pair. *)
val fold : ('a -> 'b -> 'b) -> 'a * 'a -> 'b -> 'b
(** Fold a function over the members of a pair. *)

module Make(T: Utilsigs.BasicType) (S: Utilsigs.BasicType) :
  Utilsigs.BasicType with type t = T.t * S.t
(** Create functions for equality, comparison, hashing and printing for a
    pair of types. *)