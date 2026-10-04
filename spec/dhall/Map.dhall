-- A JSON object with arbitrary keys. dhall-to-json renders this list shape
-- as an object and json-to-dhall reads an object back into it, so maps stay
-- maps in both directions. Local on purpose: no remote Prelude import, so the
-- check needs no network inside the Nix sandbox.
\(k : Type) -> \(v : Type) -> List { mapKey : k, mapValue : v }
