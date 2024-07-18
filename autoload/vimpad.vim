
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

function! vimpad#execute() abort
  call s:execute()
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

    " return lines
    return join(lines, "\n")
endfunction "}}}

function! s:to_execute(index, value) "{{{
  " match a line if the line starts with echo/echom/call
  let regex = '\V\^\(echo\|echom\|throw\)'

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
  if has('nvim')
    call nvim_buf_clear_namespace(0, g:vimpad.id, 0, -1)
  else
    call prop_remove('VimpadOutput', 1, line('$'))
    call prop_remove('VimpadOutputError', 1, line('$'))
  endif

  let g:vimpad.id = 0
endfunction "}}}

function! s:on() abort "{{{

  let lines = s:getline_as_dict(1, '$')

  call filter(lines, function('s:to_execute'))

  let previous_line = 1
  for line in lines
    try
      " only source until the current line from the previously executed line
      " adding one to the line.lnum produces a cleaner error code for some reason
      " although it would mean sourcing the current line twice
      " here and also with nvim_exec
      let source = 'silent ' . previous_line . ',' . (line.lnum + 1) . 'source'
      exec source

      if has('nvim')
        let output = nvim_exec(line.text, 1)
      else
        let output = execute(line.text)
      endif
      let error = 0
    catch /.*/
      " store the exception msg
      let output = v:exception
      let error = 1
    endtry

    let line.output = output
    let line.error = error

    " increment by 2 because the buffer starts from 1
    " while s:getline_as_dict() starts the line from 0
    let previous_line = line.lnum + 2
  endfor

  " removes lines if output is empty string
  call filter(lines, 'v:val.output != ""')

  if has('nvim')
    let g:vimpad.id = nvim_create_namespace('vimpad')
  elseif empty(prop_type_get('VimpadOutput', {'bufnr': bufnr()}))
    call prop_type_add('VimpadOutput',      {'bufnr': bufnr(), 'highlight': 'VimpadOutput'})
    call prop_type_add('VimpadOutputError', {'bufnr': bufnr(), 'highlight': 'VimpadOutputError'})
  endif

  let bufnr = 0
  for line in lines
    let output = s:build_output(line)

    if has('nvim')
      " nvim_buf_set_virtual_text({buffer}, {src_id}, {line}, {chunks}, {opts})
      call nvim_buf_set_virtual_text(
            \bufnr,
            \g:vimpad.id,
            \line.lnum,
            \output,
            \{})
    else
      let [text, hl] = output[0]
      let padding = g:vimpad.padding_count + 1

      " prop_add({lnum}, {col}, {props})
      call prop_add(line.lnum + 1, 0, {
            \'type': hl,
            \'text_align': 'after',
            \'text_padding_left': padding,
            \'text': text,
            \})
    endif
  endfor

endfunction "}}}

function! s:execute() abort
  let lines = s:get_visual_selection()
  let outputs = []
  try
    if has('nvim')
      let output = nvim_exec(lines, 1)
    else
      let output = trim(execute(lines))
    endif
    let outputs = split(output, "\n")
    let num = 0
    let lines = []
    for output in outputs
      let line = {}
      let line.num = num
      let line.output = output
      let line.error = 0
      call add(lines, line)
    endfor

  catch /.*/
    let lines = []
    let num = 0
    let line = {}
    let line.num = num
    let line.output = v:exception
    let line.error = 1
    call add(lines, line)
  endtry

  redraw
  for line in lines
    let output = s:build_output(line)
    for list in output
      if len(list) > 1
        exec 'echohl' list[1]
        echon list[0]
      endif
    endfor
    echo ""
  endfor


  echohl NONE
endfunction

" [TODO](2108210154)
