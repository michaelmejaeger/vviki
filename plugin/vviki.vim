" Copyright (c) 2020 Dave Gauer
" MIT License

if exists('g:loaded_vviki')
	finish
endif
let g:loaded_vviki = 1

" Initialize defaults
if !exists('g:vviki_root')
	let g:vviki_root = "~/wiki"
endif

if !exists('g:vviki_ext')
	let g:vviki_ext = ".adoc"
endif

if !exists('g:vviki_index')
    let g:vviki_index = "index"
endif

if !exists('g:vviki_conceal_links')
    let g:vviki_conceal_links = 1
endif

" Navigation history for Backspace
let s:history = []


" Supported link styles:
function! VVEnter()
	" Get path from AsciiDoc link macro
	"   link:http://example.com[Example] - external
	"   link:page[My Page]               - internal
	"   link:/page[My Page]              - internal absolute path
	"   link:../page[My Page]            - internal relative path
    let l:linkpath = VVGetLink()
	if strlen(l:linkpath) > 0
		if l:linkpath =~ '^https\?://'
			call VVGoUrl(l:linkpath)
		else
			call VVGoPath(l:linkpath)
		endif
		return
	end

	" Did not match a link macro. Now there are three possibilities:
	"   1. We are on whitespace
	"   2. We are on a bare URL (http://...)
	"   3. We are on an unlinked word
	let l:whole_word = expand("[0-9a-zA-Z-_]\+") " selects all non-whitespace chars
	let l:word = expand("<cword>") " selects only 'word' chars

	if l:whole_word == ''
		return
	endif

	if l:whole_word =~ '^https\?://'
		call VVGoUrl(l:whole_word)
		return
	endif

	" Not a link yet - make it a link!
	execute "normal! ciw<<".l:word.".adoc#,".l:word.">>\<ESC>"
endfunction


function! VVGetLink()
	" Captures the <path> portion of 'link:<path>[description]'
    let l:linkrx = '<<\([^#]\+\).adoc#,[^>]\+>>'
    " Grab cursor pos and current line contents
    let l:cursor = col('.')
    let l:linestr = getline('.')

    " Loop through the wiki link matches on the line, see if our cursor
    " is inside one of them.  If so, return it.
    let l:linkstart=0
    let l:linkend=0
    while 1
        " Note: match() always functions as if pattern were in 'magic' mode!
        let l:linkstart =   match(l:linestr, l:linkrx, l:linkend)
		let l:matched = matchlist(l:linestr, l:linkrx, l:linkend)
        let l:linkend =  matchend(l:linestr, l:linkrx, l:linkend)

        " No link found or we're already past the cursor; done looking
        if l:linkstart == -1 || l:linkstart > l:cursor
            return ""
        endif

        if l:linkstart <= l:cursor && l:cursor <= l:linkend
			return l:matched[1]
        endif
    endwhile
endfunction


function! VVGoPath(path)
    " Push current page onto history
    call add(s:history, expand("%:p"))

    let l:fname = a:path

    if l:fname =~ '/$'
        " Path points to a directory, append default 'index' page
        let l:fname = l:fname.g:vviki_index
    end

    if l:fname =~ '^/'
        " Path absolute from wiki root
        let l:fname = g:vviki_root."/".l:fname.g:vviki_ext
    else
        " Path relative to current page
        let l:fname = expand("%:p:h")."/".l:fname.g:vviki_ext
    endif

    execute "edit ".l:fname
endfunction


function! VVGoUrl(url)
	call system('xdg-open '.shellescape(a:url).' &')
endfunction


function! VVBack()
	if len(s:history) < 1
		return
	endif

	let l:last = remove(s:history, -1)
	execute "edit ".l:last
endfunction


function! VVSetup()
	" Set wiki pages to automatically save
	set autowriteall

	" Map ENTER key to create/follow links
	nnoremap <buffer><silent> <CR> :call VVEnter()<CR>

	" Map BACKSPACE key to go back in history
	nnoremap <buffer><silent> <BS> :call VVBack()<CR>

    " Map TAB key to find next link in page
    " NOTE: search() always uses 'magic' regexp mode.
    "       \{-1,} is Vim for match at least 1, non-greedy
    nnoremap <buffer><silent> <TAB> :call search('<<.\{-1,}]')<CR>

    if g:vviki_conceal_links
        " Conceal the AsciiDoc link syntax until the cursor enters
        " the same line.
        set conceallevel=2
        syntax region vvikiLink start=/<</ end=/\]/ keepend
        syntax match vvikiLinkGuts /<<[^>]\+#,/ containedin=vvikiLink contained conceal
        syntax match vvikiLinkGuts />>/ containedin=vvikiLink contained conceal
        highlight link vvikiLink Macro
        highlight link vvikiLinkGuts Comment
    endif
endfunction


" Detect wiki page
" If a buffer has the right parent directory and extension,
" map VViki keyboard shortcuts, etc.
augroup vviki
	au!
	execute "au BufNewFile,BufRead ".g:vviki_root."/*".g:vviki_ext." call VVSetup()"
augroup END
