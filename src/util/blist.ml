include List

let foldl = fold_left
let foldr = fold_right

let map f xs = rev (rev_map f xs)
let map2 f xs ys = rev (rev_map2 f xs ys)
let append xs ys = rev_append (rev xs) ys
let flatten xs = rev (fold_left (fun ys x -> rev_append x ys) [] xs)

let to_string sep conv xs = String.concat sep (map conv xs)

let rec pp pp_sep pp_elem fmt = function
  | [] -> ()
  | [h] -> Format.fprintf fmt "%a" pp_elem h
  | h::t ->
    Format.fprintf fmt "%a%a%a" pp_elem h pp_sep () (pp pp_sep pp_elem) t

let cons x xs = x::xs
let decons = function
  | x::xs -> (x,xs)
  | _ -> invalid_arg "decons"

let repeat a n =
  if n<0 then invalid_arg "repeat" else
  let rec aux a acc = function
    | 0 -> acc
    | m -> aux a (a::acc) (m-1) in
  aux a [] n

let rev_filter p xs =
  foldl (fun acc x -> if p x then x::acc else acc) [] xs  

let but_last = function
  | [] -> []
  | xs -> rev (tl (rev xs))

let range n xs =
  rev (snd (foldl (fun (m,ys) _ -> (m+1, m::ys)) (n,[]) xs))

let remove_nth n xs = 
  if n<0 then invalid_arg "Blist.remove_nth" else
  rev (snd (foldl (fun (m,ys) x -> (m+1, if m=n then ys else x::ys)) (0,[]) xs))

let replace_nth z n xs = 
  if n<0 then invalid_arg "Blist.replace_nth" else
  rev (snd (foldl (fun (m,ys) x -> (m+1, if m=n then z::ys else x::ys)) (0,[]) xs))

let indices xs = range 0 xs

let rec find_first f = function
  | [] -> None
  | x::xs -> match f x with
    | None -> find_first f xs
    | y -> y

let rec find_some p = function
  | [] -> None
  | x::xs -> if p x then Some x else find_some p xs

let find_index p l =
  let rec aux p n = function
    | [] -> raise Not_found
    | x::xs -> if p x then n else aux p (n+1) xs in
  aux p 0 l

let find_indexes p xs = 
  rev (snd (foldl (fun (m,ms) x -> (m+1, if p x then m::ms else ms)) (0,[]) xs))

let unzip3 xs = 
  let (bs,cs,ds) = 
    foldl (fun (bs,cs,ds) (b,c,d) -> (b::bs, c::cs, d::ds)) ([], [], []) xs in
  (rev bs, rev cs, rev ds)

let zip3 xs' ys' zs' =
  let rec aux acc xs ys zs =   
    match (xs, ys, zs) with
      | ([], [], []) -> acc
      | (b::bs, c::cs, d::ds) -> aux ((b,c,d)::acc) bs cs ds  
      | _ -> invalid_arg "zip3" in
  rev (aux [] xs' ys' zs') 

let cartesian_product xs ys =
  foldl (fun acc x -> foldl (fun acc' y -> (x,y)::acc') acc ys) [] xs

let cartesian_hemi_square xs =
  let rec chs acc = function
    | [] -> acc
    | el::tl ->
      chs (fold_left (fun acc' el' -> (el,el')::acc') acc tl) tl
  in chs [] xs

(* this should be tail recursive *)
let choose lol =
  let _,lol =
    foldl
      (fun (r,a) l -> not r, (if r then rev l else l)::a)
      (true,[]) lol in
  foldl
    (fun ll -> foldl (fun tl e -> foldl (fun t l -> (e::l)::t) tl ll) [])
    [[]] lol
