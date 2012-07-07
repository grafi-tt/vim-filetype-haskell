" Vim indent: haskell
" Version: @@VERSION@@
" Copyright (C) 2008-2010 kana <http://whileimautomaton.net/>
" License: So-called MIT/X license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

" Notation:
" * "#" indicates a whitespace for indentation.
" * "<|>" indicates the cursor position after automatic indentation.
" * "<*>" indicates the cursor position before automatic indentation.

if exists('b:did_indent')
  finish
endif

setlocal autoindent
setlocal indentexpr=GetHaskellIndent()
setlocal indentkeys=!^F,o,O,=where,0<Bar>

setlocal expandtab
setlocal softtabstop=2
setlocal shiftwidth=2

let b:undo_indent = 'setlocal '.join([
\   'autoindent<',
\   'expandtab<',
\   'indentexpr<',
\   'indentkeys<',
\   'shiftwidth<',
\   'softtabstop<',
\ ])




function! GetHaskellIndent()
  let thisLineNum = v:lnum
  let previousLineNum = v:lnum - 1
  let thisLine = getline(thisLineNum)
  let previousLine = getline(previousLineNum)

    " NB: thisLine may have trailing characters.  For example: iloveyou<Left><Return>
  let atNewLine = (col('.') - 1) == matchend(thisLine, '^\s*')
  if atNewLine
    " Case: 'class' statement
    "   class Monad m where<*>
    "   ##<|>
    if previousLine =~# '\v^\s*<class>.*<where>'
      return indent(previousLineNum) + &l:shiftwidth
    endif

    " Case: 'instance' statement
    "   instance Eq Foo where<*>
    "   ##<|>
    if previousLine =~# '\v^\s*<instance>.*<where>'
      return indent(previousLineNum) + &l:shiftwidth
    endif

    " Case: 'do' notation (1)
    "   f a b = do<*>
    "   ##<|>
    if previousLine =~# '\v^\s*.{-}<do>\s*(--.*)?$'
      return indent(previousLineNum) + &l:shiftwidth
    endif

    " Case: 'do' notation (2)
    "   f a b = do g a<*>
    "   ###########<|>
    let xs = matchlist(previousLine, '\v^(\s*.{-}<do>\s*)\S')
    if xs != []
      return len(xs[1])
    endif

    " Case: open curly bracket not closed on this line
    let R = '\v^.*\zs\{[^}]*$'
    let x = match(previousLine, R)
    if x != -1
      b:startIndent
      return x
    endif

    " Case: open paren not closed on this line
    let R = '\v^.*\zs\([^)]*$'
    let x = match(previousLine, R)
    if x != -1
      b:startIndent
      return x
    endif

    " Case: open square bracket not closed on this line
    let R = '\v^.*\zs\[[^\]]*$'
    let x = match(previousLine, R)
    if x != -1
      b:startIndent
      return x
    endif

    " Case: Function definition (1)
    "   f a b =<*>
    "   ##<|>
    if previousLine =~# '\v^\s*<\S.*\s+\=\s*(--.*)?$'
      return indent(previousLineNum) + &l:shiftwidth
    endif

    " Case: Function definition (2)
    "   f a b = g a >>=<*>
    "   ########<|>
    let R = '\v^(.{-}\s+\=\s+)\S.{-}[^A-Za-z0-9_"'')}\]]\s*(--.*)?$'
    let xs = matchlist(previousLine, R)
    if xs != []
      return len(xs[1])
    endif

    " Case: 'where' clause (2)
    "   foo = bar . baz
    "   ##where<*>
    "   ####<|>
    if previousLine =~# '\v^\s*<where>\s*(--.*)?$'
      return indent(previousLineNum) + &l:shiftwidth
    endif

    " Otherwise: Keep the previous indentation level.
    return -1
  else
    " Case: 'where' clause (1)
    "   foo = bar . baz
    "   ##where<*><|>
    if thisLine =~# '\v^\s*<where>'
      return indent(prevnonblank(previousLineNum)) + &l:shiftwidth
    endif

    " Case: Guards (1)
    "   f a b
    "   ##|<*><|>
    if thisLine =~# '\v^\s*\|'
      let np = prevnonblank(previousLineNum)
      let after_guard_p = (getline(np) =~# '\v^\s*\|')
      return indent(np) + (after_guard_p ? 0 : &l:shiftwidth)
    endif


    " Otherwise: Keep the previous indentation level.
    return -1
  endif
endfunction


let b:indentScope = []
let b:did_indent = 1

" __END__
" vim: foldmethod=marker
