#!/usr/bin/env bash
# Unit test for function_typos

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend


test_typos(){
  : 'Test function_typos
    Ref: https://github.com/crate-ci/typos
  '
  # Clause: requires rsut typos command
  if ! command -v typos > /dev/null; then
    pinfo "command 'typos' is not present => skipping typos test"
    return 0
  fi

  typos --config "$gs_root_path"/.github/res/typos_config.toml
  (( g_dispatch_i_res |= $? ))
}


test_typos


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
