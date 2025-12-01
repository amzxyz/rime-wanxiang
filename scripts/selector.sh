#!/usr/bin/env bash

require 'styles'
require 'resolver'

select_packages() {
    local all_packages=()
    local target
    local package
    for target in "$@"; do
        load_package_list_from_target "${target}"
        for package in "${package_list[@]}"; do
            if ! (echo " ${all_packages[*]} " | grep -qF " ${package} "); then
                all_packages+=("${package}")
            fi
        done
    done

    selected_packages=()
    local PS3="$(prompt '#') Enter number, package name or '.' when finished $(prompt '#') "
    echo $(highlight 'Select packages to install:')
    select selected in "${all_packages[@]}"; do
        if [[ -n "${selected}" ]]; then
            selected_packages+=("${selected}")
        else
            case "$REPLY" in
                end | ok | 0 | .)
                    break
                    ;;
                cancel | exit | quit)
                    echo $(warning 'Installation canceled.')
                    exit
                    ;;
                reset | clear)
                    selected_packages=()
                    echo $(print_result 'Reset selected packages.')
                    continue
                    ;;
                [:A-Za-z]*)
                    selected_packages+=("$REPLY")
                    ;;
                *)
                    echo $(error 'ERROR:') 'invalid number or package name:' $(print_option "$REPLY")
                    continue
                    ;;
            esac
        fi
        echo "You will rime with $(print_item ${selected_packages[@]}) (+$(print_option $REPLY))"
    done

    if [[ ${#selected_packages} -eq 0 ]]; then
        echo $(warning 'You did not select any packages.')
        echo
        echo -n "$(highlight 'Do you want to install default packages?') ($(print_item $@))"
        read -p " $(prompt '[Y/n]') " answer
        case "${answer}" in
            '' | y*)
                selected_packages=("$@")
                ;;
            *)
                echo $(warning 'Installation canceled.')
                exit
                ;;
        esac
    fi
}

provide 'selector'
