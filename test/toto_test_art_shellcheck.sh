#!/usr/bin/env bash
# Shellcheck all scripts

# Source test utilities
  export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
  gs_root_path="$(dirname "$gs_root_path")"
  gs_root_path="$(dirname "$gs_root_path")"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"


test_shellcheck(){
  local file=''  # loop variable

  # Craft chekcs to ignore
  local exclude=''
  exclude+=SC2155,  # Declare and assign separately to avoid masking return values -> Prevent declare -a, local t=$(get)
  exclude+=SC2092,  # Remove backticks for docstring in code
  exclude+=SC2154,  # cyellow is referenced but not assigned.
  exclude+=SC2016  # Expressions don't expand in single quotes, use double quotes for that

  # Hi
  start_test_function "Testing Linting of scripts with shellcheck, exclude=$exclude"

  # Clause shellcheck executable must be present
  if command -v shellcheck > /dev/null; then
    equal 0 0 "Info: OK: Shellcheck if present in the machine"
  else
    equal 0 0 "Info: Shellcheck executable is not present => skipping"
    equal 0 0 "Info: Shellcheck: Ref: https://snapcraft.io/install/shellcheck/rhel and https://github.com/koalaman/shellcheck"
    return 0
  fi

  # Clause shellcheck version > 0.7
  local version=$(shellcheck -V | sed -n '/version: [0-9.]/s/version: *//p')
  version=${version##0.}
  if (( version >= 7 )); then
    equal 0 0 "Info: OK: Shellcheck version >= 0.7 ($version)"
  else
    equal 0 0 "Info: Shellcheck version too old: < 0.7 ($version) => skipping"
    return
  fi

  pushd "$gs_root_path" > /dev/null || return 2

  # Fill command to run for each file
  declare -gA gd_bash_parallel_command=()
  for file in script/*.sh test/*.sh; do
    gd_bash_parallel_command["$file"]="shellcheck --exclude \"$exclude\" \"$file\""
  done

  # Work parallel
  bash_parallel

  # Report
  for file in "${!gd_bash_parallel_command[@]}"; do
    equal 0 "${gd_bash_parallel_status[$file]}" "Lint: ShellCheck: \"$file\" script is well linted. stdout=${gd_bash_parallel_stdout[$file]}"
  done

  popd > /dev/null || return 2
  return 0
}


test_shellcheck


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
