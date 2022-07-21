open Petrinet

type state =
  { marking: Marking.t ;
    steps: int }

type walk_result =
  | Bingo of state
  | Deadlock of state
  | Timeout of state

let state2s st = string_of_int st.steps ^ " steps. Marking = " ^ Marking.tos st.marking

let result2s = function
  | Bingo m -> "Bingo : " ^ state2s m
  | Deadlock m -> "Deadlock : " ^ state2s m
  | Timeout m -> "Timeout : " ^ state2s m

let sprinter ?(seed=0) ?timeout net init_marking p =

  let check_timeout =
    match timeout with
    | None -> fun () -> true
    | Some t ->
      let start = Unix.time () in
      let t = float_of_int t in

      fun () -> (Unix.time () -. start) < t
  in

  (*  let nb_trans = Net.nb_tr net in *)
  
  let fireables = Stepper.fireables net init_marking in

  let rec loop seed steps marking =
    if p marking then Bingo { marking ; steps }
    else
      
      let tr = Trset.pick net fireables ~start:seed in
      if tr == Net.null_tr then Deadlock { marking ; steps }
      else
        let marking = Stepper.quick_fire marking tr in
        let () = Stepper.update_fireables net marking fireables tr in

        (* Update seed *)
        let seed = abs (seed * seed - 13 * seed) in
        
        if steps land 0xfffff <> 0 || check_timeout () then loop seed (steps+1) marking else Timeout { marking ; steps }
  in

  loop seed 0 (Marking.clone init_marking)
    