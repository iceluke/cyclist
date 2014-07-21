include Util.BasicType
val mk : Sl_heap.t -> Symheap.ind_identifier * Sl_term.t list -> t
val dest: t -> Sl_heap.t * (Symheap.ind_identifier * Sl_term.t list)
val vars : t -> Sl_term.Set.t
val params : t -> Sl_term.t list
val freshen : Sl_term.Set.t -> t -> t
val subst : Sl_term.substitution -> t -> t
val parse : (t, 'a) MParser.t
val unfold : Sl_term.Set.t -> Symheap.ind_pred -> t -> Sl_heap.t

