@default_files = ('examples/example.tex', 'examples/example-beamer.tex', 'magic-haskell-doc.tex');
$pdf_mode = 1;
$out_dir = 'build';
$dvi_mode = 0;
$pdflatex = 'pdflatex %O -shell-escape %S';
$clean_ext = 'mhs.ghci mhs.out';
$postscript_mode = 0;
ensure_path('TEXINPUTS', './xlistings//');
