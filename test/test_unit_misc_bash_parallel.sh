#!/usr/bin/env bash
# Unit test for function_unit_misc_bash_parallel

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


test_function_unit_misc_bash_parallel(){
  : 'Test function_unit_misc_bash_parallel'
  pwarn "TODO: Not implemented bash_parallel function"
}


test_function_unit_misc_bash_parallel || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
