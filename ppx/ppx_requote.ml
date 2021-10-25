open Ppxlib

let (%) f g x = f (g x)

module List = struct
  include List

  let rec fold f =
    function [] -> Fun.id | x :: xs -> fold f xs % f x

  let rec drop_while f =
    function [] -> [] | x :: xs when f x -> drop_while f xs | xs -> xs
end

module Char = struct
  include Char

  let is_ascii_hspace = function
   | ' ' | '\t' -> true
   | _ -> false
end

module String = struct
  include String

  let slice_from n line =
    if n >= String.length line then "" else
    String.sub line n (String.length line - n)

  let for_all f s =
    let l = String.length s in
    let rec loop i = i = l || f s.[i] && loop (i + 1) in
    loop 0
end

module Flags = struct

  type t = {
    unflow: bool;
    left: int;
    top: int;
    bottom: int;
  }

  let default = {
    unflow = false;
    left = 0;
    top = 0;
    bottom = 0;
  }

  module Arg = struct
    let int ~min arg =
      (match int_of_string arg with
       | arg when arg >= min -> arg
       | _ ->
          Printf.ksprintf failwith "must be greater or equal to %d" min
       | exception Failure _ ->
          failwith "integer expected")
  end

  let add ~loc flag flags =
    if flag = "" then flags else
    (match String.index_opt flag '=' with
     | None ->
        (match flag with
         | "unflow" -> {flags with unflow = true}
         | _ -> Location.raise_errorf ~loc "Invalid flag %s." flag)
     | Some i ->
        let arg = String.sub flag (i + 1) (String.length flag - i - 1) in
        (try
          (match String.sub flag 0 i with
           | "left" -> {flags with left = Arg.int ~min:0 arg}
           | "top" -> {flags with top = Arg.int ~min:0 arg}
           | "bottom" -> {flags with bottom = Arg.int ~min:(-1) arg}
           | flag -> Location.raise_errorf ~loc "Invalid flag %s." flag)
         with Failure msg ->
            Location.raise_errorf ~loc
              "Invalid argument in flag %s: %s" flag msg))

end

let pop_if_empty = function
 | line :: lines when String.for_all Char.is_ascii_hspace line -> lines
 | lines -> lines

let nonempty ~loc line =
  let l = String.length line in
  if l = 0 then None else
  if Char.is_ascii_hspace line.[l - 1] then
    Location.raise_errorf ~loc "Trailing space"
  else
    Some line

let count_leading_spaces ?loc line =
  let l = String.length line in
  let rec loop i =
    if i = l then assert false else
    (match line.[i] with
     | ' ' -> loop (i + 1)
     | '\t' -> Location.raise_errorf ?loc "Tabular indentation is unsupported."
     | _ -> i)
  in
  loop 0

let unflow =
  let concat lines' =
    (match List.rev lines' with
     | [] -> assert false
     | line :: lines -> String.concat " " (line :: List.map String.trim lines))
  in
  let push paras' lines' = Some (concat lines') :: None :: paras' in
  let rec loop paras' lines' = function
   | [] ->
      if lines' = [] then List.rev paras' else
      List.rev (push paras' lines')
   | None :: lines ->
      if lines' = [] then loop paras' [] lines else
      loop (push paras' lines') [] lines
   | Some line :: lines ->
      loop paras' (line :: lines') lines
  in
  loop [] []

let requote ~loc quote_content =
  let flags, lines =
    (match String.split_on_char '\n' quote_content with
     | header :: lines ->
        let header = String.split_on_char ';' header in
        let flags = List.fold (Flags.add ~loc) header Flags.default in
        (flags, lines)
   | _ ->
      Location.raise_errorf ~loc
        "The %%requote content must start with a header line.")
  in
  (* The last line may have trailing space if empty, for the rest reject
   * trailing space and turn empty lines into [None]. *)
  let lines = lines
    |> List.rev
    |> pop_if_empty
    |> List.rev_map (nonempty ~loc)
  in
  let left_margin =
    List.fold_left min max_int
      (List.map (count_leading_spaces ~loc) (List.filter_map Fun.id lines))
  in
  let lines = lines
    |> List.map (Option.map (String.slice_from left_margin))
    |> (if flags.Flags.unflow then unflow else Fun.id)
    |> List.drop_while Option.is_none
    |> List.rev_map (Option.map ((^) (String.make flags.Flags.left ' ')))
    |> List.drop_while Option.is_none
    |> List.rev_append (List.init (flags.Flags.bottom + 1) (Fun.const None))
    |> List.rev
    |> List.rev_append (List.init flags.Flags.top (Fun.const None))
  in
  String.concat "\n" (List.map (Option.value ~default:"") lines)

let requote_line ~loc quote_content =
  (match String.split_on_char '\n' quote_content with
   | ("" :: lines) ->
      lines
        |> List.map String.trim
        |> List.filter ((<>) "")
        |> String.concat " "
   | _ ->
      Location.raise_errorf ~loc
        "The %%requote.line content must start with an empty header line.")

let expand ~loc ~path:_ f s =
  let (module Builder) = Ast_builder.make loc in
  Builder.estring (f ~loc s)

let pattern = Ast_pattern.(single_expr_payload (estring __))

let requote_extension =
  Extension.declare "requote" Extension.Context.expression pattern
    (expand requote)

let requote_line_extension =
  Extension.declare "requote.line" Extension.Context.expression pattern
    (expand requote_line)

let rules = [
  Context_free.Rule.extension requote_extension;
  Context_free.Rule.extension requote_line_extension;
]
let () = Driver.register_transformation "ppx_requote" ~rules
