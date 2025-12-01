#!/usr/bin/env bash
# encoding: utf-8

script_dir="$(dirname "$0")"
output_dir="$1"

for package in essay luna-pinyin prelude; do
  bash "${script_dir}"/install-packages.sh "${package}" "${output_dir}"
done

pushd "${output_dir}" > /dev/null

awk '($2 >= 500) {print}' essay.txt > essay.txt.min
mv essay.txt.min essay.txt

sed -n '{
  s/^version: \(["]*\)\([0-9.]*\)\(["]*\)$/version: \1\2.minimal\3/
  /^#以下爲詞組$/q;p
}' luna_pinyin.dict.yaml > luna_pinyin.dict.yaml.min
mv luna_pinyin.dict.yaml.min luna_pinyin.dict.yaml

for schema in *.schema.yaml; do
  sed '{
    s/version: \(["]*\)\([0-9.]*\)\(["]*\)$/version: \1\2.minimal\3/
    s/\(- stroke\)$/#\1/
    s/\(- reverse_lookup_translator\)$/#\1/
  }' ${schema} > ${schema}.min
  mv ${schema}.min ${schema}
done

ls *.schema.yaml | sed 's/^\(.*\)\.schema\.yaml/  - schema: \1/' > schema_list.yaml
grep -Ff schema_list.yaml default.yaml > schema_list.yaml.min
mv schema_list.yaml.min schema_list.yaml
sed '{
  s/^config_version: \(["]*\)\([0-9.]*\)\(["]*\)$/config_version: \1\2.minimal\3/
  /- schema:/d
  /^schema_list:$/r schema_list.yaml
}' default.yaml > default.yaml.min
rm schema_list.yaml
mv default.yaml.min default.yaml

popd > /dev/null
