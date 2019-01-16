" do not load multiple times
if exists('g:vtc_loaded')
        finish
endif

" GENERAL HELPER {{{

" ensures a runner pane exists
" if force is set to false, no pane is attached in case none existed yet
function! s:EnsurePane(force)
        let l:pane_exists = 0
        if exists('t:runner_pane_id')
                " if pane id is set, ensure its still in tmux
                let l:panes = s:ExecTmuxCommand('list-panes -a -F "#{pane_id}"')
                let l:found = 0
                for pane in split(l:panes, '\n')
                        if pane =~# '%'.t:runner_pane_id
                                let l:found = 1
                        endif
                endfor
                if l:found
                        let l:pane_exists = 1
                endif
        endif
        if !l:pane_exists && a:force
                unlet t:runner_pane_id
                call s:AttachRunnerPane()
        endif
endfunction

" cd's runner pane into vims cwd
function! s:ChangeRootDir()
        call s:EnsurePane(1)
        call s:SendTmuxKeys(getcwd())
endfunction

" }}}

" TMUX HELPER {{{

" returns the unique tmux pane id of either
"       a) the corresponding pane index given to the function
"       b) the currently active pane
function! s:GetPaneId(...)
        if a:0
                let format = '#P #D'
                let match = a:1
        else
                let format = '#{pane_active} #D'
                let match = '1'
                " the active pane is designated by a 1 in list-panes
        endif
        let panes = s:ExecTmuxCommand('list-panes -F "'.format.'"')
        for pane in split(panes, '\n')
                if pane =~# '^'.match
                        return str2nr(split(pane, '%')[1])
                endif
        endfor
endfunction

" executes a given command in the tmux shell
function! s:ExecTmuxCommand(cmd)
        return system('tmux '.a:cmd)
endfunction

" sends keys to tmux shell
function! s:SendTmuxKeys(keys)
        let l:keys = substitute(a:keys, '"', '\\"', 'g')
        return s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' "'.l:keys.'" Enter')
endfunction

" zooms given pane
function! s:TmuxZoomWrapper(pane_id)
        call s:EnsurePane(1)
        call s:ExecTmuxCommand('resize-pane -Z -t %'.a:pane_id)
        if !exists('s:tmux_prefix')
                let s:tmux_prefix = system("tmux list-keys | grep send-prefix | awk '{print $4}'")
                let s:tmux_prefix = substitute(s:tmux_prefix, '\n', '', '')
        endif
        if !exists('s:tmux_zoom_key')
                let s:tmux_zoom_key = system("tmux list-keys | grep 'resize-pane -Z' | awk '{print $4}'")
                let s:tmux_zoom_key = substitute(s:tmux_zoom_key, '\n', '', '')
        endif
endfunction

" exits copy-mode if runner pane is in it
function! s:ExitCopyMode()
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' -X cancel')
endfunction

" }}}

" RUNNER PANE {{{

" attach a runner pane
"       a) create a new one if vim pane is only one in current window
"       b) flash pane indices to choose from and set corresponding id
function! s:AttachRunnerPane()
        if exists('t:runner_pane_id')
                echoerr 'Cannot attach multiple runner panes!'
                return
        endif
        if g:vtc_percentage
                let t:converted_pane_height = system('tmux display -p "#{window_height}"') / g:vtc_pane_height
                let t:converted_pane_width = system('tmux display -p "#{window_width}"') / g:vtc_pane_width
        else
                let t:converted_pane_height = g:vtc_pane_height
                let t:converted_pane_width = g:vtc_pane_width
        endif
        if len(split(s:ExecTmuxCommand('list-panes'), '\n')) == 1
                " only vim pane exists so far
                if g:vtc_orientation == 1
                        let t:runner_pane_id = str2nr(split(s:ExecTmuxCommand('split-window -P -F "#D" -v -l '.t:converted_pane_height), '%')[0])
                else
                        let t:runner_pane_id = str2nr(split(s:ExecTmuxCommand('split-window -P -F "#D" -h -l '.t:converted_pane_width), '%')[0])
                endif
                call s:ExecTmuxCommand('last-pane')
                let t:current_orientation = g:vtc_orientation
        else
                call s:ExecTmuxCommand('display-panes -d 0 "select-pane -t %%" \; "last-pane"')
                let t:runner_pane_id = str2nr(split(s:ExecTmuxCommand('display-message -p -t ! "#D"'), '%')[0])
                " assume attaching is done mostly to attain other orientation
                let t:current_orientation = 1 - g:vtc_orientation
        endif
        call s:ExitCopyMode()
        call s:ChangeRootDir()
        call s:ClearRunnerPane()
