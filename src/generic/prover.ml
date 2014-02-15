open Lib
open Util
open Symbols

  (* a proof is a map from int to proof_nodes, and proof_nodes have edges  *)
  (* to other proof_nodes by indicating the Blist.find_index of the child proof_node  *)
  (* in the map this will simplify dumping the proof to the model checker  *)

module Make(Seq: Sigs.SEQUENT)(Defs: Sigs.DEFINITIONS) =
  struct
    type sequent = Seq.t
    type ind_def_set = Defs.t

    type match_fun = Seq.t -> Seq.t -> TagPairs.t option
    type axiom_fun = Seq.t -> bool
    type axiom = axiom_fun * string
    type rule_app = (Seq.t * TagPairs.t * TagPairs.t) list
    type rule_fun = Seq.t -> rule_app list
    type abd_inf_fun = Seq.t -> ind_def_set -> ind_def_set list
    type abd_match_fun = Seq.t -> Seq.t -> ind_def_set -> ind_def_set list
    type gen_fun = Seq.t -> ind_def_set -> (rule_app * ind_def_set) list

      
    let descr_axiom ax = snd ax

    module Node = Proofnode.Make(Seq)

    module Proof = Proof.Make(Proofnode.Make(Seq))
    type proof = Proof.t
            
    type proof_transformer =
      ?backlinkable:bool -> proof -> int -> (proof * int list) Zlist.t
    type abd_proof_transformer =
      ?backlinkable:bool ->
        proof -> int -> ind_def_set -> (proof * int list * ind_def_set) Zlist.t
    type gen_proof_transformer =
      | InfRule of proof_transformer
      | AbdRule of abd_proof_transformer
    type proof_rule = gen_proof_transformer * string

    let step = ref 0
    let axiomset = ref ([] : axiom list)
    let ruleset = ref ([]: proof_rule list)
    let ancestral_links_only = ref false
    let minbound = ref 1
    let maxbound = ref 12
    let lazy_soundness_check = ref false
    let backtrackable_backlinks = ref false
    let expand_proof = ref false

    (* FIXME remove/redesign "backlinkable" *)
    let is_backlinkable n =
      Node.is_open n ||
      (Node.is_inf n (* && let (_,_,_,_,b) = Node.dest_inf n in b *))

    (* due to divergence between proof tree depth and search depth *)
    (* remember last successful search depth *)
    let last_search_depth = ref 0

    (* auxiliary functions and constructors *)
    let mk_axiom axf descr = (axf, descr)
    let dest_axiom ax = ax

    let descr_rule (_, d) = d
    let bracket_rule r = bracket (descr_rule r)
    let bracket_axiom x = bracket (descr_axiom x)
    let latex_bracket_rule r = latex_bracket (descr_rule r)
    let latex_bracket_axiom x = latex_bracket (descr_axiom x)

    let get_ancestry idx prf =
      let rec aux acc idx n =
        let par_idx = Node.get_par n in
        let parent = Proof.find par_idx prf in
        let acc = (par_idx, parent)::acc in
        if par_idx=idx then acc else aux acc par_idx parent in
      aux [] idx (Proof.find idx prf)
    
    (* makes a proof node that is an axiom node if an axiom exists for it *)
    (* or an open node if no axiom applies *)
    let mk_node par_idx seq =
      let f ax = Option.pred (fun ax' -> (fst (dest_axiom ax')) seq) ax in
      match Blist.find_first f !axiomset with
        | None -> Node.mk_open seq par_idx
        | Some ax -> Node.mk_axiom seq par_idx (descr_axiom ax) 


    let pp_proof = Proof.pp
    let print_proof proof = print_endline (Proof.to_string proof)
    let to_melt = Proof.to_melt
    let melt_proof ch p = ignore (Latex.to_channel ~mode:Latex.M ch (to_melt p))
    (* print proof stats on stdout *)
    let print_proof_stats proof =
      let size = Proof.size proof in
      (* let depth = depth_of_proof proof in *)
      let links = Proof.no_of_backlinks proof in
      print_endline
        ("Proof has " ^ (string_of_int size) ^
         " nodes and a depth of " ^ (string_of_int !last_search_depth) ^
         " and " ^ (string_of_int links) ^ " back-links.")

    (* let add_to_graph par_idx prf' seq' idx'=     *)
    (*   Proof.add idx' (mk_node par_idx seq') prf' *)

    (* this is the user-visible constructor *)
    let mk_inf_rule rl d =
      let rec transf ?(backlinkable=true) prf idx =
        let n = Proof.find idx prf in
        let seq = Node.get_seq n in
        let par_idx = Node.get_par n in
        let apps = rl seq in
        if apps=[] then Zlist.empty else
        let fresh_idx = Proof.fresh_idx prf in
        let apply l =
          let (premises, tvs, tps) = Blist.unzip3 l in
					let () = debug (fun () -> "InfRule(" ^ d ^ ")\n  " ^
					  (Seq.to_string seq) ^ "\n>>>\n  " ^
						(Blist.to_string "; " Seq.to_string premises) ^ "\n") in
          let prem_idxs = Blist.range fresh_idx premises in
          let prem_ns = Blist.map (fun seq' -> mk_node idx seq') premises in
          let n' = Node.mk_inf seq par_idx (Blist.zip3 prem_idxs tvs tps) d backlinkable in
          let prf = Proof.add_inf idx n' (Blist.combine prem_idxs prem_ns) prf in
          let prem_idxs =
            Blist.filter (fun i -> Node.is_open (Proof.find i prf)) prem_idxs in
          (prf, prem_idxs) in
        Zlist.map apply (Zlist.of_list apps) in
      (InfRule(transf), d)

    let mk_back_rule matches d =
      let rec transf ?backlinkable:bool prf idx =
        let n = Proof.find idx prf in
        let par_idx = Node.get_par n in 
        let seq = Node.get_seq n in
        let m = if !ancestral_links_only then 
            get_ancestry idx prf 
          else 
            Proof.to_list prf in
        let l = Zlist.of_list  m in
        (* optimization: remove self before trying anything *)
        let l = Zlist.filter (fun (idx',n') -> idx<>idx' && is_backlinkable n') l in
        let l = Zlist.map (fun (i,n') -> (i, n', matches seq (Node.get_seq n'))) l in
        let l = Zlist.filter (fun (_, _, b) -> Option.is_some b) l in
        let l =
          Zlist.map
            begin fun (j, n', tvs) ->
              (n', Proof.add_backlink idx
                (Node.mk_backlink seq par_idx j (Option.get tvs) d) prf)
            end
            l in
        let l = Zlist.filter (fun (_,p) -> Proof.check p) l in
				let l = Zlist.map
				  begin fun (n',p) ->
						let () = debug (fun () -> "BackRule("^d^")\n  " ^
						  (Seq.to_string seq) ^ "\n>>>\n  " ^ (Seq.to_string (Node.get_seq n')) ^ "\n")
						in (p,[])
					end
					l in
        if !backtrackable_backlinks then
          l
        else
          (* postpone emptiness check via laziness *)
          lazy (Lazy.force (
						if Zlist.is_empty l then l else
							(Zlist.cons (Zlist.hd l) Zlist.empty)))
      and rule = (InfRule(transf), d) in
      rule

    let mk_abd_inf_rule rl d =
      let rec transf ?backlinkable:bool prf idx defs =
        let n = Proof.find idx prf in
        let (seq,parent,_) = Node.dest n in 
        let apps = rl seq defs in
        if apps=[] then Zlist.empty else
        let fresh_idx = Proof.fresh_idx prf in
        let prf = 
          Proof.add_abd idx (Node.mk_abd seq parent fresh_idx d) 
            (fresh_idx, mk_node idx seq)
            prf in
        Zlist.map
				  begin fun newdefs ->
						let () = debug (fun () -> "AbdInf(" ^ d ^")\n  " ^
						  (Seq.to_string seq) ^ "\n") in
						(prf,[fresh_idx],newdefs)
					end
					(Zlist.of_list apps)
      and rule = (AbdRule(transf), d) in
      rule

    let mk_abd_back_rule rl d =
      let rec transf ?backlinkable:bool prf idx defs =
        let n = Proof.find idx prf in
        let (seq,parent,_) = Node.dest n in 
        let fresh_idx = Proof.fresh_idx prf in
        let prf = 
          Proof.add_abd idx (Node.mk_abd seq parent fresh_idx d) 
            (fresh_idx, mk_node idx seq)
            prf in
        let m = if !ancestral_links_only then 
            get_ancestry idx prf 
          else 
            Proof.to_list prf in
        let l = Zlist.of_list m in
        (* optimization: remove self before trying anything *)
        let l = Zlist.filter
				  (fun (idx',n) -> idx<>idx' && fresh_idx<>idx' && is_backlinkable n) l in
        let l = Zlist.map (fun (_,m) -> Zlist.of_list (rl seq (Node.get_seq m) defs)) l in
        let l = Zlist.flatten l in
        Zlist.map (fun newdefs -> (prf, [fresh_idx], newdefs)) l
      and rule = (AbdRule(transf), d) in
      rule

    let mk_gen_rule rl d =
      let rec transf ?(backlinkable=true) prf idx defs =
        let n = Proof.find idx prf in
        let (seq,parent,_) = Node.dest n in 
        let apps = rl seq defs in
        if apps=[] then Zlist.empty else
        let fresh_idx = Proof.fresh_idx prf in
        let apply (l,defs') =
          let (premises, tvs, tps) = Blist.unzip3 l in
          let prem_idxs = Blist.range fresh_idx premises in
          let prem_ns = Blist.map (fun seq' -> mk_node idx seq') premises in
          let n' = Node.mk_inf seq parent (Blist.zip3 prem_idxs tvs tps) d backlinkable in
          let prf = Proof.add_inf idx n' (Blist.combine prem_idxs prem_ns) prf in
          let prem_idxs =
            Blist.filter (fun i -> Node.is_open (Proof.find i prf)) prem_idxs in
          (prf, prem_idxs,defs') in
        Zlist.map apply (Zlist.of_list apps)
      and rule = (AbdRule(transf), d) in
      rule

    (* check whether the subtree rooted at idx is closed *)
    (* i.e. contains no Open nodes *and* *)
    (* is non-backtrackable, i.e. contains no backlinks if *)
    (* backtrackable_backlinks is set to true *)
    let is_closed_at idx prf =
      let rec aux idx' =
        let n = Proof.find idx' prf in
        if Node.is_axiom n then true else
        if Node.is_open n then false else
        if Node.is_backlink n then not (!backtrackable_backlinks) else
        Blist.for_all aux (Node.get_succs n) in 
      aux idx
    
    (* this is for internal use only *)
    (* NB: this is not the inverse of mk_inf_rule *)
    let dest_rule (tr, d) = match tr with
      | AbdRule _ -> failwith "dest_rule"
      | InfRule(rf) -> (rf, d)
    let dest_abdrule (tr, d) = match tr with
      | InfRule _ -> failwith "dest_abdrule"
      | AbdRule(rf) -> (rf, d)
    let is_abdrule (tr, _) = match tr with
      | AbdRule _ -> true
      | InfRule _ -> false
    let is_infrule (tr, _) = match tr with
      | AbdRule _ -> false
      | InfRule _ -> true

    let expand_proof_state prf prf_depth goals =
      (* let () = assert (not (Proof.is_closed prf) && goals<>[]) in *)
      (* idx is the goal being closed and goal_depth is its depth *)
      let ((idx,goal_depth), goals) = Blist.decons goals in
      (* let () = assert (Node.is_open (Proof.find idx prf) && prf_depth >= goal_depth) in *)
      let new_goal_depth = goal_depth+1 in
      let new_prf_depth = max prf_depth new_goal_depth in
      let f rl =
        let (r, _) = dest_rule rl in
        let apps = Zlist.map
          begin fun (p',g') ->
            (p', new_prf_depth, (Blist.map (fun j -> (j,new_goal_depth)) g') @ goals)
          end
          (r prf idx) in
        (* Zlist.filter                                                         *)
        (*   begin fun (_,d',g') ->                                             *)
        (*     d'<= !maxbound && Blist.for_all (fun (_,gd) -> gd < !maxbound) g' *)
        (*   end                                                                *)
          apps in
      ((prf, idx), Zlist.flatten (Zlist.map f (Zlist.of_list !ruleset)))

    exception Continue

    let idfs seq =
      let bound = ref !minbound in
      let start = Proof.mk (mk_node 0 seq) in
      if Proof.is_closed start then (last_search_depth := 0 ; Some start) else
      let stack = ref [expand_proof_state start 0 [(0,0)]] in
      let found = ref None in
      let frontier = ref [] in
      while !bound <= !maxbound && Option.is_none !found &&
        (!stack <> [] || !frontier <> []) do
        try
          if !stack=[] then
            begin
              (* finished current depth, increase and Blist.repeat *)
              bound := 1 + !bound;
              stack := Blist.rev !frontier;
              frontier := [];
              raise Continue
            end ;
          (* idx points to node being closed *)
          let ((_, idx) as par, next) = Blist.hd !stack in
          let () = stack := Blist.tl !stack in
          if Zlist.is_empty next then
            (* no applications left, go to next set of applications *)
              raise Continue ;
          (* next rule application *)
          let (p,d,g) = Zlist.hd next in
          (* let () = assert (d <= !bound) in                                 *)
          (* let () = assert (Blist.for_all (fun (_,gd) -> gd <= !bound) g) in *)
          (* push remaining applications *)
          let () = stack := (par, Zlist.tl next) :: !stack in
          if g=[] then
            begin
              (* no subgoals left, so it must be a closed proof *)
              (* assert (Proof.is_closed p) ; *)
              found := Some (p,d);
              raise Continue
            end ;
          (* let () = assert (not (Proof.is_closed p)) in *)
          let () = if !do_debug then
            begin
              print_endline ("Expanding node: " ^ (string_of_int (fst (Blist.hd g)))) ;
              print_proof p
            end in
          if Blist.exists (fun (_,gd) -> gd = !bound) g then
            begin
              (* if any of the open goals is at the current depth *)
              (* then keep for later *)
              frontier := (expand_proof_state p d g) :: !frontier ;
              raise Continue
            end ;
          if is_closed_at idx p then
            begin
              (* last application resulted in no new open subgoals *)
              (* thus we will pop all generators of applications *)
              (* that are parents of the current one *)
              (* and whose current goal is open *)
              (* this is equivalent to a prolog cut over the other possible *)
              (* closed proofs of these goals *)
              let ancestry = get_ancestry idx p in
              let ancestry = (idx, (Proof.find idx p))::ancestry in
              let ancestry =
                Blist.filter (fun (i,_) -> is_closed_at i p) ancestry in
              (* FIXME make this depend on proper parenthood *)
              let keep ((p',_),_) =
                Blist.for_all
                  begin fun (i, n) ->
                    not (Proof.mem i p') ||
                    not (Node.is_open (Proof.find i p')) ||
                    not (Seq.equal (Node.get_seq n) (Node.get_seq (Proof.find i p')))
                  end
                  ancestry in
              stack := Blist.filter keep !stack ;
            end ;
          stack := (expand_proof_state p d g) :: !stack
        with Continue -> ()
      done ;
      match !found with
        | None -> None
        | Some (p, d) -> last_search_depth := d ; Some p

    module Seq_tacs =
      struct
        let try_tac rl seq =
          let apps = rl seq in
          if apps=[] then
						[ [ (seq, TagPairs.mk (Seq.tags seq), TagPairs.empty) ] ]
					else
						apps

				let opt rl seq =
					[ (seq, TagPairs.mk (Seq.tags seq), TagPairs.empty) ]
					::
					(rl seq)

        let apply_rule_to_subgoal (rule:rule_fun) (seq,tv,tp) =
          let fix_subgoal (seq', tv', tp') =
            (seq',
            TagPairs.compose tv tv',
            TagPairs.union_of_list
              [
                TagPairs.compose tp tp';
                TagPairs.compose tv tp';
                TagPairs.compose tp tv'
              ]
            ) in
          Blist.map (fun l -> Blist.map fix_subgoal l) (rule seq)

        let apply_rule_on_application r2 subgoals =
          let apps = Blist.map (fun a -> apply_rule_to_subgoal r2 a) subgoals in
          Blist.map Blist.flatten (Blist.choose apps)

        let then_tac (r1:rule_fun) r2 seq =
          Blist.flatten
					  (Blist.map (fun a -> apply_rule_on_application r2 a) (r1 seq))

        let rec first (l:rule_fun list) seq = match l with
          | [] -> []
          | h::t -> match h seq with
            | [] -> first t seq
            | apps -> apps

        let angelic_or_tac (l:rule_fun list) seq =
					Blist.flatten (Blist.map (fun rl -> rl seq) l)

        let repeat_tac rl seq =
          let apps = ref (rl seq) in
					if !apps=[] then [] else
          let cont = ref true in
          let () = while !cont do
            cont := false ;
            apps := Blist.flatten
              (Blist.map
                (fun app ->
                  let res = apply_rule_on_application rl app in
                  if res=[] then [app] else (cont := true ; res))
                !apps)
          done in
          (* this check is important for performance *)
          !apps

        let rec seq = function
        	| [] -> failwith "seq"
        	| [r] -> r
        	| r::rs -> then_tac r (seq rs)


    end

    module Proof_tacs =
      struct
        let lift (f:proof_transformer) =
          fun ?backlinkable prf idx (defs:Defs.t) ->
            Zlist.map
              (fun (prf,i) -> (prf,i,defs)) (f ?backlinkable prf idx)

        let gen_lift ((rl, d): proof_rule) =
          let new_rl = match rl with
            | AbdRule(rf) -> rf
            | InfRule(rf) -> lift rf in
          (AbdRule(new_rl), d)

        let try_tac (rl, d) =
          let new_rl = match rl with
            | InfRule(rf) -> InfRule(
                fun ?backlinkable prf idx -> lazy (
                  let r = rf ?backlinkable prf idx in
                  Lazy.force
                    (if Zlist.is_empty r then
											Zlist.of_list [ (prf, [idx]) ]
										else
											r)))
            | AbdRule(rf) -> AbdRule(
                fun ?backlinkable prf idx defs -> lazy (
                  let r = rf ?backlinkable prf idx defs in
                  Lazy.force (
                    if Zlist.is_empty r then
											Zlist.of_list [(prf,[idx],defs)]
                    else
											r))) in
          (new_rl, "Try " ^ (bracket d))

				let opt (rl, d) =
          let new_rl = match rl with
            | InfRule(rf) -> InfRule(
                fun ?backlinkable prf idx ->
									lazy (Lazy.force
                    (Zlist.cons (prf, [idx]) (rf ?backlinkable prf idx))))
            | AbdRule(rf) -> AbdRule(
                fun ?backlinkable prf idx defs ->
									lazy (Lazy.force
                    (Zlist.cons (prf, [idx], defs) (rf ?backlinkable prf idx defs)))) in
          (new_rl, "Try " ^ (bracket d))

        let apply_to_subgoals (rl:proof_transformer) (prf, subgoals) =
          let newapps = Blist.fold_left
            (* close one subgoal each time *)
            (fun apps idx ->
              Blist.flatten
                (* actually apply the rule *)
                (Blist.map
                  (fun (oldprf, opened) ->
                    (* add new subgoals to the list of opened ones *)
                    Blist.map
                      (fun (newprf, newsubgoals) -> (newprf, newsubgoals::opened))
                      (Zlist.to_list (rl ~backlinkable:false oldprf idx)))
                apps))
            [ (prf, []) ]
            subgoals in
          Zlist.map
            (fun (newprf,opened) -> (newprf, Blist.flatten (Blist.rev opened)))
            (Zlist.of_list newapps)

        let abd_apply_to_subgoals (rl:abd_proof_transformer) (prf,subgoals,defs) =
          let newapps = Blist.fold_left
            (* close one subgoal each time *)
            (fun apps idx ->
              Blist.flatten
                (* actually apply the rule *)
                (Blist.map
                  (fun (oldprf,opened,olddefs) ->
                    (* add new subgoals to the list of opened ones *)
                    Blist.map
                      (fun (newprf, newsubgoals, newdefs) ->
                        (newprf, newsubgoals::opened, newdefs))
                      (Zlist.to_list (rl ~backlinkable:false oldprf idx olddefs)))
                apps))
            [ (prf, [], defs) ]
            subgoals in
          Zlist.map
            (fun (newprf,opened,defs) -> (newprf, Blist.flatten (Blist.rev opened),defs))
            (Zlist.of_list newapps)

        let then_tac (rl,d) (rl',d') =
          let d'' = (bracket d) ^ " Then " ^ (bracket d') in
          match (rl,rl') with
            | (InfRule(rf), InfRule(rf')) ->
              let rf'' ?backlinkable prf idx =
                let first = rf ?backlinkable prf idx in
                Zlist.flatten (Zlist.map (fun a -> apply_to_subgoals rf' a) first) in
              (InfRule(rf''), d'')
            | (InfRule(rf), AbdRule(arf')) ->
              let rf'' ?backlinkable prf idx defs =
                let first = (lift rf) ?backlinkable prf idx defs in
                Zlist.flatten (Zlist.map (fun a -> abd_apply_to_subgoals arf' a) first) in
              (AbdRule(rf''), d'')
            | (AbdRule(arf), InfRule(rf')) ->
              let rf'' ?backlinkable prf idx defs =
                let first = arf ?backlinkable prf idx defs in
                Zlist.flatten (Zlist.map (fun a -> abd_apply_to_subgoals (lift rf') a) first) in
              (AbdRule(rf''), d'')
            | (AbdRule(arf), AbdRule(arf')) ->
              let rf'' ?backlinkable prf idx defs =
                let first = arf ?backlinkable prf idx defs in
                Zlist.flatten (Zlist.map (fun a -> abd_apply_to_subgoals arf' a) first) in
              (AbdRule(rf''), d'')

        let always_fail =
          (InfRule(fun ?(backlinkable=true) _ _ -> Zlist.empty), "")

        let angelic_or_tac l =
          if l=[] then always_fail else
          if Blist.for_all is_infrule l then
          begin
            let (rl, dl) = Blist.split (Blist.map dest_rule l) in
            let g ?backlinkable prf idx =
              Zlist.flatten
                (Zlist.map
                  (fun f -> f ?backlinkable prf idx) (Zlist.of_list rl)) in
            (InfRule(g), "Ang. Or " ^ (Blist.to_string ", " bracket dl))
          end
          else
          begin
            let (rl, dl) =
              Blist.split (Blist.map dest_abdrule (Blist.map gen_lift l)) in
            let g ?backlinkable prf idx defs =
              Zlist.flatten
                (Zlist.map
                  (fun f -> f ?backlinkable prf idx defs) (Zlist.of_list rl)) in
            (AbdRule(g), "Ang. Or " ^ (Blist.to_string ", " bracket dl))
          end

        let first l =
          if l=[] then always_fail else
          if Blist.for_all is_infrule l then
          begin
            let (rl, dl) = Blist.split (Blist.map dest_rule l) in
            let g ?backlinkable prf idx =
              let l =
                Zlist.map (fun f -> f ?backlinkable prf idx) (Zlist.of_list rl) in
              match Zlist.find_first (fun apps -> not (Zlist.is_empty apps)) l with
							  | None -> Zlist.empty
								| Some apps -> apps in
            (InfRule(g), "Or " ^ (Blist.to_string ", " bracket dl))
          end
          else
          begin
            let (rl, dl) =
              Blist.split (Blist.map dest_abdrule (Blist.map gen_lift l)) in
            let g ?backlinkable prf idx defs =
              let l =
                Zlist.map (fun f -> f ?backlinkable prf idx defs) (Zlist.of_list rl) in
              match Zlist.find_first (fun apps -> not (Zlist.is_empty apps)) l with
							  | None -> Zlist.empty
								| Some apps -> apps in
            (AbdRule(g), "Or " ^ (Blist.to_string ", " bracket dl))
          end


        let repeat_tac (rl,d) = match rl with
					| InfRule(rf) ->
						begin
              let rf' ?backlinkable prf idx =
                let state = ref (rf ?backlinkable prf idx) in
                let progress = ref true in
                let apply ((prf',subgoals) as p) =
                  lazy ( Lazy.force (
                    if subgoals=[] then Zlist.of_list [p] else
                    let r = apply_to_subgoals rf p in
                    if Zlist.is_empty r then
                      Zlist.of_list [p]
                    else
                      (progress := true ; r)
    						  )) in
                while !progress do
                  progress := false ;
                  state := Zlist.flatten (Zlist.map apply !state) ;
                done ;
                !state in
              (InfRule(rf'), "Repeat " ^ (bracket d))
						end
					| AbdRule(rf) ->
						begin
              let rf' ?backlinkable prf idx defs =
                let state = ref (rf ?backlinkable prf idx defs) in
                let progress = ref true in
                let apply ((prf',subgoals,_) as p) =
                  lazy ( Lazy.force (
                    if subgoals=[] then Zlist.of_list [p] else
                    let r = abd_apply_to_subgoals rf p in
                    if Zlist.is_empty r then
                      Zlist.of_list [p]
                    else
                      (progress := true ; r)
    						  )) in
                while !progress do
                  progress := false ;
                  state := Zlist.flatten (Zlist.map apply !state) ;
                done ;
                !state in
              (AbdRule(rf'), "Repeat " ^ (bracket d))
						end

        let rec seq = function
        	| [] -> failwith "seq"
        	| [r] -> r
        	| r::rs -> then_tac r (seq rs)

			end


		(* FIXME sync other prover with abductive one *)
		type app_state =
			{
				prf : proof;
				depth : int;
				goals : (int * int) list;
				defs : Defs.t
			}
		let mk_app p d g defs = { prf=p; depth=d; goals=g; defs=defs }

		type abd_proof_state =
			{
				seq_no : int ;
				par : int ;
				idx : int;
				apps : app_state Zlist.t
			}

		let state_seq_no = ref 0

		let mk_state par idx apps =
			{
				seq_no = (incr state_seq_no; !state_seq_no);
				par=par; idx=idx; apps=apps
			}

		let pop_parents sn stack =
			let rec loop aux s = function
				| [] -> Blist.rev aux
				| p::ps ->
					if p.seq_no = s then
						loop aux p.par ps
					else
						loop (p::aux) s ps in
			loop [] sn stack

    let abd_expand_proof_state par_seq_no app mk_rules =
      let () = assert (not (Proof.is_closed app.prf) && app.goals<>[]) in
      (* idx is the goal being closed and goal_depth is its depth *)
      let ((idx,goal_depth), goals) = Blist.decons app.goals in
      let () = assert (Node.is_open (Proof.find idx app.prf) && app.depth >= goal_depth) in
      let new_goal_depth = goal_depth+1 in
      let new_prf_depth = max app.depth new_goal_depth in
      let f rl = match (fst rl) with
        | InfRule(r) ->
          Zlist.map
            begin fun (p',g') ->
              mk_app
							  p'
								new_prf_depth
								(Blist.rev_append (Blist.rev_map (fun j -> (j,new_goal_depth)) g') goals)
								app.defs
            end
            (r ~backlinkable:true app.prf idx)
        | AbdRule(r) ->
          Zlist.map
            begin fun (p',g',defs') ->
							mk_app
              	p'
								new_prf_depth
								(Blist.rev_append (Blist.rev_map (fun j -> (j,new_goal_depth)) g') goals)
								defs'
            end
            (r ~backlinkable:true app.prf idx app.defs) in
      mk_state
			  par_seq_no
				idx
				(Zlist.flatten (Zlist.map f (Zlist.of_list (mk_rules app.defs))))

    let abduce seq initial_defs mk_rules acceptable =
      let bound = ref !minbound in
      let start = Proof.mk (mk_node 0 seq) in
      if Proof.is_closed start then (last_search_depth := 0 ; Some (start, initial_defs)) else
      let stack = ref [abd_expand_proof_state 0 (mk_app start 0 [(0,0)] initial_defs) mk_rules] in
      let found = ref None in
      let frontier = ref [] in
      while !bound <= !maxbound && Option.is_none !found &&
        (!stack <> [] || !frontier <> []) do
        try
          if !stack=[] then
            begin
              (* finished current depth, increase and Blist.repeat *)
              incr bound;
              stack := Blist.rev !frontier;
              frontier := [];
              raise Continue
            end ;
          (* idx points to node being closed *)
          (* let ((_, idx) as par, next) = Blist.hd !stack in *)
          let proof_state = Blist.hd !stack in
          let () = stack := Blist.tl !stack in
          (* if no applications left, go to next set of applications *)
          if Zlist.is_empty proof_state.apps then raise Continue ;
          (* next rule application *)
          let app = Zlist.hd proof_state.apps in
          let () = assert (app.depth <= !bound) in
          let () = assert (Blist.for_all (fun (_,gd) -> gd <= !bound) app.goals) in
          (* push remaining applications *)
          let () = stack := {proof_state with apps=Zlist.tl proof_state.apps} :: !stack in
          if app.goals=[] then
            begin
              (* no subgoals left, so it must be a closed proof *)
              assert (Proof.is_closed app.prf) ;
              if acceptable app.defs then found := Some (app.prf,app.depth,app.defs);
							(* NOTE: in case not acceptable we do not pop parents as we may need to backtrack *)
              raise Continue
            end ;
          let () = assert (not (Proof.is_closed app.prf)) in
          let () = if !do_debug then
            begin
              print_endline ("Expanding node: " ^ (string_of_int (fst (Blist.hd app.goals)))) ;
              print_proof app.prf
            end in
          if Blist.exists (fun (_,gd) -> gd = !bound) app.goals then
            begin
              (* if any of the open goals is at the current depth *)
              (* then keep for later *)
              frontier := (abd_expand_proof_state proof_state.seq_no app mk_rules) :: !frontier ;
              raise Continue
            end ;
          if is_closed_at proof_state.idx app.prf then
            begin
              (* last application resulted in no new open subgoals *)
              (* thus we will pop all generators of applications *)
              (* that are parents of the current one *)
              (* this is equivalent to a prolog cut over the other possible *)
              (* closed proofs of these goals *)
						  stack := pop_parents proof_state.seq_no !stack
            end ;
          stack := (abd_expand_proof_state proof_state.seq_no app mk_rules) :: !stack
        with Continue -> ()
      done ;
      match !found with
        | None -> None
        | Some (p, d, defs) -> last_search_depth := d ; Some (p, defs)
  end
