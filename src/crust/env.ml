exception Missing_binding of string
module EnvMap = struct
  type 'b t = (string, 'b) Hashtbl.t
  let find h k = 
    try
      Hashtbl.find h k
    with Not_found ->
      raise (Missing_binding ("No binding found for object: " ^ k))
  let fold = Hashtbl.fold
  let mem = Hashtbl.mem
end

type adt_env_t = (string,Ir.type_expr) Hashtbl.t
let adt_env = Hashtbl.create 10;;
let fn_env = Hashtbl.create 10;;
let abstract_fn_env = Hashtbl.create 10;;
let abstract_impl = Hashtbl.create 10;;
let associated_types = Hashtbl.create 10;;
let static_env = Hashtbl.create 10;;
let driver_env = ref [];;

let is_abstract name = Hashtbl.mem abstract_impl name

let rec set_env = function 
  | [] -> ()
  | ((`Enum_def {
      Ir.enum_name = adt_name;
      _
    }) as adt)::t
  | ((`Struct_def {
      Ir.struct_name = adt_name;
      _
    }) as adt)::t -> 
    Hashtbl.add adt_env adt_name adt;
    set_env t
  | (`Fn f)::t -> 
    Hashtbl.add fn_env f.Ir.fn_name f;
    (match f.Ir.fn_impl with
     | None -> ()
     | Some { Ir.abstract_name = a_name } ->
       if Hashtbl.mem abstract_impl a_name then
         Hashtbl.replace abstract_impl a_name @@ f.Ir.fn_name :: (Hashtbl.find abstract_impl a_name)
       else
         Hashtbl.add abstract_impl a_name [ f.Ir.fn_name ]
    );
    set_env t
  | `Assoc_type ({ Types.abstract_name = a_name; _ } as a)::t ->
    (if Hashtbl.mem associated_types a_name then 
      Hashtbl.replace associated_types a_name @@ a::(Hashtbl.find associated_types a_name)
    else
      Hashtbl.add associated_types a_name [ a ]
    );
    set_env t
  | `Static (name,ty,expr)::t ->
    Hashtbl.add static_env name (ty,expr);
    set_env t
  (* these are ignored for the moment *)
  | `Abstract_Type _::t -> set_env t
  | `Abstract_Fn f::t ->
    Hashtbl.add abstract_fn_env f.Ir.afn_name f;
    set_env t
  | `Driver e :: t -> begin
      set_env t;
      driver_env := e :: !driver_env;
    end

let init_opt = ref false;;

let is_abstract_fn = Hashtbl.mem abstract_impl
let is_static_var = Hashtbl.mem static_env



let get_adt_drop t_name = 
  let t_def = Hashtbl.find adt_env t_name in
  match t_def with
  | `Enum_def e -> e.Ir.drop_fn
  | `Struct_def e -> e.Ir.drop_fn

let crust_init_name =
  let comp = Lazy.from_fun (fun () ->
      let init_regex = Str.regexp "^.+crust_init$" in
      let a = Hashtbl.fold (fun k _ accum -> 
          if Str.string_match init_regex k 0 then
            k::accum
          else
            accum
        ) fn_env [] in
      match a with
      | [] -> None
      | [t] -> Some t
      | _ -> failwith "Multiple crust_init definitions found!"
    )
  in
  fun () -> Lazy.force comp


let crust_init_name_e () = 
  match crust_init_name () with
  | Some s -> s
  | None -> failwith "Crust init not found"
