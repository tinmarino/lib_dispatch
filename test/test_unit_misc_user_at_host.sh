#!/usr/bin/env bash
# Unit test for function_unit_misc_user_at_host

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend ""


test_function_unit_misc_user_at_host(){
  : 'Test function_unit_misc_user_at_host'
  out=$(USER=user HOSTNAME=hostname user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'user@hostname' "$out" 'user_at_host 2 var'

  out=$(unset USER USERNAME; HOSTNAME=hostname user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'hostname' "$out" 'user_at_host 1 var: host'

  out=$(unset HOSTNAME; USER=user user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'user@localhost' "$out" 'user_at_host 1 var: user'

  out=$(unset HOSTNAME USER USERNAME; user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'localhost' "$out" 'user_at_host 0 var'
}


test_function_unit_misc_user_at_host


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
