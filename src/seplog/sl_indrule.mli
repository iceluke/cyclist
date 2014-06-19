include Util.BasicType
val mk : Sl_heap.t -> Symheap.ind_identifier * Sl_term.t list -> t
val dest: t -> Sl_heap.t * (Symheap.ind_identifier * Sl_term.t list)
val vars : t -> Sl_term.Set.t
val freshen : Sl_term.Set.t -> t -> t
val subst : Sl_term.substitution -> t -> t
val parse : (t, 'a) MParser.t


