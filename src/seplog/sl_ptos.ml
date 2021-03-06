open Lib

open Symbols
open MParser

include Multiset.Make(Sl_pto)

let subst theta ptos = endomap (Sl_pto.subst theta) ptos

let to_string_list v = Blist.map Sl_pto.to_string (elements v)
let to_string v =
  Blist.to_string symb_star.sep Sl_pto.to_string (elements v)
let to_melt v =
  ltx_star (Blist.map Sl_pto.to_melt (elements v))

let terms ptos =
  Sl_term.Set.union_of_list (Blist.map Sl_pto.terms (elements ptos)) 

let vars p = Sl_term.filter_vars (terms p)

let parse st =
  (Sl_term.parse >>= (fun x ->
          parse_symb symb_pointsto >>
          Tokens.comma_sep1 Sl_term.parse << spaces |>>
          (fun l -> (x, l))) <?> "pto") st

let rec unify ?(total=true) 
    ?(sub_check=Sl_subst.trivial_check)
    ?(cont=Sl_unifier.trivial_continuation)
    ?(init_state=Sl_unifier.empty_state) ptos ptos' =
  if is_empty ptos then
    if not total || is_empty ptos' then cont init_state else None
  else
    let a = choose ptos in
    let ptos = remove a ptos in
    let f a' =
      Sl_pto.unify ~sub_check  
        ~cont:(fun state' -> 
          unify ~total ~sub_check ~cont ~init_state:state' ptos (remove a' ptos'))
        ~init_state a a' in
    find_map f ptos'

let rec subsumed ?(total=true) eqs ptos ptos' =
  if is_empty ptos then not total || is_empty ptos' else
  let pto = choose ptos in
  let ptos = remove pto ptos in
  let pto = Sl_pto.norm eqs pto in
  match find_opt (fun pto' -> Sl_pto.equal pto (Sl_pto.norm eqs pto')) ptos' with
  | None -> false
  | Some pto' -> subsumed ~total eqs ptos (remove pto' ptos')

let norm eqs ptos = endomap (Sl_pto.norm eqs) ptos
