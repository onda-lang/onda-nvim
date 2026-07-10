" Onda indentation.
" A trailing colon starts an indented Onda block, including sections such as
" `init:` and `sample:`.

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetOndaIndent()
setlocal indentkeys=0{,0},0),0],:,0#,!^F,o,O,e
let b:undo_indent = "setlocal indentexpr< indentkeys<"

function! GetOndaIndent() abort
  let l:previous = prevnonblank(v:lnum - 1)
  if l:previous == 0
    return 0
  endif

  let l:indent = indent(l:previous)
  let l:line = substitute(getline(l:previous), '\s*#.*$', '', '')
  if l:line =~# ':\s*$'
    return l:indent + shiftwidth()
  endif

  return l:indent
endfunction
