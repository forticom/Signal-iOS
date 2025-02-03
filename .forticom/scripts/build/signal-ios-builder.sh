#!/bin/bash

# bash configuration:
# 1) Exit script if you tru to use an uninitialized variable.
set -o nounset

# 2) Exit script if a statement returns a non-true return value.
set -o errexit

# 3) Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# global import
declare -rx BUILD_CHECK_FILE='.signal_ios_builder_checked'

declare -ax config_files

# args

function main() {
  base_signal_ios_build_container
  local signal_ios_image_dir=".results/signal_ios_image"
  mkdir -p "${signal_ios_image_dir}"
  if signal_ios_build_needed "${signal_ios_image_dir}"; then
    echo "Build because flag is newer than signal ios"
    : # build_signal_ios
  fi
}

function base_signal_ios_build_container() {
  docker build \
    ".forticom/containers/signal-ios-builder" \
    -f ".forticom/containers/signal-ios-builder/Dockerfile.signal-ios-builder" \
    -t "signal_ios_builder:signal_ios"
}

function flag_file_name() {
  printf '%s' ".results/signal_ios_image/${BUILD_CHECK_FILE}"
}

#
# determine if build needed.
# if and only iff
#     1) any source is newer than the flag checkpoint
#     2) any target is older than the flag checkpoint
function signal_ios_build_needed() {
  local -r signal_ios_image_dir="${1}"
  local flag_file
  local signal_ios_image

  flag_file="$(flag_file_name)"
  signal_ios_image='bzImage'
  local -r signal_ios_path="${signal_ios_image_dir}/${signal_ios_image}"
  local -r base_builder='./.forticom/containers/signal-ios-builder'
  if file1_newer_than_file2 "${base_builder}/Dockerfile.signal-ios-builder" "${flag_file}"; then
    echo "Build because Dockerfile is newer"
    touch "${flag_file}"
  fi
  if file_date_compare_dir_contents_newer_than_file2 "${base_builder}/scripts" "${flag_file}"; then
    echo "Build because signal ios scripts are newer"
    touch "${flag_file}"
  fi
  file1_newer_than_file2 "${flag_file}" "${signal_ios_path}"
}

#
# return 0 if file1 exists and is newer than file2
# return 1 if first file does not exist
# return 0 if first file exists and second one does not
# return 1 if first file older than second file
#
function file1_newer_than_file2() {
  local -r file1="${1}"
  local -r file2="${2}"

  if [[ -e ${file1}   ]]; then
     if [[ -e $file2   ]]; then
      if [[ ${file1} -nt ${file2}     ]]; then
        return 0
      fi
    else
      return 0
    fi
  fi
  return 1
}

function file_date_compare_dir_contents_newer_than_file2() {
  local -r dir="${1}"
  local -r file="${2}"
  local file_count=0
  if [[ -e ${file}   ]]; then
    file_count="$(find "${dir}" -type f -newer "${file}" | wc -l)"
  fi
  [[ ${file_count} -gt 0   ]]
}

# Get the directory of the enclosing script
function current_script_dir() {
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

function build_signal_ios() {
  docker run \
    --rm \
    --volume "$(pwd):/src:ro" \
    --volume "$(pwd)/.results/:/forticom/results" \
    "signal_ios_builder:forticom" |
      tee ".results/.forticom.log"
}

main "${@:-}"
