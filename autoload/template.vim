" Simple and flexible template engine.
" Version: 0.3.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

let s:nomodeline = 703 < v:version || (v:version == 703 && has('patch438'))
let s:loading_template = ''

" Core functions. {{{1
function! template#load(...)
  let empty_buffer = line('$') == 1 && strlen(getline(1)) == 0
  let pattern = get(a:000, 0, 0)
  let lnum = get(a:000, 1, 0)
  let force = get(a:000, 2, 0)
  if !force && !empty_buffer
    return
  endif
  let tmpl = template#search(empty(pattern) ? expand('%:p') : pattern)
  if tmpl == ''
    if &verbose && !empty(pattern)
      echohl ErrorMsg
      echomsg 'template: Template file was not found.'
      echohl None
    endif
    return
  endif

  call cursor(lnum, 1)
  silent keepalt :.-1 read `=tmpl`
  if empty_buffer
    silent $ delete _
    1
  endif

  let loading_pre = s:loading_template
  let s:loading_template = tmpl

  if getline('.') =~ '^:'
    let [save_reg, save_reg_type] = [getreg('"'), getregtype('"')]
    silent .;/^[^:]\|^$\|^:\s*fini\%[sh]\>/-1 delete "
    if getline('.') =~# ':\s*fini\%[sh]\>'
      delete _
    endif

    let code = @"
    call setreg('"', save_reg, save_reg_type)

    let temp = tmpl . '.vim'
    if glob(temp) != ''
      let temp = tempname()
    endif

    call writefile(split(code, "\n"), temp)
    try
      if s:nomodeline
        doautocmd <nomodeline> User plugin-template-preexec
      else
        doautocmd User plugin-template-preexec
      endif
      source `=temp`
    catch
      echoerr v:exception
    finally
      call delete(temp)
    endtry
  endif
  if s:nomodeline
    doautocmd <nomodeline> User plugin-template-loaded
  else
    doautocmd User plugin-template-loaded
  endif

  let s:loading_template = loading_pre
endfunction

function! template#search(pattern)
  if !exists('g:template_basedir') || empty(a:pattern)
    return ''
  endif
  " Matching from tail.
  let target = s:reverse(s:to_slash_path(a:pattern))

  let longest = ['', 0]  " ['template file name', match length]
  for i in split(globpath(g:template_basedir, g:template_files), "\n")
    let i = s:to_slash_path(i)
    if isdirectory(i) || i !~ g:template_free_pattern
      continue
    endif
    " Make a pattern such as the following.
    " From: 'path/to/a_FREE_file.vim' (FREE is a free pattern.)
    " To:   '^\Vmiv.elif_\(\.\{-}\)_a\%[/ot/htap]'
    " TODO: cache?
    let l = map(split(i, g:template_free_pattern),
      \ 's:reverse(escape(v:val, "\\"))')
    let [head, rest] = matchlist(l[0], '\v(.{-})(/.*)')[1:2]
    let l[0] = head . '\%[' . substitute(rest, '[][]', '[\0]', 'g') . ']'
    let matched = matchlist(target, '^\V' . join(reverse(l), '\(\.\{-}\)'))
    let len = len(matched) ?
      \ strlen(matched[0]) - strlen(join(matched[1:], '')) : 0
    if longest[1] < len
      let longest = [i, len]
    endif
  endfor
  return longest[0]
endfunction

function! template#loading()
  return s:loading_template
endfunction


" Misc functions. {{{1
" Return the reversed string.
function! s:reverse(str)
  return join(reverse(split(a:str, '\zs')), '')
endfunction

" Unify pass separator to a slash.
function! s:to_slash_path(path)
  if has('win16') || has('win32') || has('win64')
    return substitute(a:path, '\\', '/', 'g')
  endif
  return a:path
endfunction

" Complete function for :TemplateLoad
function! template#complete(lead, cmd, pos)
  let lead = escape(matchstr(a:cmd, 'T\%[emplateLoad]!\?\s\+\zs.*$'), '\')
  let pat = '[/\\][^/\\]*' . g:template_free_pattern
  let list = map(filter(split(globpath(g:template_basedir, g:template_files),
    \ "\n"), '!isdirectory(v:val)'), 'v:val[match(v:val, pat):]')
  return filter(list, 'v:val =~ "^\\V" . lead')
endfunction


let &cpo = s:save_cpo
