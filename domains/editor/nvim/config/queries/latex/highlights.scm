; Minimal latex highlights for tree-sitter-latex 0.6.0 - safe subset
(command_name) @function @nospell
(comment) @comment @spell
(text) @spell
(label_definition
  command: _ @function.macro)
(label_reference
  command: _ @function.macro)
(citation
  command: _ @function.macro)
(section
  command: _ @keyword)
(subsection
  command: _ @keyword)
(chapter
  command: _ @keyword)
(begin
  command: _ @keyword)
(end
  command: _ @keyword)
(math_environment
  begin: _ @punctuation.delimiter
  end: _ @punctuation.delimiter)
(inline_formula
  "$" @punctuation.delimiter)
(displayed_equation
  "$$" @punctuation.delimiter)
