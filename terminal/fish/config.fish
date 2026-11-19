# PATH first: oh-my-posh installs into ~/.local/bin on a fresh machine
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.nargo/bin
fish_add_path $HOME/.bb
fish_add_path $HOME/.opencode/bin

oh-my-posh init fish --config $HOME/.config/fish/multiverse-neon.omp.json | source

if status is-interactive
    # Commands to run in interactive sessions can go here
end
