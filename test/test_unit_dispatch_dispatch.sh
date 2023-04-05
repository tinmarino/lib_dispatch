#!/usr/bin/env bash
# Unit test for function_unit_dispatch_dispatch

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend fill_fct_dic call_fct_arg


test_function_unit_dispatch_dispatch(){
  : 'Test function_unit_dispatch_dispatch'
  startup
  # -- 1: bad
  out=$(dispatch function_not_existing 2> /dev/null); equal "$E_ARG" $? 'dispatch status (1) <= bad function name'
  equal '' "$out" 'dispatch fails silently on stdout'

  # -- 2: no arg
  out=$(dispatch 2> /dev/null); equal 0 $? 'dispatch status (2) <= no arg'
  # TODO should be stderr
  # equal '' "$out" 'dispatch explains silently on stdout'

  # -- 3: basic function
  out=$(dispatch toto); equal 0 $? 'dispatch status (3)'
  equal 'grepme-toto:::|' "$out" 'dispatch '

  # -- 4: function option
  out=$(dispatch --opt value titi); equal 42 $? 'dispatch status (4)'
  equal 'grepme-titi:value::|' "$out" 'dispatch '

  # -- 5: function flag option
  out=$(dispatch titi -f --opt value); equal 42 $? 'dispatch status (5)'
  equal 'grepme-titi:value:flag:-f --opt value|' "$out" 'dispatch '
}


test_function_unit_dispatch_dispatch


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
