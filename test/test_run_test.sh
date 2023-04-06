#!/usr/bin/env bash
# Unit test for dispatch very lowest level utilities
# Those used for printing errors in other utilities

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
  gs_root_path="$(dirname "$gs_root_path")"; gs_root_path="$(dirname "$gs_root_path")"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi


test_run_test(){
  "$gs_root_path"/test/run_test.sh fail

}

test_run_test "$@"


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res, at $tmp_bank"
exit "$g_dispatch_i_res"
