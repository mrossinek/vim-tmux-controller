" do not load multiple times
if exists('g:vtc_loaded')
        finish
endif

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
endfunction

" make some function available via commands
function! s:DefineCommands()
        command! VtcAttachRunner call VTC#AttachRunnerPane()
        command! VtcDetachRunner call VTC#DetachRunnerPane()
        command! VtcFocusRunner call VTC#FocusRunnerPane()
        command! VtcZoomRunner call VTC#ZoomRunnerPane()
        command! VtcKillRunner call VTC#KillRunnerPane()
        command! VtcClearRunner call VTC#ClearRunnerPane()
        command! VtcScrollRunner call VTC#ScrollRunnerPane()
        command! VtcQuitCommand call VTC#QuitTmuxCommand()
        command! VtcSetCommand call VTC#SetTmuxCommand()
        command! VtcTriggerCommand call VTC#TriggerTmuxCommand()
        command! -range VtcSendLines <line1>,<line2>call VTC#SendLines()
        command! VtcSendFile call VTC#SendFile()
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
        " tmux Kill
        nnoremap <leader>tk :VtcKillRunner<cr>
        " tmux Clear
        nnoremap <leader>tc :VtcClearRunner<cr>
        " tmux Scroll
        nnoremap <leader>ts :VtcScrollRunner<cr>
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

call <SID>Initialize()
call <SID>DefineCommands()
call <SID>DefineKeymaps()
