#!/usr/bin/env bash
# Unit test for placeholder_filename

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"


test_placeholder_filename(){
  g_dispatch_i_res=0

  equal 0 0 "TODO implement test"

  return "$g_dispatch_i_res"
}


test_placeholder_filename || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
