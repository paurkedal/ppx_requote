open Alcotest

let test_defaults () =
  check string "same value"
    "Keep\n\
     \n\
    \  - this item, and\n\
    \  - this item,\n\n\
     and don't\n\
     \n\
    \    let loopy () =\n\
    \      loopy ()\n"
    {%requote|
      Keep

        - this item, and
        - this item,

      and don't

          let loopy () =
            loopy ()|}

let test_unflow () =
  check string "same value"
    "\n\
    \   The first line of the first paragraph with\n\
     \n\
    \     “an indented quotation”\n\
     \n\
    \ and a following text.\n\
     \n\
    \   A second paragraph."
    {%requote|unflow;left=1;top=1;bottom=-1

        The first line of
      the first paragraph with

          “an indented
           quotation”

      and a following text.

        A second paragraph.
    |}

let test_line () =
  check string "same value"
    "SELECT * FROM package WHERE name ILIKE 'ppx_%' ORDER BY name LIMIT 10"
    {%requote.line|

      SELECT * FROM package
               WHERE name ILIKE 'ppx_%'

        ORDER BY name
        LIMIT 10

    |}

let tests = [
  "defaults", `Quick, test_defaults;
  "unflow", `Quick, test_unflow;
  "line", `Quick, test_line;
]

let () = Alcotest.run "ppx_requote" ["main", tests]
