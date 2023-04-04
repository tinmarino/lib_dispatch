#!/usr/bin/env bash
# Unit test for function_unit_misc_get_opt

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr


test_function_unit_misc_get_opt(){
  : 'Test function_unit_misc_get_opt'
  equal "arg1 arg2" "$(get_opt --param --param arg1 arg2)" 'get_opt with only good parameter'
  equal "arg1 arg2" "$(get_opt --param --date 30 --param arg1 arg2)" 'get_opt prefixed with other parameter'
  equal "arg1 arg2" "$(get_opt --param positional --param arg1 arg2 --date 30)" 'get_opt with redundant parameter'
  equal "" "$(get_opt --param)" 'get_opt no aditional parameter, no output'
  get_opt 2> /dev/null; equal "$E_REQ" $? 'get_opt with zero parameter should fail'
  equal "" "$(get_opt 2> /dev/null)" 'get_opt with zero parameter should have no stdout'
}


test_function_unit_misc_get_opt


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