endfunction

" detaches from the runner pane
function! s:DetachRunnerPane()
        if exists('t:runner_pane_id')
                unlet t:runner_pane_id
        endif
endfunction

" kills the runner pane
function! s:KillRunnerPane()
        call s:EnsurePane(0)
        if exists('t:runner_pane_id')
                call s:ExecTmuxCommand('kill-pane -t %'.t:runner_pane_id)
                unlet t:runner_pane_id
        endif
endfunction

" clears the runner pane
function! s:ClearRunnerPane()
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        call s:SendTmuxKeys('clear')
endfunction

" scroll inside the runner pane
function! s:ScrollRunnerPane()
        call s:EnsurePane(1)
        call s:ExecTmuxCommand('copy-mode -t %'.t:runner_pane_id)
        while 1
                " cannot use s:SendTmuxKeys because Enter shall not be printed
                call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' '.nr2char(getchar()))
        endwhile
endfunction

" moves focus to the runner pane
function! s:FocusRunnerPane()
        call s:EnsurePane(1)
        call s:ExecTmuxCommand('select-pane -t %'.t:runner_pane_id)
endfunction

" zooms into the runner pane
function! s:ZoomRunnerPane()
        call s:TmuxZoomWrapper(t:runner_pane_id)
        call s:SendTmuxKeys('echo -e "\033[0;93;1mZoom out using: \033[0;91;1m'.s:tmux_prefix.' + '.s:tmux_zoom_key.'\033[0m\nOr with tmux resize-pane -Z"')
endfunction

" hides the runner pane (the same as zooming into the vim pane)
function! s:HideRunnerPane()
        call s:TmuxZoomWrapper(s:vim_pane_id)
        echohl WarningMsg | echon 'Zoom out using: ' | echohl ErrorMsg | echon s:tmux_prefix.' + '.s:tmux_zoom_key | echohl None | echon "\t[Or with :!tmux resize-pane -Z]"
endfunction

" rotates the runner and vim pane
function! s:RotateRunnerPane()
        let l:old_layout = s:ExecTmuxCommand('display-message -p "#{window_layout}"')
        if t:current_orientation == 1
                call s:ExecTmuxCommand('move-pane -d -h -t %'.s:vim_pane_id.' -s %'.t:runner_pane_id)
                call s:ExecTmuxCommand('resize-pane -t %'.t:runner_pane_id.' -x '.t:converted_pane_width)
                let t:current_orientation = 0
        else
                call s:ExecTmuxCommand('move-pane -d -v -t %'.s:vim_pane_id.' -s %'.t:runner_pane_id)
                call s:ExecTmuxCommand('resize-pane -t %'.t:runner_pane_id.' -y '.t:converted_pane_height)
                let t:current_orientation = 1
        endif
        let l:new_layout = s:ExecTmuxCommand('display-message -p "#{window_layout}"')
        " ensures correct flipping in case of wrong initial orientation
        if l:new_layout =~# l:old_layout
                call s:RotateRunnerPane()
        endif
endfunction

" }}}

" COMMAND {{{

" sets the command sent to tmux by default
function! s:SetTmuxCommand(...)
        if exists('t:tmux_command')
                let choice = confirm('Overwrite the tmux command = '.t:tmux_command.' ?', "&Yes\n&No\n&Cancel", 1, 'Warning')
                if choice == 0
                        echoerr 'Tmux command could not be overwritten!'
                        return
                elseif choice == 1
                        unlet t:tmux_command
                else
                        return
                endif
        endif
        if a:0
                let t:tmux_command = a:1
        else
                let t:tmux_command = input('Command: ')
        endif
endfunction

" quits the running tmux command
function! s:QuitTmuxCommand()
        call s:EnsurePane(1)
        let l:pane_pid = s:ExecTmuxCommand('display-message -p -t %'.t:runner_pane_id.' "#{pane_pid}"')
        let l:processes = split(system('pstree -p -n -T '.l:pane_pid), '---')
        if len(l:processes) > 1
                let l:kill_pid = substitute(l:processes[1], '\D', '', 'g')
                execute('!kill -s TERM '.l:kill_pid)
                execute('silent !ps -p '.l:kill_pid.' > /dev/null')
                if system('echo $?') != 0
                        execute('!kill -s KILL '.l:kill_pid)
                endif
        endif
endfunction

