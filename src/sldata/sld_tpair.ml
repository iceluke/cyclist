open Lib
open Util
open Symbols
open MParser

module TPair = PairTypes(Sld_term)(Sld_term)

include TPair

let _unify sub_check cont state (x, y) (x', y') =
  Sld_term.unify ~sub_check ~cont:(fun state' -> Sld_term.unify ~sub_check ~cont ~init_state:state' y y') ~init_state:state x x'
   
let unify ?(order=false) 
    ?(sub_check=Sld_term.trivial_sub_check) 
    ?(cont=Sld_term.trivial_continuation)
    ?(init_state=Sld_term.empty_state) p p' =
  if order then 
    _unify sub_check cont init_state p p'
  else
    Blist.find_some (_unify sub_check cont init_state p) [ p'; Pair.swap p' ]

let order ((x,y) as pair) =
  if Sld_term.compare x y <= 0 then pair else (y,x)

let subst theta (x,y) = (Sld_term.subst theta x, Sld_term.subst theta y)
      
let to_string_sep sep p =
  let (x,y) = Pair.map Sld_term.to_string p in x ^ sep ^ y
let to_melt_sep sep p =
  let (x,y) = Pair.map Sld_term.to_melt p in Latex.concat [x; sep; y]

module FList =
  struct
    include Util.MakeFList(TPair)
    
    let rec unify_partial ?(order=false) ?(inverse=false) 
        ?(sub_check=Sld_term.trivial_sub_check)
        ?(cont=Sld_term.trivial_continuation)
        ?(init_state=Sld_term.empty_state) xs ys =
      match (xs, ys) with
      | ([], _) -> cont init_state
      | (_, []) -> None
      | (p::ps, _) ->
        Blist.find_some 
          (fun q ->
            let (x,y) = if inverse then (q,p) else (p,q) in  
            unify ~order ~sub_check
              ~cont:(fun state' -> 
                unify_partial ~order ~inverse ~sub_check ~cont ~init_state:state' ps ys) ~init_state x y) 
          ys
    
    let terms ps = 
      Blist.foldl 
        (fun a p -> Pair.fold Sld_term.Set.add p a) 
        Sld_term.Set.empty 
        ps 
  end 

