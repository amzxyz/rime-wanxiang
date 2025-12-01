#!/usr/bin/env bash
#
# bootstraps the script module system
#
# usage:
#   - source this file in the main script
#   - require 'module-name'
# in modules:
#   - require module dependencies
#   - define module
#   - provide 'module-name'

module_root_dir="$(dirname "${BASH_SOURCE[0]}")"

provide() {
    local module_name="$1"
    loaded_modules+=("${module_name}")
}

require() {
    local module_name="$1"
    if grep -qF " ${module_name} " <<<" ${loaded_modules[*]} "; then return; fi
    source "${module_root_dir}/${module_name}.sh"
    if grep -qF " ${module_name} " <<<" ${loaded_modules[*]} "; then return; fi
    echo >&2 "ERROR: failed to load module '${module_name}'"
}

provide 'bootstrap'
