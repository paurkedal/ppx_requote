(lang dune 2.0)

(name ppx_requote)
(license Apache-2.0)
(authors "Petter A. Urkedal <paurkedal@gmail.com>")
(maintainers "Petter A. Urkedal <paurkedal@gmail.com>")
(source (github "paurkedal/ppx_requote"))

(generate_opam_files true)

(package
 (name ppx_requote)
 (synopsis "Reformatting of quoted strings")
 (description "\
    This PPX implements basic reformatting of quoted string literals to allow \
    them to be layed out in source code for easy reading and editing")
 (depends
  (ocaml (>= 4.11.2))
  dune
  (alcotest :with-test)
  (odoc :with-doc)
  ppxlib))
