#!/usr/bin/env bash
# Unit test for function_unit_misc_bash_sleep

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


test_function_unit_misc_bash_sleep(){
  : 'Test function_unit_misc_bash_sleep'
  out=$(bash_sleep 0.001 2>&1); equal 0 $? "bash_sleep: normal return 0"
  equal "" "$out" "bash_sleep: no stdout nor stderr"

  out=$(bash_timeout 0.001 bash_sleep 0.2); equal 137 $? "bash_sleep: timedout"
  equal "" "$out" "bash_sleep and bash_timeout no stdout nor stderr"
}


test_function_unit_misc_bash_sleep || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
