#!/usr/bin/env bash
#
# Fetch a Rime data package from GitHub
#

package_name="$1"
shift

if [[ -z "${package_name}" ]]; then
    echo "Usage: $(basename "$0") <package-name> [<directory>] [-b <branch>]"
    exit 1
fi

resolve_package_name() {
    local name="$1"
    if [[ ${name} =~ [^/]*/[^/]* ]]; then
        echo ${name}
    elif [[ ${name} =~ rime-[^/]* ]]; then
        echo rime/${name}
    else
        echo rime/rime-${name}
    fi
}

package_url="https://github.com/$(resolve_package_name "${package_name}").git"

git_version_greater_or_equal() {
    local target_major="$1"
    local target_minor="$2"
    local git_version_pattern='^git version ([0-9]*)\.([0-9]*).*$'
    if [[ "$(git --version | grep '^git version')" =~ $git_version_pattern ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        [[ "${major}" -gt "${target_major}" ]] || (
            [[ "${major}" -eq "${target_major}" ]] && [[ "${minor}" -ge "${target_minor}" ]]
        )
    else
        return 1
    fi
}

clone_options=(
    --depth 1
    --recurse-submodules
)

if git_version_greater_or_equal 2 9; then
    clone_options+=(
        --shallow-submodules
    )
fi

git clone ${clone_options[@]} "${package_url}" "$@"
