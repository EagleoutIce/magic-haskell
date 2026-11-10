# Changelog

## Unreleased

- Initial version, extracted from the `haskell-listings` package of the functional programming lecture and rebuilt on top of `xlistings`.
- `magic-haskell-ghc`: a port of `hasktex` that batches all queries into one GHCi session per run, reads its answers catcode-safe, and only reruns GHCi if the queries changed.
- Links are generated from Hackage into `magic-haskell-links.cfg` by `tools/generate-links.sh`, which verifies every link; identifiers are matched as whole words and nothing is linked within strings or comments.
- `\mhsEval` and the `ghcisession` environment evaluate Haskell with GHCi; sessions are animated on beamer overlays.
- Animated sessions reserve their final layout on every overlay (also before `start`): steps yet to come are typeset invisibly instead of as blank lines, so slides no longer move as a session grows.
- Linked names get a slight, colorable underline (option `underline`).
- The documentation lists the link database from its real data.
- Names, types, and constructors defined in the document link to their definition; `\mhsModules` and the key `modules` choose among the modules exporting a name.
- Sessions support `:{ ... :}` blocks and repeated lines; exceptions count as errors; edited files are re-evaluated.
- The regression tests cover names, operators, options, markers, the database, definitions, and GHC sessions.
- Constructors of `data` and `newtype` link to their definition; all bindings of a `where` or `let` block are local definitions; `mhsdefinitions=local` keeps the definitions of a listing within it.
- Definitions work across beamer overlays (also with `\only`, `onlyenv`, and the optional `code-animation` package), and later redefinitions are respected.
- `\mhsGhcEvalInto` stores a value; `\mhsGhcTime` and `\mhsGhcMemory` give the time (ms) and memory (bytes) of the last evaluation, `\mhsGhcTimeText` and `\mhsGhcMemoryText` format them.
- The documentation has an index of commands, options, and keys.
