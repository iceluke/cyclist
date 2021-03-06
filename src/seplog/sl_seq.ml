open Lib

open Symbols
open MParser

include Pair.Make(Sl_form)(Sl_form)

let equal (l,r) (l',r') =
  Sl_form.equal l l' 
  &&
  Sl_form.equal_upto_tags r r'

let equal_upto_tags (l,r) (l',r') =
  Sl_form.equal_upto_tags l l' 
  &&
  Sl_form.equal_upto_tags r r'


let dest seq = Pair.map Sl_form.dest seq

let parse ?(null_is_emp=false) st =
  ( (Sl_form.parse ~null_is_emp) >>= (fun l ->
    parse_symb symb_turnstile >> 
    (Sl_form.parse ~null_is_emp) >>= (fun r ->
                return (l, r))) <?> "Sequent") st

let of_string ?(null_is_emp=false) s =
  handle_reply (MParser.parse_string (parse ~null_is_emp) s ())

let to_string (l, r) =
  (Sl_form.to_string l) ^ symb_turnstile.sep ^ (Sl_form.to_string r)
let to_melt (l, r) =
  ltx_mk_math
    (Latex.concat [Sl_form.to_melt l; symb_turnstile.melt; Sl_form.to_melt r])

let pp fmt (l, r) =
  Format.fprintf fmt "@[%a %s@ %a@]" Sl_form.pp l symb_turnstile.str Sl_form.pp r

let terms (l, r) = Sl_term.Set.union (Sl_form.terms l) (Sl_form.terms r)
let vars seq = Sl_term.filter_vars (terms seq)

let tags seq = Sl_form.tags (fst seq)
let tag_pairs f = Tagpairs.mk (tags f)

let subst theta seq = Pair.map (Sl_form.subst theta) seq

let subst_tags tagpairs (l,r) = (Sl_form.subst_tags tagpairs l, r)

(* (l',r') *)
(* ------- *)
(* (l,r)   *)
(* meaning l  |- l' *)
(* and     r' |- r  *)

let subsumed (l,r) (l',r') = 
  Sl_form.subsumed l' l && Sl_form.subsumed_upto_tags r r'

let subsumed_upto_tags (l,r) (l',r') = 
  Sl_form.subsumed_upto_tags l' l && Sl_form.subsumed_upto_tags r r'

let norm s = Pair.map Sl_form.norm s               
