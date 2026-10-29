; extends

; ----------------------------------------------------------------------------
; Haskell — angst override: distinct builtins + robust function promotion
; Upstream leaves monomorphic signatures as @variable and treats all
; (name)/(variable) as @type generically. This layer adds:
;  1. Builtin types -> @type.builtin (Constant teal)
;  2. Builtin functions -> @function.builtin (SpecialChar mauve/orange)
;  3. Any signature followed by a function/binding with same name -> @function
;     even when the type is monomorphic (a -> b, String, Int -> ...)
;  4. Optional: arrow/function types as @function signatures

; Fix overbroad (variable)@type — keep expression arguments as variables
; Upstream's (variable)@type makes `map f xs` where `f`/`xs` are variables appear as types
(apply
  argument: (variable) @variable)

(infix
  left_operand: (variable) @variable)

(infix
  right_operand: (variable) @variable)

(tuple
  (variable) @variable)

(list
  (variable) @variable)

; ----------------------------------------------------------------------------
; 1. Builtin types (Prelude + common)
; name covers most type constructors in signatures: `String`, `Int`, etc.
((name) @type.builtin
  (#any-of? @type.builtin
    "Int" "Integer" "Float" "Double" "Char" "String" "Bool" "Ordering" "IO" "Maybe" "Either" "Ordering"
    "Show" "Read" "Eq" "Ord" "Enum" "Bounded" "Functor" "Applicative" "Monad" "Monoid" "Semigroup"
    "Foldable" "Traversable" "FilePath" "Void"))

; qualified builtin types: `Prelude.String`, `Data.Maybe.Maybe`
((qualified (name) @type.builtin)
  (#any-of? @type.builtin
    "Int" "Integer" "Float" "Double" "Char" "String" "Bool" "Ordering" "IO" "Maybe" "Either"))

; constructor variants (some grammars emit constructor for type constructors)
; Note: True/False kept as @boolean (red) not @type.builtin
((constructor) @type.builtin
  (#any-of? @type.builtin
    "Just" "Nothing" "Left" "Right" "LT" "EQ" "GT"))

; True/False already @boolean in upstream, but keep builtin type path for completeness

; ----------------------------------------------------------------------------
; 2. Builtin functions / Prelude values
; plain variables
((variable) @function.builtin
  (#any-of? @function.builtin
    "putStrLn" "print" "getLine" "readLn" "readFile" "writeFile" "appendFile"
    "show" "read" "showsPrec" "showString" "showParen"
    "return" "pure" "fmap" "map" "filter" "foldr" "foldl" "foldMap" "concat" "concatMap"
    "head" "tail" "null" "length" "take" "drop" "zip" "zipWith" "enumFromTo"
    "error" "undefined" "seq" "id" "const" "flip" "curry" "uncurry"
    "maybe" "either" "fst" "snd" "not" "compare"))

; qualified builtin functions: `Prelude.putStrLn`, `Data.List.map`
((qualified (variable) @function.builtin)
  (#any-of? @function.builtin
    "putStrLn" "print" "getLine" "readLn" "show" "read" "return" "pure" "map" "filter" "foldr" "foldl"))

; applied builtin calls should also be @function.builtin (upstream uses @function.call)
((expression/variable) @function.builtin
  (#any-of? @function.builtin
    "putStrLn" "print" "getLine" "readLn" "show" "read" "return" "pure" "map" "filter"))

((expression/qualified
  (variable) @function.builtin)
  (#any-of? @function.builtin
    "putStrLn" "print" "getLine" "readLn" "show" "read" "return" "pure" "map" "filter"))

; ----------------------------------------------------------------------------
; 3. Robust function promotion: any `name :: <anything>` followed by same `name`
;    in next decl is a function, not a variable. Upstream only handles
;    quantified_type / IO / lambda. This covers `getNewUserInfo :: String -> (String,String)`
;    and `main :: IO ()` etc. without duplicating upstream heuristics.

; Top-level signatures and functions — make them consistently @function
; Any signature at top-level (declarations) is a function signature
(declarations
  (signature
    name: (variable) @function))

(declarations
  (function
    name: (variable) @function))

; signature whose type is a function arrow `a -> b` -> function
(decl/signature
  name: (variable) @function
  type: (function))

(signature
  name: (variable) @function
  type: (function))

; adjacent signature + function decl with same name -> function (covers monomorphic arrows)
((decl/signature
  name: (variable) @_sig)
  .
  (decl/function
    name: (variable) @function)
  (#eq? @_sig @function))

((signature
  name: (variable) @_sig)
  .
  (function
    name: (variable) @function)
  (#eq? @_sig @function))

; adjacent signature + bind (no patterns) with same name -> function if the type is a function/arrow
; this handles `withinNextWeek :: Day -> Bool ; withinNextWeek d = ...` inside lets as well when top-level
((decl/signature
  name: (variable) @_sig
  type: (function))
  .
  (decl/bind
    name: (variable) @function)
  (#eq? @_sig @function))

((decl/signature
  name: (variable) @_sig
  type: (type/apply))
  .
  (decl/bind
    name: (variable) @function)
  (#eq? @_sig @function))

((signature
  name: (variable) @_sig
  type: (function))
  .
  (bind
    name: (variable) @function)
  (#eq? @_sig @function))

; local_binds inside let/where: `let isValid = ...` where isValid's inferred type is function
; allow signature inside same local_binds? For now promote explicit local signatures too
((signature
  pattern: (pattern/variable) @function
  type: (function)))

; ----------------------------------------------------------------------------
; 4. Fix overbroad (variable) @type — keep let/binds as variables
; Upstream captures any (variable) as @type at line 372, making locals like
; `withinNextWeek` appear as types (olive). Re-assert bind names as @variable
; so they stay cream distinct from true types (name/constructor).
(bind
  name: (variable) @variable)

(decl/bind
  name: (variable) @variable)

; main is always a function (top-level bind, not decl/bind)
(bind
  name: (variable) @function
  (#eq? @function "main"))

; keep parameters distinct (already @variable.parameter upstream, ensure no override)
; No changes needed.

; ----------------------------------------------------------------------------
; 5. Ensure type constructors remain @type when not builtin (upstream already)
; No override needed; this file is `; extends` so upstream rules stay.

; ----------------------------------------------------------------------------
; 6. Re-assert booleans after variable fix (otherwise/True/False)
((variable) @boolean
  (#eq? @boolean "otherwise"))

((constructor) @boolean
  (#any-of? @boolean "True" "False"))
