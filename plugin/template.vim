" Simple and flexible template engine.
" Version: 0.2.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

if exists('g:loaded_template') || v:version < 702
  finish
endif
let g:loaded_template = 1

let s:save_cpo = &cpo
set cpo&vim



" Core functions. {{{1
function! s:load_template(file, force) " {{{2
  let empty_buffer = line('$') == 1 && strlen(getline('1')) == 0
  if !a:force && !empty_buffer
    return
  endif
  let tmpl = s:search_template(a:file)
  if tmpl == ''
    if &verbose && !empty(a:file)
      echohl ErrorMsg
      echomsg 'template: The template file is not found.'
      echohl None
    endif
    return
  endif

  silent keepalt :.-1 read `=tmpl`
  if empty_buffer
    silent $ delete _
    1
  endif

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
      doautocmd User plugin-template-preexec
      execute 'source' temp
    catch
      echoerr v:exception
    finally
      call delete(temp)
    endtry
  endif
  doautocmd User plugin-template-loaded
endfunction



function! s:search_template(file) " {{{2
  if !exists('g:template_basedir')
    return ''
  endif
  " Matching from tail.
  let target = s:reverse(s:to_slash_path(empty(a:file) ?
    \ expand('%:p') : fnamemodify(a:file, ':p')))

  let longest = ['', 0] " ['template file name', match length]
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



" Misc functions. {{{1
" Return the reversed string.
function! s:reverse(str) " {{{2
  return join(reverse(split(a:str, '\zs')), '')
endfunction


" Unify pass separator to a slash.
function! s:to_slash_path(path) " {{{2
  if has('win16') || has('win32') || has('win64')
    return substitute(a:path, '\\', '/', 'g')
  endif
  return a:path
endfunction



" Complete function for :TemplateLoad
function! s:TemplateLoad_complete(lead, cmd, pos) " {{{2
  let lead = escape(matchstr(a:cmd, 'T\%[emplateLoad]!\?\s\+\zs.*$'), '\')
  let pat = '[/\\][^/\\]*' . g:template_free_pattern
  let list = map(filter(split(globpath(g:template_basedir, g:template_files),
    \ "\n"), '!isdirectory(v:val)'), 'v:val[match(v:val, pat):]')
  return filter(list, 'v:val =~ "^\\V" . lead')
endfunction



" Default settings. {{{1
function! s:set_default(var, val)
  if !exists(a:var) || type({a:var}) != type(a:val)
    unlet! {a:var}
    let {a:var} = a:val
  endif
endfunction



call s:set_default('g:template_basedir', &runtimepath)
call s:set_default('g:template_files', 'template/**')
call s:set_default('g:template_free_pattern', 'template')



delfunction s:set_default
" Defining commands and autocmds. {{{1
command! -nargs=? -bang -bar -complete=customlist,s:TemplateLoad_complete
  \ TemplateLoad call s:load_template(<q-args>, <bang>0)



augroup plugin-template
  autocmd!
  autocmd BufReadPost,BufNewFile * TemplateLoad
  " To avoid the error message when there is no event.
  autocmd User plugin-template-* :
augroup END



let &cpo = s:save_cpo
unlet s:save_cpo
