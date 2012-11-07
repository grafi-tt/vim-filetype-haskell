" Vim indent: haskell
" Version: @@VERSION@@
" Copyright (C) 2012 grafi <http://grafi.jp/>
"               2008-2010 kana <http://whileimautomaton.net/>
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
setlocal indentkeys=!^F,o,O,0=where,0=in,0<Bar>,0<=>
setlocal expandtab

let b:undo_indent = 'setlocal '.join([
\   'autoindent<',
\   'expandtab<',
\   'indentexpr<',
\   'indentkeys<',
\ ])

function! GetHaskellOffset(previousLineNum)
    let previousLine = getline(a:previousLineNum)
    let offset = 0

    let R = '\v(.{-})<(do|of|let|where|\(|\)|\{|\}|\[|\])>(\s*)'
    let curOffset = 0
    let curLeftOffset = 0
    let curMatched = ''
    let insideComment = 0
    let tokenList = []

    let xs = matchlist(previousLine, R, curOffset)
    while insideComment == 0 && xs != []
        let curLeftOffset = curOffset + len(xs[1])
        let curOffset += len(xs[0])
        let curMatched = xs[2]
        if synIDattr(synID(a:previousLineNum, curLeftOffset, 1), 'name') =~ 'Comment$'
            let insideComment = 1
        elseif synIDattr(synID(a:previousLineNum, curLeftOffset+1 , 1), 'name') =~ 'String$'
            let xs = matchlist(previousLine, R, curOffset)
        else
            call add(tokenList, [curMatched, curOffset, curLeftOffset])
            let xs = matchlist(previousLine, R, curOffset)
        endif
    endwhile

    let parenDepth = 0
    let activeTokenListReversed = []

    while tokenList != []
        let lastToken = remove(tokenList, -1)
        if lastToken[1] =~# '\v[]})]'
            let parenDepth = 1
        endif
        while parenDepth > 0
            let lastToken = remove(tokenList, -1)
            if lastToken[1] =~# '\v[]})]'
                let parenDepth += 1
            elseif lastToken[1] =~# '\v[[{(]'
                let parenDepth -= 1
            endif
        endwhile
        call add(activeTokenListReversed, lastToken)
    endwhile

    if activeTokenListReversed == []
        return 0
    else
        let [token, offset, leftOffset] = activeTokenListReversed[0]
        if (len(activeTokenListReversed) != 1)
            let [oldToken, oldOffset, oldLeftOffset] = activeTokenListReversed[1]
        else
            let [oldToken, oldOffset, oldLeftOffset] = ['', 0, 0]
        endif
        if match(previousLine, '\v($|[-{]-)', offset) != -1
            if token == 'do'
                return oldOffset + &l:shiftwidth
            elseif token == 'when'
                return oldOffset + &l:shiftwidth + &l:shiftwidth
            elseif token == 'let'
                return leftOffset + &l:shiftwidth
            elseif token == 'of'
                let leftOffset = matchend(previousLine, '\v^.*case') - 1
                return leftOffset + &l:shiftwidth
            elseif token =~# '\v[[{(]'
                return oldOffset + &l:shiftwidth + &l:shiftwidth
            endif
        else
            if token =~# '\v[[{(]'
                return offset + &l:shiftwidth
            endif
        endif
    endif
    return 0
endfunction

function! GetHaskellIndent()
    let thisLineNum = v:lnum
    let previousLineNum = v:lnum - 1
    let thisLine = getline(thisLineNum)
    let previousLine = getline(previousLineNum)

    " Case: this line is inside a string or comment
    if synIDattr(synID(thisLineNum, col('.')), 'name') =~ '\(String\|Comment\)$'
        return -1
    endif

    " NB: thisLine may have trailing characters.  For example: iloveyou<Left><Return>
    let atNewLine = (col('.') - 1) == matchend(thisLine, '^\s*')

    if atNewLine
        " Case: previous line is constructed by only comment
        if synIDattr(synID(previousLineNum, matchend(previousLine, '^\s*')+1), 'name') =~ 'Comment$'
            return -1
        endif

        " Case: specially handle the line contains only 'where'
        "   foo = bar . baz
        "   ##where<*>
        "   ####<|>
        if previousLine =~# '\v^\s*<where>\s*(--.*)?$'
          return indent(previousLineNum) + &l:shiftwidth
        endif

        " Case: 'do', 'of', 'let', 'where' and parensises
        let offset = GetHaskellOffset(previousLineNum)

        " Case: Function definition (1)
        "   f a b =<*>
        "   ##<|>
        if previousLine =~# '\v^\s*<\S.*\s+\=\s*(--.*)?$'
            return indent(previousLineNum) + offset + &l:shiftwidth
        endif

        " Case: Function definition (2)
        "   f a b = g a >>=<*>
        "   ########<|>
        " TODO the regex for symbols is not sufficient
        let R = '\v^(.{-}\s+\=\s+)\S.{-}[^A-Za-z0-9_"'')}\]]\s*(--.*)?$'
        let xs = matchlist(previousLine, R)
        if xs != []
            return len(xs[1])
        endif

        " Otherwise: Keep the previous indentation level.
        if offset
            return indent(previousLineNum) + offset
        else
            return -1
        endif

    else
        " Case: 'where' clause start
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

        " Case: Equal (1)
        "   f a b
        "   =<*>####<|>
        " TODO

        " Case: in
        "   let a = 1
        "       b = 2
        "   <|>####in<*>
        " TODO
        " to deal with `let` within do block, consider indent level

        " Case: close comment
        " {-
        "   je t'aime
        "   je vous aime
        " <|>##-}<*>
        " TODO

        " Otherwise: Keep the previous indentation level.
        return -1

    endif
endfunction


let b:indentScope = []
let b:did_indent = 1

" __END__
" vim: foldmethod=marker
