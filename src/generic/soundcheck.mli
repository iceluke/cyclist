(** Provides an abstract view of a proof as a graph and allows checking its 
    soundness. *)

type abstract_node 
(** Abstract proof node type. The only 
    information stored is a set of tags (integers) and a list of
    tuples of: successor, set of valid tag transitions and set of
    progressing tag transitions. *) 

val mk_abs_node :   
  Util.Tags.t -> ((int * Util.TagPairs.t* Util.TagPairs.t ) list) -> 
    abstract_node 
(** Constructor for nodes. *)

type t = abstract_node Util.Int.Map.t
(** The type of abstracted proof as a map from ints to nodes. 
    NB the root is always at 0. *)

val check_proof : t -> bool
(** Validate, minimise, check soundness of proof/graph and memoise. *)

val pp : Format.formatter -> t -> unit
(** Pretty print abstract proof. *)
