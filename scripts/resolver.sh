#!/usr/bin/env bash

require 'styles'

# a recipe order takes the form
#     <github-user>/<repository-name>@<branch>:<recipe>:key=value,...
#
# the "<github-user>/" and/or "@<branch>", ":<recipe>..." parts can be omitted

resolve_user_name() {
    local package="${1%%[@:]*}"
    local user_name='rime'
    if [[ "${package}" =~ / ]]; then
        user_name="${package%/*}"
    fi
    echo "${user_name}"
}

resolve_package_name() {
    local package="${1%%[@:]*}"
    local repo_name="${package##*/}"
    local package_name="${repo_name#rime-}"
    echo "${package_name}"
}

resolve_package() {
    local package="${1%%[@:]*}"
    echo "${package}"
}

# returns empty string if not specified
resolve_branch() {
    local package="${1%%:*}"
    if [[ "${package}" =~ @ ]]; then
        echo "${package##*@}"
    fi
}

# returns empty string if not specified
resolve_recipe() {
    local rx="$1"
    if [[ "${rx}" =~ : ]]; then
        rx="${rx#*:}"
        echo "${rx%%:*}"
    fi
}

resolve_recipe_options() {
    local rx="$1"
    if [[ "${rx}" =~ : ]]; then
        rx="${rx#*:}"
        if [[ "${rx}" =~ : ]]; then
            echo "${rx#*:}" | sed 's/[:,]/ /g'
        fi
    fi
}

expand_configuration_url() {
    if [[ "$1" =~ ^https:// ]]; then
        echo "$1"
    elif [[ "$1" =~ ^([^/@:]*)/([^/@:]*)(@[^/@:]*)?/([^@:]*-packages.conf)$ ]]; then
        local user="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local branch="${BASH_REMATCH[3]#@}"
        local filepath="${BASH_REMATCH[4]}"
        echo "https://github.com/${user}/${repo}/raw/${branch:-master}/${filepath}"
    fi
}

load_package_list_from_target() {
    local target="$1"
    case "${target}" in
        */*/*-packages.conf |\
            https://github.com/*/raw/*-packages.conf |\
            https://raw.githubusercontent.com/*-packages.conf)
            local configuration_url="$(expand_configuration_url "${target}")"
            if [[ -z "${configuration_url}" ]]; then
                echo $(error 'ERROR:') "unable to recognize configuration: ${target}" >&2
                exit 1
            fi
            echo $(info 'Fetching') "${configuration_url}"
            curl -fLO "${configuration_url}"
            source "$(basename "${configuration_url}")"
            ;;
        *.conf)
            source "${target}"
            ;;
        :*)
            source "${root_dir:-.}/${target#:}"-packages.conf
            ;;
        *)
            package_list=("${target}")
            ;;
    esac
}

provide 'resolver'
