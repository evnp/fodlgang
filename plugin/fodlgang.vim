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

function! HeaderLevel(lnum)
  " return number of leading hash signs
  " start with header size 2 to avoid collapsing standard #-prefixed comments
  return strlen(matchstr(getline(a:lnum), '\v^##+'))
endfunction

function! PrevHeaderLineNum(lnum)
  let numlines = line('$')
  let current = a:lnum - 1

  while current >= 0
    if getline(current) =~? '\v^##+'
      return current
    endif

    let current -= 1
  endwhile

  return -2
endfunction

function! NextNonBlankLineNum(lnum)
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

function! PrevNonBlankLineNum(lnum)
  let numlines = line('$')
  let current = a:lnum - 1

  while current >= 0
    if getline(current) =~? '\v\S'
      return current
    endif

    let current -= 1
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

  " Fold markdown header-deliniated sections
  let prev_header = HeaderLevel(PrevHeaderLineNum(a:lnum))
  let curr_header = HeaderLevel(a:lnum)
  if curr_header > 0
    return '>' . curr_header
  endif
  if prev_header > 0
    return prev_header
  endif

  let prev_indent = IndentLevel(PrevNonBlankLineNum(a:lnum))
  let curr_indent = IndentLevel(a:lnum)
  let next_indent = IndentLevel(NextNonBlankLineNum(a:lnum))

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
  let barChart = ''
  let i = 0
  let c = 0
  if exists('g:fodlgang_bar_chart')
    for l in getline(v:foldstart, v:foldend)
      i++
      if strlen(barChart) > 80
        break
      elseif i <= 10
        c += strlen(line)
      else
        if c < 100
          barChart .= '▁'
        elseif c < 200
          barChart .= '▂'
        elseif c < 300
          barChart .= '▃'
        elseif c < 400
          barChart .= '▄'
        elseif c < 500
          barChart .= '▅'
        elseif c < 600
          barChart .= '▆'
        elseif c < 700
          barChart .= '▇'
        else
          barChart .= '█'
        endif
        i = 0
        c = 0
      endif
    endfor
  endif

  " make sure fold preview text indentation is correct when using tabs
  let numTabs = strlen(matchstr(text, '\v^[\t]+')) " number of leading tabs
  let sub = substitute(line, '\v^[\t]+', repeat(repeat(' ', &shiftwidth), numTabs), 'g')

  " Fold text for /* ... */ -style block comments
  if match(line, '\v^\s*(/\*)[*/]*\s*$') == 0
    let leader = substitute(text, '\v^(\s*)([/*]*).*$', '\1\2', '')         " get initial space and opening comment characters
    let truncatedText = substitute(text, '\v^(.{,40})(\w*).*$', '\1\2', '') " truncate text to 40 characters, breaking at end of word
    let cleanedText = substitute(truncatedText, '\v(\s|/|*)+', ' ', 'g')    " replace whitespace and /* characters with a single space
    let sub = leader . cleanedText . '... ' . numLines . 'l ' . numChars . 'c */'

  " Fold text for codeblocks enclosed in ({[]}) brackets
  else
    let startbrace = substitute(line, '\v^.*\{\s*$', '{', 'g')
    if startbrace == '{'
      let line = getline(v:foldend)
      let endbrace = substitute(line, '\v^\s*\}(.*)$', '}', 'g')
      if endbrace == '}'
        if exists('g:fodlgang_bar_chart')
          let sub = sub.substitute(line, '\v^\s*\}(.*)$', barChart . '}\1', 'g')
        else
          let sub = sub.substitute(line, '\v^\s*\}(.*)$', '... ' . numLines . 'l ' . numChars . 'c ...}\1', 'g')
        endif
      endif
    endif
  endif
  " replace trailing ------- with trailing space
  return sub . repeat(' ', 10000)
endfunction
