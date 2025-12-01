#!/usr/bin/env bash

require 'styles'

guess_rime_user_dir() {
    if [[ -n "${rime_dir}" ]]; then
        return
    fi
    if [[ -z "${rime_frontend}" ]]; then
        # guess frontend by OS
        case "$OSTYPE" in
            linux*)
                export rime_frontend='fcitx5/fcitx5-rime'
                ;;
            darwin*)
                export rime_frontend='rime/squirrel'
                ;;
            cygwin* | msys* | win*)
                # Weasel
                export rime_frontend='rime/weasel'
                ;;
            *)
                echo $(warning 'WARNING:') 'Unknown OSTYPE:' $(print_option "$OSTYPE")
                ;;
        esac
    fi
    # install to default rime user directory
    case "${rime_frontend}" in
        fcitx/fcitx-rime | fcitx-rime)
            export rime_dir="$HOME/.config/fcitx/rime"
            ;;
        fcitx5/fcitx5-rime | fcitx5-rime)
            export rime_dir="$HOME/.local/share/fcitx5/rime"
            ;;
        rime/ibus-rime | ibus-rime)
            export rime_dir="$HOME/.config/ibus/rime"
            ;;
        rime/squirrel | squirrel)
            export rime_dir="$HOME/Library/Rime"
            ;;
        rime/weasel | weasel)
            export rime_dir="$APPDATA\\Rime"
            ;;
        *)
            echo $(warning 'WARNING:') 'Unknown Rime frontend:' $(print_option "${rime_frontend:-(unknown)}")
            return
            ;;
    esac
    echo 'Installing for Rime frontend:' $(print_option "${rime_frontend:-(unknown)}")
}

provide 'frontend'
