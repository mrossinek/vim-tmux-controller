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

" attach a runner pane
"       a) create a new one if vim pane is only one in current window
"       b) flash pane indices to choose from and set corresponding id
function! s:AttachRunnerPane()
        if exists('s:runner_pane_id')
                echoerr 'Cannot attach multiple runner panes!'
                return
        endif
        if len(split(s:ExecTmuxCommand('list-panes'), '\n')) == 1
                " only vim pane exists so far
                let s:runner_pane_id = str2nr(split(s:ExecTmuxCommand('split-window -P -F "#D" -v -l 10'), '%')[0])
                call s:ExecTmuxCommand('last-pane')
        else
                call s:ExecTmuxCommand('display-panes -d 0 "select-pane -t %% \; last-pane"')
                let s:runner_pane_id = str2nr(split(s:ExecTmuxCommand('display-message -p -t ! "#D"'), '%')[0])
        endif
        echo s:runner_pane_id
endfunction

" detaches from the runner pane
" stores the last runner pane id for possible later use
function! s:DetachRunnerPane()
        if !exists('s:runner_pane_id')
                echo 'No runner pane to detach from.'
                return
        endif
        let s:prev_runner_pane_id = s:runner_pane_id
        unlet s:runner_pane_id
endfunction

" kills the runner pane
function! s:KillRunnerPane()
        if !exists('s:runner_pane_id')
                echo 'No runner pane to kill.'
                return
        endif
        call s:ExecTmuxCommand('kill-pane -t %'.s:runner_pane_id)
        unlet s:runner_pane_id
endfunction

" moves focus to the runner pane
function! s:FocusRunnerPane()
        if !exists('s:runner_pane_id')
                echoerr 'No runner pane specified yet!'
                return
        endif
        call s:ExecTmuxCommand('select-pane -t %'.s:runner_pane_id)
endfunction

" moves focus to the vim pane
function! s:FocusVimPane()
        call s:ExecTmuxCommand('select-pane -t '.s:vim_pane_id)
endfunction

" sets the command sent to tmux by default
function! s:SetTmuxCommand(...)
        if exists('s:tmux_command')
                let choice = confirm('Overwrite the tmux command = '.s:tmux_command.' ?', "&Yes\n&No\n&Cancel", 1, 'Warning')
                if choice == 0
                        echoerr 'Tmux command could not be overwritten!'
                        return
                elseif choice == 1
                        unlet s:tmux_command
                else
                        return
                endif
        endif
        if a:0 == 1
                let s:tmux_command = a:1
        else
                let s:tmux_command = input('Command: ')
        endif
endfunction

" flushes the tmux command
function! s:FlushTmuxCommand()
        unlet s:tmux_command
endfunction

" sends the specified command to tmux
function! s:TriggerTmuxCommand()
        if !exists('s:tmux_command')
                call s:SetTmuxCommand()
        endif
        if !exists('s:tmux_command')
                echoerr 'No tmux command specified!'
                return
        endif
        call s:ExecTmuxCommand('send-keys -t %'.s:runner_pane_id.' '.s:tmux_command.' Enter')
endfunction

" initializes some variables
function! s:Initialize()
        let s:vim_pane_id = s:GetPaneId()
        " use the currently active pane on vim startup
endfunction

" make some function available via commands
function! s:DefineCommands()
        command! VtcAttachRunner call s:AttachRunnerPane()
        command! VtcDetachRunner call s:DetachRunnerPane()
        command! VtcFocusRunner call s:FocusRunnerPane()
        command! VtcKillRunner call s:KillRunnerPane()
        command! VtcFlushCommand call s:FlushTmuxCommand()
        command! VtcSetCommand call s:SetTmuxCommand()
        command! VtcExecuteCommand call s:TriggerTmuxCommand()
endfunction

" define standard keymaps for some commands
function! s:DefineKeymaps()
endfunction

call s:Initialize()
call s:DefineCommands()
call s:DefineKeymaps()
