" Simple and flexible template engine.
" Version: 0.3.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

if exists('g:loaded_template') || v:version < 702
  finish
endif
let g:loaded_template = 1

let s:save_cpo = &cpo
set cpo&vim

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
command! -nargs=? -bang -bar -range -complete=customlist,template#complete
  \ TemplateLoad call template#load(<q-args>, <line1>, <bang>0)


augroup plugin-template
  autocmd!
  autocmd BufReadPost,BufNewFile * TemplateLoad
  " To avoid an error message when there is no event.
  autocmd User plugin-template-* :
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
