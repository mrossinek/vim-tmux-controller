" do not load multiple times
if exists('g:vtc_loaded')
        finish
endif

" executes a given command in the tmux shell
function! s:ExecTmuxCommand(cmd)
        return system('tmux '.a:cmd)
endfunction

" returns the unique tmux pane id of either
"       a) the corresponding pane index given to the function
"       b) the currently active pane
function! s:GetPaneId(...)
        if a:0 == 0
                let format = '#{pane_active} #D'
                let match = '1'
                " the active pane is designated by a 1 in list-panes
        else
               let format = '#P #D'
               let match = a:1
        endif
        let panes = s:ExecTmuxCommand('list-panes -F "'.format.'"')
        for pane in split(panes, '\n')
                if pane =~# '^'.match
                        return str2nr(split(pane, '%')[1])
                endif
        endfor
endfunction

function! s:ChangeRootDir()
        if !exists('t:runner_pane_id')
                echoerr 'No runner pane to specified yet!'
                return
        endif
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' "cd '.getcwd().'" Enter')
endfunction

" attach a runner pane
"       a) create a new one if vim pane is only one in current window
"       b) flash pane indices to choose from and set corresponding id
function! s:AttachRunnerPane()
        if exists('t:runner_pane_id')
                echoerr 'Cannot attach multiple runner panes!'
                return
        endif
        if len(split(s:ExecTmuxCommand('list-panes'), '\n')) == 1
                " only vim pane exists so far
                if g:vtc_percentage
                        if g:vtc_orientiation =~# 'v'
                                let t:converted_pane_size = system('tmux display -p "#{window_height}"') / g:vtc_pane_size
                        else
                                let t:converted_pane_size = system('tmux display -p "#{window_width}"') / g:vtc_pane_size
                        endif
                else
                        let t:converted_pane_size = g:vtc_pane_size
                endif
                let t:runner_pane_id = str2nr(split(s:ExecTmuxCommand('split-window -P -F "#D" -'.g:vtc_orientiation.' -l '.t:converted_pane_size), '%')[0])
                call s:ExecTmuxCommand('last-pane')
        else
                call s:ExecTmuxCommand('display-panes -d 0 "select-pane -t %%" \; "last-pane"')
                let t:runner_pane_id = str2nr(split(s:ExecTmuxCommand('display-message -p -t ! "#D"'), '%')[0])
        endif
        call s:ChangeRootDir()
        call s:ClearRunnerPane()
endfunction

" detaches from the runner pane
function! s:DetachRunnerPane()
        if !exists('t:runner_pane_id')
                echo 'No runner pane to detach from.'
                return
        endif
        unlet t:runner_pane_id
endfunction

" kills the runner pane
function! s:KillRunnerPane()
        if !exists('t:runner_pane_id')
                echo 'No runner pane to kill.'
                return
        endif
        call s:ExecTmuxCommand('kill-pane -t %'.t:runner_pane_id)
        unlet t:runner_pane_id
endfunction

" clears the runner pane
function! s:ClearRunnerPane()
        if !exists('t:runner_pane_id')
                echo 'No runner pane to clear.'
                return
        endif
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' clear Enter')
endfunction

" scroll inside the runner pane
function! s:ScrollRunnerPane()
        if !exists('t:runner_pane_id')
                echoerr 'No runner pane to scroll in!'
                return
        endif
        call s:ExecTmuxCommand('copy-mode -t %'.t:runner_pane_id)
        while 1
                call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' '.nr2char(getchar()))
        endwhile
endfunction

" moves focus to the runner pane
function! s:FocusRunnerPane()
        if !exists('t:runner_pane_id')
                echoerr 'No runner pane specified yet!'
                return
        endif
        call s:ExecTmuxCommand('select-pane -t %'.t:runner_pane_id)
endfunction

