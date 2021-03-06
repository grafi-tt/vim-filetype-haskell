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
setlocal expandtab
setlocal indentexpr=GetHaskellIndent()
setlocal indentkeys=!^F,o,O,0=where,0=in,0=deriving,0<Bar>,0<=>

let b:undo_indent = 'setlocal '.join([
\   'autoindent<',
\   'expandtab<',
\   'indentexpr<',
\   'indentkeys<',
\ ])

let s:maxBack = 50


" parse tokens for caluculating offset, and push those to reversed list
function! s:GetHaskellOffsetTokenList(previousLineNum)
	let previousLine = getline(a:previousLineNum)

	let R = '\v(.{-})<(do|of|let|where|\(|\)|\{|\}|\[|\])>(\s*)'
	let curOffset = 0
	let curLeftOffset = 0
	let curToken = ''
	let insideComment = 0
	let tokenListRaw = []

	let matched = matchlist(previousLine, R, curOffset)
	while insideComment == 0 && matched != []
		let curLeftOffset = curOffset + len(matched[1])
		let curOffset += len(matched[0])
		let curToken = matched[2]
		if synIDattr(synID(a:previousLineNum, curLeftOffset, 0), 'name') =~ 'Comment$'
			let insideComment = 1
		elseif synIDattr(synID(a:previousLineNum, curLeftOffset+1, 0), 'name') =~ 'String$'
			let matched = matchlist(previousLine, R, curOffset)
		else
			call add(tokenListRaw, [curToken, curOffset, curLeftOffset])
			let matched = matchlist(previousLine, R, curOffset)
		endif
	endwhile

	let parenDepth = 0
	let tokenList = []

	while tokenListRaw != []
		let lastToken = remove(tokenListRaw, -1)
		if lastToken[1] =~# '\v[]})]'
			let parenDepth = 1
		endif
		while parenDepth > 0
			let lastToken = remove(tokenListRaw, -1)
			if lastToken[1] =~# '\v[]})]'
				let parenDepth += 1
			elseif lastToken[1] =~# '\v[[{(]'
				let parenDepth -= 1
			endif
		endwhile
		call add(tokenList, lastToken)
	endwhile

	return tokenList
endfunction

" returns offset caused by tokens of previous line
" if no offset is caused, returns -1
function! s:GetHaskellOffset(previousLineNum)
	let previousLine = getline(a:previousLineNum)
	let xs = s:GetHaskellOffsetTokenList(a:previousLineNum)

	if xs != []
		let [token, offset, leftOffset] = xs[0]
		if (len(xs) != 1)
			let [oldToken, oldOffset, oldLeftOffset] = xs[1]
		else
			let [oldToken, oldOffset, oldLeftOffset] = ['', 0, 0]
		endif
		if match(previousLine, '\v^($|[-{]-)', offset) != -1
			" previous line ends by matched token
			if token == 'do'
				return oldOffset + &l:shiftwidth
			elseif token == 'where'
				return oldOffset + &l:shiftwidth
			elseif token == 'let'
				return leftOffset + &l:shiftwidth
			elseif token == 'of'
				let leftOffset = matchend(previousLine, '\v^.*\zecase')
				return leftOffset + &l:shiftwidth
			elseif token =~# '\v[[{(]'
				return oldOffset + &l:shiftwidth
			endif
		else
			" previous line does not end by matched token
			if token =~# '\v[[{(]'
				return offset + &l:shiftwidth
			else
				return offset
			endif
		endif
	endif

	return -1
endfunction

function! s:GetPreviousLeftIndented(lineNum, indent)
	let curNum = a:lineNum - 1
	while (indent(curNum) > a:indent)
		if (curNum == 0 || curNum == a:lineNum - s:maxBack)
			break
		endif
		let curNum -= 1
	endwhile
	return curNum
endfunction

