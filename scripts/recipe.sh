#!/usr/bin/env bash

require 'styles'

install_recipe() {
    local recipe_file="$1"
    if ! [[ -f "${recipe_file}" ]]; then
        echo $(error 'Recipe not found:') "${recipe_file}"
        exit 1
    fi

    local rx="${package}${recipe:+:${recipe}}"
    echo $(info 'Installing recipe:') $(highlight "${rx}")
    for option in "${recipe_options[@]}"; do
        echo $(info '- option:') $(print_option "${option}")
    done

    check_recipe_info

    apply_download_files

    apply_install_files

    apply_patch_files
}

print_section() {
    local section="$1"
    sed -n '/^'"${section}"':/,/^[^[:space:]#]/ {
        /^[^[:space:]#]/ !p
    }'
}

check_recipe_info() {
    local recipe_decl=$(
        cat "${recipe_file}" |
            print_section 'recipe' |
            grep '^[ ]*Rx: ' |
            sed 's/^[ ]*Rx:[ "'"'"']*\(.*\)[ "'"'"']*$/\1/'
    )
    [[ -z "${recipe}" ]] || [[ "${recipe_decl}" == "${recipe}" ]] || (
        echo $(error 'Invalid recipe:') "'${recipe_decl}' does not match file name '${recipe_file}'"
        exit 1
    )
}

get_filename() {
    local url="$1"
    # if a filename is specified, use it
    if [[ "$url" = *::* ]]; then
        echo "${url%%::*}"
    else
        echo "${url##*/}"
    fi
}

download_file() {
    local url="$1"
    local filename="$(get_filename $url)"
    local check_update=""
    local msg='Downloading file:'

    if [[ -e "${package_dir}/${filename}" ]]; then
        check_update="-z $filename"
        msg='Checking for update of external file:'
    fi
 
    (
        cd "${package_dir}"
        echo $(info "$msg") $(highlight "$filename")
        curl -fRL -o "$filename" $check_update "${url#*::}"
    )
}

apply_download_files() {
    if ! grep -q '^download_files:' "${recipe_file}"; then
        return
    fi
    local file_patterns=(
        $(cat "${recipe_file}" |
            print_section 'download_files' |
            sed '/^[ ]*#/ d; s/^[ ]*-[ ]//'
        )
    )
    if (( ${#file_patterns[@]} == 0 )); then
        return
    fi
    for _item in ${file_patterns[@]}; do
        download_file $_item || (
            echo $(error 'Error:') "failed to download files in recipe ${rx}"
            exit 1
        )
    done
}

apply_install_files() {
    if ! grep -q '^install_files:' "${recipe_file}"; then
        return
    fi
    local file_patterns=(
        $(cat "${recipe_file}" |
            print_section 'install_files' |
            sed '/^[ ]*#/ d; s/^[ ]*-[ ]//'
        )
    )
    if (( ${#file_patterns[@]} == 0 )); then
        return
    fi
    install_files $(
        cd "${package_dir}"
        ls ${file_patterns[@]} ||
            echo $(error 'Error: some files to install are not found.') >&2
    ) || (
        echo $(error 'Error:') "failed to install files in recipe ${rx}"
        exit 1
    )
}

apply_patch_files() {
    if ! grep -q '^patch_files:' "${recipe_file}"; then
        return
    fi
    local script_header="\
#!/usr/bin/env bash
source '${script_dir}/bootstrap.sh'
require 'recipe'
output_dir='${output_dir}'
package='${package}'
recipe='${recipe}'
recipe_options=(
    ${recipe_options[*]}
)
eval \${recipe_options[@]}
"
    cat "${recipe_file}" |
        print_section 'patch_files' |
        sed '{
            1 i\
'"$(escape_sed_text <<<"${script_header}")"'
# patch files
            s/^[ ][ ]//
            s/^\([^[:space:]#]*\):\s*$/patch_file \1 <<EOF/
            2,$ {
                /<<EOF/ i\
EOF
            }
            $ a\
EOF
        }' | bash || (
        echo $(error 'Error:') "failed to patch files in recipe ${rx}"
        exit 1
    )
}

escape_sed_text() {
    sed -e 's/[\\ ]/\\&/g; s/$/\\/'
}

patch_file() {
    local file_name="$1"
    echo $(info 'Patching:') $(print_item "${file_name}")
    local target_file="${output_dir:-.}/${file_name}"
    if ! [[ -e "${target_file}" ]] || ! grep -q '^__patch:$' "${target_file}"; then
        echo '__patch:' >> "${target_file}"
    fi
    local option_list="${recipe_options[*]}"
    local rx="${package}:${recipe}:${option_list// /,}"
    if grep -Fq "# Rx: ${rx}" "${target_file}"; then
        echo $(info 'Updating patch.')
        # first remove the existing patch
        sed '/^# Rx: '"${rx//\//\\/}"' {$/,/^# }$/ d' \
            "${target_file}" > "${target_file}.new" &&
            mv "${target_file}.new" "${target_file}"
    fi
    # read patch contents from standard input
    local patch_contents="$(escape_sed_text)"
    sed -E '
        /^__patch:$/,/^[^[:space:]#]/ {
            $ {
                /^__patch:|^[[:space:]#]/ {
                    a\
# Rx: '"${rx}"' {\
'"${patch_contents}"'
# }
                    q
                }
                i\
# Rx: '"${rx}"' {\
'"${patch_contents}"'
# }
            }
        }
    ' "${target_file}" > "${target_file}.new" &&
    mv "${target_file}.new" "${target_file}" || (
        echo $(error 'Error patching:') "${file_name}"
        exit 1
    )
}

provide 'recipe'
