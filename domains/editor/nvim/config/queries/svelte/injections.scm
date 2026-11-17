; Modern Neovim injection captures for tree-sitter-svelte 0.11.0.

((script_element
  (raw_text) @injection.content)
 (#set! injection.language "typescript"))

((raw_text_expr) @injection.content
 (#set! injection.language "javascript"))

((style_element
  (raw_text) @injection.content)
 (#set! injection.language "css"))
