" Fodlgang
"
" desc.:
"   Better Vim folding defaults
"   `:help fodlgang`

" Avoid loading the script twice.
" Note that the variable name should be changed since this is global.
if exists("g:loaded_fodlgang")
  finish
endif
let g:loaded_fodlgang = 1

" Keymappings

" set fodlgang_map_keys=0
" in .vimrc to disable plugin keymappings
if !exists('g:fodlgang_map_keys')
  let g:fodlgang_map_keys = 1
endif
if g:fodlgang_map_keys
  nnoremap - zm
  nnoremap _ zM
  nnoremap = zr
  nnoremap + zR
  nnoremap <silent> <Space> @=(foldlevel('.') ? (foldclosed('.') < 0 ? 'zc' : 'zO' ) : 'l')<CR>
endif

" Helper functions

function! IndentLevel(lnum)
  return indent(a:lnum) / &shiftwidth
endfunction

function! NextNonBlankLine(lnum)
  let numlines = line('$')
  let current = a:lnum + 1

  while current <= numlines
    if getline(current) =~? '\v\S'
      return current
    endif

    let current += 1
  endwhile

  return -2
endfunction

" Set better foldexpr function
" Modified foldexpr from http://learnvimscriptthehardway.stevelosh.com/chapters/49.html

set foldmethod=expr
set foldexpr=GetLineFoldLevel(v:lnum)

function! GetLineFoldLevel(lnum)
  let line = getline(a:lnum)

  " Set foldlevel 'undefined' for blank lines so they share foldlevel with prev or next line
  if line =~? '\v^\s*$'
    return '-1'
  endif

  let curr_indent = IndentLevel(a:lnum)
  let next_indent = IndentLevel(NextNonBlankLine(a:lnum))

  " Fold #regions
  if curr_indent > 0 && line =~? '#region'
    let curr_indent -= 1
  endif

  " Fold block comments
  let has_comment_start = line =~? '/\*'
  let has_comment_end = line =~? '\*/'

  " Opening comment line /*...
  if has_comment_start && !has_comment_end
    let curr_indent += 1
    return '>' . curr_indent
  endif

  " Closing comment line ...*/
  if !has_comment_start && has_comment_end
    let curr_indent += 1
    return '<' . curr_indent
  endif

  " Intermediate comment line *...
  if line =~? '^\s*\*'
    return '-1'
  endif

  " Include closing bracket lines in the previous fold
  if line =~? '\v^\s*[\}\]\)]'
    let curr_indent += 1
  endif

  " Include block opening lines (i.e. function signature, if/for/while declaration) in the following fold
  if next_indent > curr_indent
    return '>' . next_indent
  endif

  return curr_indent
endfunction

" Set better foldtext function

set foldtext=MyFoldText()

function! MyFoldText()
  let line = getline(v:foldstart)
  let text = join(getline(v:foldstart, v:foldend))
  let numLines = v:foldend - v:foldstart + 1
  let numChars = strlen(substitute(text, '\v\s+', '', 'g')) " number of non-whitespace chars

  " Fold text for /* ... */ -style block comments
  if match(line, '\v^\s*(/\*)[*/]*\s*$') == 0
    let leader = substitute(text, '\v^(\s*)([/*]*).*$', '\1\2', '')         " get initial space and opening comment characters
    let truncatedText = substitute(text, '\v^(.{,40})(\w*).*$', '\1\2', '') " truncate text to 40 characters, breaking at end of word
    let cleanedText = substitute(truncatedText, '\v(\s|/|*)+', ' ', 'g')    " replace whitespace and /* characters with a single space
    let sub = leader . cleanedText . '... ' . numLines . 'l ' . numChars . 'c */'

  " Fold text for codeblocks enclosed in ({[]}) brackets
  else
    let sub = line
    let startbrace = substitute(line, '\v^.*\{\s*$', '{', 'g')
    if startbrace == '{'
      let line = getline(v:foldend)
      let endbrace = substitute(line, '\v^\s*\}(.*)$', '}', 'g')
      if endbrace == '}'
        let n = v:foldend - v:foldstart + 1
        let sub = sub.substitute(line, '\v^\s*\}(.*)$', '... ' . numLines . 'l ' .numChars . 'c ...}\1', 'g')
      endif
    endif
  endif
  " replace trailing ------- with trailing space
  return sub . repeat(' ', 10000)
endfunction