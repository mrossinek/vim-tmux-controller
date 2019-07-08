Vim Tmux Controller
===================

A simple set of commands to control tmux from within vim.
This project is heavily inspired by [Chris Toomey's VTR plugin](https://github.com/christoomey/vim-tmux-runner "Vim Tmux Runner").

Usage
-----

The Vim Tmux Controller (VTC) is meant to simplify the interaction of vim with
tmux. It is designed with the idea of controlling a tmux pane alongside vim to
which commands can be sent from vim directly.
This allows to keep a very accessible window for `making` or `testing` your
project while coding along.

Future plans include the ability to send selections from within vim to be
executed directly (e.g. for python scripts to be interpreted on the fly).

Installation
------------

I would recommend using [minpac](https://github.com/k-takata/minpac) which makes extensive use of the package feature
which was added to Vim 8 and Neovim.
```
call minpac#add('https://gitlab.com/mrossinek/vim-tmux-controller')
```
Other package managers work in a similar fashion.

I recommend Chris Toomey's [Vim Tmux Navigator](https://github.com/christoomey/vim-tmux-navigator) to go along with this plugin.

Inspiration
-----------

As already mentioned, this plugin is heavily inspired by Chris Toomey's [VTR](https://github.com/christoomey/vim-tmux-runner).
I really like his plugin, but recently he has not been very actively updating
that repository (his vim-tmux-navigator is more active though!).
I did not simply fork his plugin because of [this issue](https://github.com/christoomey/vim-tmux-runner/issues/66) which requires a lot of
refactoring. Furthermore, I wanted to do a few things differently and, thus,
decided to start from scratch. I recently went back to his plugin to get some
ideas when I got stuck, so I owe Chris many thanks!


