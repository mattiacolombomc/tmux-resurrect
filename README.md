# Tmux Resurrect

> [!IMPORTANT]
> **This is a fork of [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect).**
> It saves the same things, to the same files, with the same options and key
> bindings, and it restores them with the same code. The difference is in how
> saving is done: it stays fast with hundreds of panes, and a failed save never
> replaces a good one.

## What is different from the original

| | original | this fork |
|---|---|---|
| Processes started by a save | one `ps` per pane, plus several `tmux` calls per pane and per window | one `ps` per save |
| Save duration with 213 panes | 653 s | 5.9 s |
| CPU time of that save | 322 s | 3.5 s |
| Two saves at the same time | allowed, they pile up | the second one exits |
| Save file with no panes, or nearly empty | becomes `last` | kept as `.broken`, `last` is not touched |
| Pane command lookup | by pid prefix | by exact pid |
| Restore | — | unchanged |

Measured on macOS with tmux 3.8, on a live server with 213 panes, 159 windows
and 154 sessions, and about 2300 processes on the machine.

> [!NOTE]
> **Why the original is slow.** Its default save command strategy runs
> `ps -ao ppid,args` once for every pane. Each run scans the whole process
> table. On macOS that takes seconds on a busy machine, so the save time grows
> with the number of panes. With [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
> a save that takes longer than the save interval overlaps with the next one,
> and the `ps` processes pile up
> ([upstream issue #544](https://github.com/tmux-plugins/tmux-resurrect/issues/544)).

The changes, all in `scripts/save.sh` and `save_command_strategies/ps.sh`:

- **One process scan per save.** The process table is read once and shared
  with the `ps` strategy. Pane commands are then resolved in a single pass,
  with no process started per pane.
- **Window options read in batches.** The `automatic-rename` option of all
  windows is read 100 windows per `tmux` call, not one call per window.
- **One save at a time.** A save takes a lock in the resurrect directory. A
  save started while another one is running exits without doing anything. A
  lock left by a dead process is taken over.
- **A broken save does not replace a good one.** A tmux server in trouble can
  answer with errors, and the resulting save file is nearly empty. Such a file
  is renamed to `.broken` and the `last` link stays on the previous save.
- **Exact pid match.** The original matches the pane pid by prefix, so pane
  pid 8075 also picks up the children of pid 80750.

> [!TIP]
> **The save file is the same.** On the same server the fork and the original
> produce the same save file, apart from the lines where the prefix match of
> the original is wrong. Existing save files and settings keep working, and
> you can go back to the original at any time.

> [!WARNING]
> The other save command strategies (`pgrep`, `gdb`, `linux_procfs`) still run
> once per pane, as in the original. The single process scan applies to the
> default `ps` strategy.

To use the fork with [TPM](https://github.com/tmux-plugins/tpm), replace the
plugin line in `.tmux.conf`:

    set -g @plugin 'mattiacolombomc/tmux-resurrect'

If the original is already installed, TPM keeps the existing
`tmux-resurrect` directory. Point it at the fork once:

    cd ~/.tmux/plugins/tmux-resurrect
    git remote set-url origin https://github.com/mattiacolombomc/tmux-resurrect.git
    git fetch origin && git reset --hard origin/master

The rest of this README is the original one.

---

[![Build Status](https://travis-ci.org/tmux-plugins/tmux-resurrect.svg?branch=master)](https://travis-ci.org/tmux-plugins/tmux-resurrect)

Restore `tmux` environment after system restart.

Tmux is great, except when you have to restart the computer. You lose all the
running programs, working directories, pane layouts etc.
There are helpful management tools out there, but they require initial
configuration and continuous updates as your workflow evolves or you start new
projects.

`tmux-resurrect` saves all the little details from your tmux environment so it
can be completely restored after a system restart (or when you feel like it).
No configuration is required. You should feel like you never quit tmux.

It even (optionally)
[restores vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)!

Automatic restoring and continuous saving of tmux env is also possible with
[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) plugin.

### Screencast

[![screencast screenshot](/video/screencast_img.png)](https://vimeo.com/104763018)

### Key bindings

- `prefix + Ctrl-s` - save
- `prefix + Ctrl-r` - restore

### About

This plugin goes to great lengths to save and restore all the details from your
`tmux` environment. Here's what's been taken care of:

- all sessions, windows, panes and their order
- current working directory for each pane
- **exact pane layouts** within windows (even when zoomed)
- active and alternative session
- active and alternative window for each session
- windows with focus
- active pane for each window
- "grouped sessions" (useful feature when using tmux with multiple monitors)
- programs running within a pane! More details in the
  [restoring programs doc](docs/restoring_programs.md).

Optional:

- [restoring vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)
- [restoring pane contents](docs/restoring_pane_contents.md)
- [restoring a previously saved environment](docs/restoring_previously_saved_environment.md)

Requirements / dependencies: `tmux 1.9` or higher, `bash`.

Tested and working on Linux, OSX and Cygwin.

`tmux-resurrect` is idempotent! It will not try to restore panes or windows that
already exist.<br/>
The single exception to this is when tmux is started with only 1 pane in order
to restore previous tmux env. Only in this case will this single pane be
overwritten.

### Installation with [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (recommended)

Add plugin to the list of TPM plugins in `.tmux.conf`:

    set -g @plugin 'tmux-plugins/tmux-resurrect'

Hit `prefix + I` to fetch the plugin and source it. You should now be able to
use the plugin.

### Manual Installation

Clone the repo:

    $ git clone https://github.com/tmux-plugins/tmux-resurrect ~/clone/path

Add this line to the bottom of `.tmux.conf`:

    run-shell ~/clone/path/resurrect.tmux

Reload TMUX environment with: `$ tmux source-file ~/.tmux.conf`.
You should now be able to use the plugin.

### Docs

- [Guide for migrating from tmuxinator](docs/migrating_from_tmuxinator.md)

**Configuration**

- [Changing the default key bindings](docs/custom_key_bindings.md).
- [Setting up hooks on save & restore](docs/hooks.md).
- Only a conservative list of programs is restored by default:<br/>
  `vi vim nvim emacs man less more tail top htop irssi weechat mutt`.<br/>
  [Restoring programs doc](docs/restoring_programs.md) explains how to restore
  additional programs.
- [Change a directory](docs/save_dir.md) where `tmux-resurrect` saves tmux
  environment.

**Optional features**

- [Restoring vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)
  is nice if you're a vim/neovim user.
- [Restoring pane contents](docs/restoring_pane_contents.md) feature.

### Other goodies

- [tmux-copycat](https://github.com/tmux-plugins/tmux-copycat) - a plugin for
  regex searches in tmux and fast match selection
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank) - enables copying
  highlighted text to system clipboard
- [tmux-open](https://github.com/tmux-plugins/tmux-open) - a plugin for quickly
  opening highlighted file or a url
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) - automatic
  restoring and continuous saving of tmux env

### Reporting bugs and contributing

Both contributing and bug reports are welcome. Please check out
[contributing guidelines](CONTRIBUTING.md).

### Credits

[Mislav Marohnić](https://github.com/mislav) - the idea for the plugin came from his
[tmux-session script](https://github.com/mislav/dotfiles/blob/2036b5e03fb430bbcbc340689d63328abaa28876/bin/tmux-session).

### License
[MIT](LICENSE.md)
