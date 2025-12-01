#!/usr/bin/env bash

script_dir="$(dirname "$0")"
target="$1"
output_dir="$2"

option_no_update="${no_update:+1}"

source "${script_dir}"/bootstrap.sh
require 'styles'
require 'resolver'

if [[ -z "$target" ]] || [[ -z "$output_dir" ]]; then
    echo "Usage: $(basename "$0") :<configuration>|<package-name> <output-directory>"
    exit 1
fi

set -e

[[ -d "${output_dir}" ]] || mkdir -p "${output_dir}"

files_updated=0

install_package() {
    local user_name="$(resolve_user_name "$1")"
    local package_name="$(resolve_package_name "$1")"
    local package_dir="${root_dir:-.}/package/${user_name}/${package_name}"

    local package="$(resolve_package "$1")"
    local branch="$(resolve_branch "$1")"
    local branch_label="${branch:+@${branch}}"

    local recipe="$(resolve_recipe "$1")"
    local recipe_options=($(resolve_recipe_options "$1"))

    fetch_or_update_package

    if [[ -n "${recipe}" ]]; then
        require 'recipe'
        install_recipe "${package_dir}/${recipe}.recipe.yaml"
    elif [[ -f "${package_dir}/recipe.yaml" ]]; then
        require 'recipe'
        install_recipe "${package_dir}/recipe.yaml"
    else
        install_files_from_package "${package_dir}"
    fi
}

fetch_or_update_package() {
    if ! [[ -d "${package_dir}" ]]; then
        echo $(info 'Downloading package:') $(highlight "${package}") $(print_option "${branch_label}")
        local fetch_options=()
        if [[ -n "${branch}" ]]; then
            fetch_options+=(--branch "${branch}")
        fi
        "${script_dir}"/fetch-package.sh "${package}" "${package_dir}" "${fetch_options[@]}"
    else
        if [[ -z "${option_no_update}" ]]; then
            echo $(info 'Updating package:') $(highlight "${package}")
        else
            echo $(info 'Found package:') $(highlight "${package}")
        fi
        "${script_dir}"/update-package.sh "${package_dir}" "${branch}"
    fi
}

install_files_from_package() {
    local package_dir="$1"
    local IFS=$'\r\n'
    local data_files=(
        $(
            cd "${package_dir}"
            ls *.yaml 2> /dev/null \
                | grep -v -e '\.custom\.yaml$' -e '\.recipe\.yaml$' -e '^recipe\.yaml$'
            ls *.txt 2> /dev/null
            ls *.gram 2> /dev/null
            ls opencc/*.* 2> /dev/null \
                | grep -e '\.json$' -e '\.ocd$' -e '\.txt$'
        )
    )
    install_files "${data_files[@]}"
}

install_files() {
    if [[ "$#" -eq 0 ]]; then
        return
    fi
    local source_path
    local target_path
    for file in "$@"; do
        source_path="${package_dir}/${file}"
        target_path="${output_dir}/${file}"
        if ! [ -e "${target_path}" ]; then
            create_containing_directory "${target_path}"
            echo $(info 'Installing:') $(print_item "${file}")
        elif ! diff -q "${source_path}" "${target_path}" &> /dev/null; then
            echo $(info 'Updating:') $(print_item "${file}")
        else
            continue
        fi
        cp "${source_path}" "${target_path}"
        ((++files_updated))
    done
}

create_containing_directory() {
    local target_dir="$(dirname "$1")"
    if ! [ -d "${target_dir}" ]; then
        echo $(info 'Creating directory:') $(print_item "${target_dir}")
        mkdir -p "${target_dir}"
    fi
}

load_package_list_from_target "${target}"

for package in "${package_list[@]}"; do
    install_package "${package}"
done

if [[ "${files_updated}" -eq 0 ]]; then
    echo $(print_result 'No files updated.')
else
    echo $(print_result "Updated ~ ${files_updated} files " \
                        "from ${#package_list[@]} packages in") "'${output_dir}'"
fi
