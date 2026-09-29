# magic-haskell

magic-haskell extends the [xlistings](https://github.com/EagleoutIce/xlistings) package with a Haskell language that automatically links "magic" names to their documentation on [Hackage](https://hackage.haskell.org) or to their definition in the document. It can also ask GHC for types, values, and whole sessions. Originally, I developed magic-haskell privately for the functional programming lecture at Ulm University.

It interacts flawlessly with the styles, line numbers, environments, inline commands, and `minted` emulation layer of xlistings, as well as with the optional [code-animation](https://github.com/EagleoutIce/code-animation) package. All of the following happens automatically for Haskell code:

- **Links to Hackage.** Known names and operators link to their documentation, from a link database of over 7000 links that can be extended easily.
- **Links and syntax highlighting for user definitions.** Functions, types, and constructors are recognized where they are defined, and every use links there, anywhere in the document and across beamer overlays.
- **Adaptive redefinitions.** After a second `data Foo`, later uses link to it, while earlier ones keep linking to the first.
- **Qualified names.** `Data.Map.insert` links sensitive to the import, also with aliases like `M.insert`.
- **Ligatures copy as text.** `f <$> xs >>= g` can be typeset with ligatures, but copies as the original text.
- **Markers.** Support for multi-line highlight segments with `|warn|head xs|warn|`, `|err|undefined|err|`, and more.
- **Answers from GHC.** We can request GHC to compute types and values during document compilation, e.g. `\mhsType{map}`.
- **GHCi sessions.** The environment `ghcisession` runs its lines in GHCi and typesets the answers, on beamer slides one overlay per step.

```latex
\usepackage[language=hs]{magic-haskell}
\usepackage{hyperref}
...
\begin{hs}
main :: IO ()
main = mapM_ print [1 .. 10]
\end{hs}
```

See [`magic-haskell-doc.tex`](magic-haskell-doc.tex) for the documentation, [`example.tex`](example.tex) and [`example-beamer.tex`](example-beamer.tex) for examples.

## Development

`xlistings` is a git submodule, clone with `--recurse-submodules` (or run `git submodule update --init`).

```sh
latexmk            # builds the examples and the documentation into build/ (needs ghc)
l3build check      # runs the regression tests in tests/ (no GHC needed)
l3build save NAME  # updates the expected output tests/NAME.tlg
```

## License

LaTeX Project Public License 1.3c, see [LICENSE](LICENSE).