" sends the specified command to tmux
function! s:TriggerTmuxCommand()
        if g:vtc_initial_command !=# '' && !exists('t:init_cmd_read')
                call s:SetTmuxCommand(g:vtc_initial_command)
                let t:init_cmd_read = 1
        endif
        if !exists('t:tmux_command')
                call s:SetTmuxCommand()
        endif
        if !exists('t:tmux_command')
                echoerr 'No tmux command specified!'
                return
        endif
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        call s:SendTmuxKeys(t:tmux_command)
endfunction

" }}}

" LINES AND FILES {{{

" sends lines to runner pane for execution
function! s:SendLines() range
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        for line in getline(a:firstline, a:lastline)
                call s:SendTmuxKeys(line)
        endfor
endfunction

" send entire file to runner pane for execution
function! s:SendFile()
        let l:enabled = substitute(split(execute(':filetype'))[1], 'detection:', '', '')
        if l:enabled !=# 'ON'
                echoerr 'This functionality requires the filetype option to be enabled!'
                return
        endif
        if &filetype ==? ''
                execute(':filetype detect')
                if &filetype ==? ''
                        echoerr 'This functionality requires a valid filetype to be set!'
                        return
                endif
        endif
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        let l:runner = get(g:vtc_runners, &filetype, '')
        if l:runner ==? ''
                echohl WarningMsg | echo "\rNo runner specified for this filetype!"
                return
        endif
        call s:QuitTmuxCommand()
        call s:SendTmuxKeys(l:runner.' '.expand('%:t'))
endfunction

" }}}

" INITIALIZATION {{{

" initializes some variables
function! s:Initialize()
        " global variables
        let g:vtc_initial_command = ''
        let g:vtc_orientation = 1
        let g:vtc_percentage = 0
        let g:vtc_pane_height = 10
        let g:vtc_pane_width = 85

        " filetype dictionary for whole file interpretation
        let g:vtc_runners = {
                \ 'python':     'python',
                \ 'ruby':       'ruby',
                \ 'sh':         'sh',
                \ }

        " local variables
        " use the currently active pane on vim startup
        let s:vim_pane_id = s:GetPaneId()
endfunction

" make some function available via commands
function! s:DefineCommands()
        command! VtcAttachRunner call s:AttachRunnerPane()
        command! VtcDetachRunner call s:DetachRunnerPane()
        command! VtcFocusRunner call s:FocusRunnerPane()
        command! VtcZoomRunner call s:ZoomRunnerPane()
        command! VtcHideRunner call s:HideRunnerPane()
        command! VtcKillRunner call s:KillRunnerPane()
        command! VtcClearRunner call s:ClearRunnerPane()
        command! VtcScrollRunner call s:ScrollRunnerPane()
        command! VtcRotateRunner call s:RotateRunnerPane()
        command! VtcQuitCommand call s:QuitTmuxCommand()
        command! VtcSetCommand call s:SetTmuxCommand()
        command! VtcTriggerCommand call s:TriggerTmuxCommand()
        command! -range VtcSendLines <line1>,<line2>call s:SendLines()
        command! VtcSendFile call s:SendFile()
endfunction

" define standard keymaps for some commands
function! s:DefineKeymaps()
        " tmux Attach
        nnoremap <leader>ta :VtcAttachRunner<cr>
        " tmux Detach
        nnoremap <leader>td :VtcDetachRunner<cr>
        " tmux fOcus
        nnoremap <leader>to :VtcFocusRunner<cr>
        " tmux Zoom
        nnoremap <leader>tz :VtcZoomRunner<cr>
        " tmux Hide
        nnoremap <leader>th :VtcHideRunner<cr>
        " tmux Kill
        nnoremap <leader>tk :VtcKillRunner<cr>
        " tmux Clear
        nnoremap <leader>tc :VtcClearRunner<cr>
        " tmux Scroll
        nnoremap <leader>ts :VtcScrollRunner<cr>
        " tmux Rotate
        nnoremap <leader>tr :VtcRotateRunner<cr>
        " tmux Quit
        nnoremap <leader>tq :VtcQuitCommand<cr>
        " tmux coMmand
        nnoremap <leader>tm :VtcSetCommand<cr>
        " tmux Trigger
        nnoremap <leader>tt :VtcTriggerCommand<cr>
        " tmux Lines
        nnoremap <leader>tl :VtcSendLines<cr>
        vnoremap <leader>tl :VtcSendLines<cr>
        " tmux File
        nnoremap <leader>tf :VtcSendFile<cr>
endfunction

" }}}

call s:Initialize()
call s:DefineCommands()
call s:DefineKeymaps()
