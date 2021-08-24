
function! vimpad#toggle() abort
  if g:vimpad.id > 0
    call s:off()

  else
    call s:on()
  endif

endfunction

function! vimpad#on() abort
  call s:on()
endfunction

function! vimpad#off() abort
  call s:off()
endfunction

function! vimpad#refresh() abort
  if g:vimpad.id > 0
    call s:off()
    call s:on()
  endif
endfunction

let s:output_hl = 'VimpadOutput'
let s:prefix_hl = 'VimpadPrefix'
let s:suffix_hl = 'VimpadSuffix'


function! s:get_visual_selection() "{{{
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)

    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]

    return lines
    " return join(lines, "\n")
endfunction "}}}

function! s:to_execute(index, value) "{{{
  " match a line if the line starts with echo/echom/call
  let regex = '\V\^\(echo\|echom\|call\)'

  if a:value.text =~ regex
    return 1
  else
    return 0
  endif

endfunction "}}}

function! s:getline_as_dict(start, end) "{{{
  let lines = getline(1, '$')
  let lnum = 0

  let lists = []
  for line in lines
    let obj = {}
    let obj.lnum = lnum
    let obj.text = line
    call add(lists, obj)

    let lnum += 1
  endfor

  return lists
endfunction "}}}

function! s:add_padding(string, padding) "{{{
  return a:padding..a:string..a:padding
endfunction "}}}

function! s:is_in(value, list) "{{{
  return index(a:list, a:value) >= 0
endfunction "}}}

function! s:lsp_ouput(line) "{{{

  let hl = s:output_hl
  let prefix_hl = s:prefix_hl
  let prefix = 'prefix'

  if a:line.error
    let hl .= 'Error'
    let prefix_hl .= 'Error'
    let prefix .= '_error'
  endif

  let output = g:vimpad[prefix].' '.a:line.output 

  if g:vimpad.padding_count
    let output = s:add_padding(output, repeat(' ', g:vimpad.padding_count))
  else
    let output = a:line.output
  endif

  return [
        \[output, hl]
        \]
endfunction "}}}

function! s:custom_output(line) "{{{

  let hl = s:output_hl
  let prefix_hl = s:prefix_hl
  let suffix_hl = s:suffix_hl

  let prefix = 'prefix'
  let suffix = 'suffix'

  if a:line.error
    let hl .= 'Error'
    let prefix_hl .= 'Error'
    let suffix_hl .= 'Error'

    let prefix .= '_error'
    let suffix .= '_error'

  endif

  if g:vimpad.padding_count
    let output = s:add_padding(a:line.output, repeat(' ', g:vimpad.padding_count))
  else
    let output = a:line.output
  endif

  return [ 
        \[g:vimpad[prefix], prefix_hl], 
        \[output, hl], 
        \[g:vimpad[suffix], suffix_hl]
        \]

endfunction "}}}


function! s:build_output(line) "{{{

  let style = g:vimpad.style

  if a:line.error
    let style = g:vimpad.style_error
  endif

  " call Decho(style)

  let output = []

  if style ==# 'lsp'
    let output = s:lsp_ouput(a:line)

  elseif style ==# 'custom'
    let output = s:custom_output(a:line)

  endif

  if g:vimpad.space_count
    let space = repeat(' ', g:vimpad.space_count)
    call insert(output, [space])
  endif

  return output
endfunction "}}}

function! s:off() abort "{{{
  call nvim_buf_clear_namespace(0, g:vimpad.id, 0, -1)

  let g:vimpad.id = 0
endfunction "}}}

function! s:on() abort "{{{

  let lines = s:getline_as_dict(1, '$')

  call filter(lines, function('s:to_execute'))

  " let the exception go through
  try
    silent source %
  catch /.*/
  endtry

  " execute the line and add output
  for line in lines
    try
      let output = nvim_exec(line.text, 1)
      let error = 0
    catch /.*/
      " store the exception msg
      let output = v:exception
      let error = 1
    endtry
    let line.output = output
    let line.error = error
  endfor

"  call Decho(string(lines))

  let g:vimpad.id = nvim_create_namespace('vimpad')

  let bufnr = 0
  for line in lines
    let output = s:build_output(line)
    call nvim_buf_set_virtual_text(
          \bufnr, 
          \g:vimpad.id, 
          \line.lnum, 
          \output,
          \{})
  endfor

endfunction "}}}



" [TODO](2108210154)
