#!/usr/bin/env bash

old_branch=master
new_branch=split-packages

package_files() {
  local package="$1"
  grep "^${package}=" <<EOF | sed 's/^.*=//'
array=extra/array30.*
bopomofo=preset/bopomofo*
cangjie=preset/cangjie*
combo-pinyin=supplement/combo_pinyin.*
double-pinyin={preset,supplement}/double_pinyin*
emoji=supplement/emoji.*
essay=essay.* make_essay.*
ipa=supplement/ipa_xsampa.*
jyutping=supplement/jyutping.*
luna-pinyin=preset/luna_pinyin.*
middle-chinese=supplement/{zyenpheng,sampheng}.*
pinyin-simp=supplement/pinyin_simp.*
prelude=default.yaml symbols.yaml
quick=supplement/quick*
scj=extra/scj*
soutzoe={supplement,extra}/soutzoe.*
stenotype={supplement,extra}/stenotype.*
stroke={preset,supplement}/stroke* {supplement,extra}/stroke5.*
terra-pinyin=preset/terra_pinyin.*
wubi={supplement,extra}/wubi*
wugniu=supplement/wugniu*
EOF
}

rewrite_git_history() {
  local package="$1"
  # we are currently on new_branch, now create the old_branch in the cloned repo
  git branch ${old_branch} origin/${old_branch}
  # the short history of the package directory
  git filter-branch --prune-empty --index-filter '
      git read-tree --empty
      git reset -q $GIT_COMMIT -- LICENSE '"$(package_files ${package})"'
  ' -- ${old_branch}
  git update-ref -d refs/original/refs/heads/${old_branch}
  # older history of files that is now in this package
  git filter-branch --prune-empty --subdirectory-filter ${package} -- ${new_branch}
  git update-ref -d refs/original/refs/heads/${new_branch}
  # join the two parts
  local graft_id=$(git rev-parse --short heads/${old_branch})
  git filter-branch --parent-filter 'sed "s/^\$/-p '${graft_id}'/"' -- ${new_branch}
  # clean up
  git reset --hard
  git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
  git reflog expire --expire=now --all
  git gc --aggressive --prune=now
}

push_package() {
  local package="$1"
  # sync master branch
  git fetch . ${new_branch}:master
  # push to GitHub
  git remote rename origin local
  git remote add origin https://github.com/rime/rime-${package}.git
  git push -u origin master
}

excluded_dirs=':packages:scripts:'
target_dir="$PWD/packages"

main() {
  mkdir -p "${target_dir}"
  local package
  for package in *; do
    if [[ -d "${package}" ]] && ! [[ "${excluded_dirs}" =~ ":${package}:" ]]; then
        local package_repo_path="${target_dir}/rime-${package}"
        git clone "$PWD" "${package_repo_path}"
        pushd "${package_repo_path}"
        rewrite_git_history ${package}
        push_package ${package}
        popd
    fi
  done
}

main
