" GENERAL HELPER

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
                call VTC#AttachRunnerPane()
        endif
endfunction

" cd's runner pane into vims cwd
function! s:ChangeRootDir()
        call s:EnsurePane(1)
        call s:SendTmuxKeys(getcwd())
endfunction

" TMUX HELPER

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

" RUNNER PANE

" attach a runner pane
"       a) create a new one if vim pane is only one in current window
"       b) flash pane indices to choose from and set corresponding id
function! VTC#AttachRunnerPane()
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
        call VTC#ClearRunnerPane()
endfunction

" detaches from the runner pane
function! VTC#DetachRunnerPane()
        if exists('t:runner_pane_id')
                unlet t:runner_pane_id
        endif
endfunction

" kills the runner pane
function! VTC#KillRunnerPane()
        call s:EnsurePane(0)
        if exists('t:runner_pane_id')
                call s:ExecTmuxCommand('kill-pane -t %'.t:runner_pane_id)
                unlet t:runner_pane_id
        endif
endfunction

" clears the runner pane
function! VTC#ClearRunnerPane()
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' ""')
endfunction

" scroll inside the runner pane
function! VTC#ScrollRunnerPane()
        call s:EnsurePane(1)
        call s:ExecTmuxCommand('copy-mode -t %'.t:runner_pane_id)
        while 1
                " cannot use s:SendTmuxKeys because Enter shall not be printed
                call s:ExecTmuxCommand('send-keys -t %'.t:runner_pane_id.' '.nr2char(getchar()))
        endwhile
endfunction

" moves focus to the runner pane
function! VTC#FocusRunnerPane()
        call s:EnsurePane(1)
        call s:ExecTmuxCommand('select-pane -t %'.t:runner_pane_id)
endfunction

" zooms into the runner pane
function! VTC#ZoomRunnerPane()
        call s:TmuxZoomWrapper(t:runner_pane_id)
        call s:SendTmuxKeys('echo -e "\033[0;93;1mZoom out using: \033[0;91;1m'.s:tmux_prefix.' + '.s:tmux_zoom_key.'\033[0m\nOr with tmux resize-pane -Z"')
endfunction

" COMMAND

" sets the command sent to tmux by default
function! VTC#SetTmuxCommand(...)
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
function! VTC#QuitTmuxCommand()
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
function! VTC#TriggerTmuxCommand()
        if g:vtc_initial_command !=# '' && !exists('t:init_cmd_read')
                call VTC#SetTmuxCommand(g:vtc_initial_command)
                let t:init_cmd_read = 1
        endif
        if !exists('t:tmux_command')
                call VTC#SetTmuxCommand()
        endif
        if !exists('t:tmux_command')
                echoerr 'No tmux command specified!'
                return
        endif
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        call s:SendTmuxKeys(t:tmux_command)
endfunction

" LINES AND FILES

" sends lines to runner pane for execution
function! VTC#SendLines() range
        call s:EnsurePane(1)
        call s:ExitCopyMode()
        for line in getline(a:firstline, a:lastline)
                call s:SendTmuxKeys(line)
        endfor
endfunction

" send entire file to runner pane for execution
function! VTC#SendFile()
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
        call VTC#QuitTmuxCommand()
        call s:SendTmuxKeys(l:runner.' '.expand('%:t'))
endfunction

