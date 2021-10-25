## Synopsis

`ppx_requote` makes it easier to maintain and read quoted strings by
applying some lightweight transformations which allows a natural layout,
such as the text relative to the surrounding code.  In other words, its
purpose is to revert formatting done in the interest of code readability.

## Motivation

OCaml already comes with a flexible mechanism to filter out excessive
newlines and spaces in regular double-quoted strings, e.g.:
```ocaml
let print_program recipient =
  Printf.printf
    "#include <stdio.h>\n\n\
     int main() {\n\
    \  printf(\"Hello %s!\\n\");\n\
    \  return 0;\n\
     }"
    recipient
```
While this is fairly readable, it imposes the overhead on editors of
maintaining the various kinds of escapes.  This is solved by the
introduction of quoted strings:
```ocaml
let print_program recipient =
  Printf.printf
    {code|
#include <stdio.h>
int main() {
  printf("Hello %s!\n");
  return 0;
}
|code}
    recipient
```
However, the solution is not perfect, since we lost the ability to control
indentation, as is clearly apparent here.

The `ppx_requote` syntax extension allows adding back indentation to make
the OCaml source code more readable, without affecting the printed program:
```ocaml
let print_program recipient =
  Printf.printf
    {%requote code|
      #include <stdio.h>
      int main() {
        printf("Hello %s!\n");
        return 0;
      }
    |code}
    recipient
```

## Installation

### With `opam` on native projects

```bash
opam install ppx_requote
```

### With `esy` on native projects

```bash
esy add @opam/ppx_requote
```

## Usage

The PPX translates two extension points for strings,

  - `[%requote]` adjusts the top, left, and bottom margins, and
  - `[%requote.line]` turns a block of text into a single line.

### Adjusting Margins

The `[%requote]` extension points expects string containing a header line
followed by a multi-line body and

  - extracts options described below from the header line,
  - determines the left margin of the remaining lines, i.e. the minimum
    indentation of any non-empty line, and remove it from all lines, and
  - removes black lines before and after the text.

The resulting text will then be adjusted according to the following
semi-colon separated flags in header line (no spaces allowed):

  - `left=`*n* indents each line by *n* spaces,
  - `top=`*n* adds *n* blank lines at the top,
  - `bottom=`*n* adds *n* blank lines at the bottom, and, as a special case,
  - `bottom=-1` removes the newline from the last line.

To supplement the example in the introduction, the following self-explaining
example shows how to adjust add margins:
```ocaml
let text =
  {%requote q|left=2;top=1;bottom=1

      The margin of this quote is 4 spaces due to the following lines.
    Therefore, 2 spaces are removed from all lines to match the "left"
    margin flag.

      The "top" and "bottom" margin flags means there will be a single empty
    line above and below these paragraphs.  Without the "top" option, the
    initial empty line would have been removed.
  |q}
```

There is also an experimental `unflow` option which concatenates lines
within the same paragraph.  It should not be used in production code, since
its logic of detecting continuation lines is limited and subject to
revision.  Currently it be used to avoid spurious line breaks when a
pre-flowed text is passed to `Format.pp_print_text`, but it will not handle
markdown correctly.

### Turning a Text Block into a Single Line

The `[%requote]` extension point expects a string containing an empty header
line, reserved for future use, followed by a multi-line body, which will be
concatenated to a single line.  That is, any newline followed by zero or
more spaces will be replaced by a single space.  This can be useful e.g. to
avoid sending excessive spaces to an SQL server while keeping the source
code readable:
```ocaml
let follow =
  let req =
    Caqti_request.collect Caqti_type.string Caqti_type.string
      {%requote.line|
        SELECT t.name
          FROM object s
          JOIN arrow a ON a.source_id = s.id
          JOIN object t ON t.id = a.target_id
         WHERE s.name = $1|}
  in
  fun source ->
    Caqti_lwt.with_connection uri
      (fun (module C : Caqti_lwt.CONNECTION) -> C.collect_list req source)
```