" zooms into the runner pane
function! s:ZoomRunnerPane()
        if !exists('t:runner_pane_id')
                echoerr 'No runner pane specified yet!'
                return
        endif
        call s:ExecTmuxCommand('resize-pane -Z -t %'.t:runner_pane_id)
        if !exists('s:tmux_prefix')
                let s:tmux_prefix = system("tmux list-keys | grep send-prefix | awk '{print $4}'")
                let s:tmux_prefix = substitute(s:tmux_prefix, '\n', '', '')
        endif
        if !exists('s:tmux_zoom_key')
                let s:tmux_zoom_key = system("tmux list-keys | grep 'resize-pane -Z' | awk '{print $4}'")
                let s:tmux_zoom_key = substitute(s:tmux_zoom_key, '\n', '', '')
        endif
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' "echo -e \"\033[0;93;1mZoom out using: \033[0;91;1m'.s:tmux_prefix.' + '.s:tmux_zoom_key.'\033[0m\nOr with tmux resize-pane -Z\"" Enter')
endfunction

" hides the runner pane (the same as zooming into the vim pane)
function! s:HideRunnerPane()
        call s:ExecTmuxCommand('resize-pane -Z -t %'.t:vim_pane_id)
        if !exists('s:tmux_prefix')
                let s:tmux_prefix = system("tmux list-keys | grep send-prefix | awk '{print $4}'")
                let s:tmux_prefix = substitute(s:tmux_prefix, '\n', '', '')
        endif
        if !exists('s:tmux_zoom_key')
                let s:tmux_zoom_key = system("tmux list-keys | grep 'resize-pane -Z' | awk '{print $4}'")
                let s:tmux_zoom_key = substitute(s:tmux_zoom_key, '\n', '', '')
        endif
        echohl WarningMsg | echon 'Zoom out using: ' | echohl ErrorMsg | echon s:tmux_prefix.' + '.s:tmux_zoom_key | echohl None | echo 'Or with :!tmux resize-pane -Z'
endfunction


" moves focus to the vim pane
function! s:FocusVimPane()
        call s:ExecTmuxCommand('select-pane -t %'.s:vim_pane_id)
endfunction

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
        if a:0 == 1
                let t:tmux_command = a:1
        else
                let t:tmux_command = input('Command: ')
        endif
endfunction

" flushes the tmux command
function! s:FlushTmuxCommand()
        unlet t:tmux_command
endfunction

" kills the running tmux command
function! s:KillTmuxCommand()
        if !exists('t:runner_pane_id')
                echoerr 'No runner pane specified yet!'
                return
        endif
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
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' '.t:tmux_command.' Enter')
endfunction

" initializes some variables
function! s:Initialize()
        " global variables
        let g:vtc_initial_command = ''
        let g:vtc_orientiation = 'v'
        let g:vtc_percentage = 0
        let g:vtc_pane_size = 10

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
        command! VtcFlushCommand call s:FlushTmuxCommand()
        command! VtcKillCommand call s:KillTmuxCommand()
        command! VtcSetCommand call s:SetTmuxCommand()
        command! VtcTriggerCommand call s:TriggerTmuxCommand()
endfunction

" define standard keymaps for some commands
function! s:DefineKeymaps()
        " tmux attach
        nnoremap <leader>ta :VtcAttachRunner<cr>
        " tmux detach
        nnoremap <leader>td :VtcDetachRunner<cr>
        " tmux focus
        nnoremap <leader>tf :VtcFocusRunner<cr>
        " tmux zoom
        nnoremap <leader>tz :VtcZoomRunner<cr>
        " tmux hide
        nnoremap <leader>th :VtcHideRunner<cr>
        " tmux kill
        nnoremap <leader>tk :VtcKillRunner<cr>
        " tmux 'empty' (i.e. clear)
        nnoremap <leader>te :VtcClearRunner<cr>
        " tmux scroll
        nnoremap <leader>ts :VtcScrollRunner<cr>
        " tmux 'down' (i.e. flush)
        nnoremap <leader>tj :VtcFlushCommand<cr>
        " tmux 'cross out' (i.e. kill command)
        nnoremap <leader>tx :VtcKillCommand<cr>
        " tmux command
        nnoremap <leader>tc :VtcSetCommand<cr>
        " tmux trigger
        nnoremap <leader>tt :VtcTriggerCommand<cr>
endfunction

call s:Initialize()
call s:DefineCommands()
call s:DefineKeymaps()