function! s:GetHaskellBarPos(lineNum, col)
	let max = s:GetPreviousLeftIndented(a:lineNum, a:col)
	let curNum = a:lineNum - 1
	while (curNum >= max)
		let equalPos = matchend(getline(curNum), '\v^\s*data.{-}\ze\=')
		if equalPos != -1
			return equalPos
		endif
		let guardPos = matchend(getline(curNum), '\v^.{-}%(\a|\d|\s)\ze\|%(\a|\d|\s)')
		if guardPos != -1
			return guardPos
		endif
		let curNum -= 1
	endwhile
	return -1
endfunction

function! s:GetHaskellDerivingPos(lineNum, col)
	let max = s:GetPreviousLeftIndented(a:lineNum, a:col)
	let curNum = a:lineNum - 1
	while (curNum >= max)
		let equalPos = matchend(getline(curNum), '\v^\s*%(data|newtype).{-}\ze\=')
		if equalPos != -1
			return equalPos
		endif
		let orPos = matchend(getline(curNum), '\v^\s*\ze\|')
		if orPos != -1
			return orPos
		endif
		let curNum -= 1
	endwhile
	return -1
endfunction

function! GetHaskellIndent()
	let thisLineNum = v:lnum
	let previousLineNum = v:lnum - 1
	let thisLine = getline(thisLineNum)
	let previousLine = getline(previousLineNum)

	" Case: this line is inside a string or comment
	if synIDattr(synID(thisLineNum, col('.'), 0), 'name', 0) =~ '\(String\|Comment\)$'
		return -1
	endif

	" NB: thisLine may have trailing characters.  For example: iloveyou<Left><Return>
	let atNewLine = (col('.') - 1) == matchend(thisLine, '^\s*')

	if atNewLine
		" Case: previous line is constructed by only comment
		if synIDattr(synID(previousLineNum, matchend(previousLine, '^\s*')+1, 0), 'name') =~ 'Comment$'
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
		let offset = s:GetHaskellOffset(previousLineNum)
		let defaultIndent = (offset == -1) ? indent(previousLineNum) : offset

		" Case: Function definition (1)
		"   f a b =<*>
		"   ##<|>
		if previousLine =~# '\v^\s*<\S.*\s+\=\s*(--.*)?$'
			return defaultIndent + &l:shiftwidth
		endif

		" Case: Function definition (2)
		"   f a b = g a >>=<*>
		"   ########<|>
		" TODO the regex for symbols is not sufficient
		let R = '\v^(.{-}\s+\=\s+)\S.{-}[^[:alnum:][:blank:]_"'')}\]]\s*(--.*)?$'
		let xs = matchlist(previousLine, R)
		if xs != []
			return len(xs[1])
		endif

		" Case: PreviousLine is started with guard
		if previousLine =~# '\v\s*\|'
			return 0
		endif

		" Otherwise: Return calculated offset, or previous indent level
		return defaultIndent

	else
		" Case: 'where' clause start
		"   foo = bar . baz
		"   ##where<*><|>
		if thisLine =~# '\v^\s*<where>'
			return indent(prevnonblank(previousLineNum)) + &l:shiftwidth
		endif

		" Case: Type Constructor Bar
		" Tree a = Leaf a
		"        | Node (Tree a) (Tree a)
		" Case: Guards (1)
		"   f a b
		"   ##|<*><|>
		if thisLine =~# '\v^\s*\|'
			let barPos = s:GetHaskellBarPos(thisLineNum, indent(thisLineNum))
			if barPos != -1
				return barPos
			else
				return indent(prevnonblank(previousLineNum)) + &l:shiftwidth
			endif
		endif

		" Case: Deriving
		" Tree a = Leaf a
		"        | Node (Tree a) (Tree a)
		"        deriving hoge
		if thisLine =~# '\v^\s*deriving'
			let derivingPos = s:GetHaskellDerivingPos(thisLineNum, indent(thisLineNum))
			if derivingPos != -1
				return derivingPos
			else
				return indent(prevnonblank(previousLineNum)) + &l:shiftwidth
			endif
		endif

		" Case: Equal (1)
		"   f a b
		"   =<*>####<|>
		" TODO

		" Case: in
		"   let a = 1
		"	   b = 2
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
