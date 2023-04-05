#!/usr/bin/env bash
# Unit test for function_unit_dispatch_run

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


test_function_unit_dispatch_run(){
  : 'Test function_unit_dispatch_run'
  fct(){
    echo Grepme-fct
    return 3
  }
  fct_proxy(){
    fct "$@"
    return $?
  }
  return_42(){ return 42; }
  return_0(){ return 0; }
  run return_0 &> /dev/null; equal 0 $? "Run proxy status 0"
  run return_42 &> /dev/null; equal 42 $?  "Run proxy status 42"
  all_out=$(g_dispatch_b_print=1 g_dispatch_b_run=1; run fct_proxy a "b c" d1); equal 3 $? "Run fct status"
  all_err=$(g_dispatch_b_print=1 g_dispatch_b_run=1; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 3 $? "Run fct status"
  no_out=$(g_dispatch_b_print=1 g_dispatch_b_run=0; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 0 $? "Run fct status without run"
  # shellcheck disable=SC2034  # g_dispatch_b_print appears unused
  no_err=$(g_dispatch_b_print=0 g_dispatch_b_run=1; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 3 $? "Run fct status without print"

  [[ "$all_out" =~ Grepme-fct ]]; equal 0 $? "Run stdout"
  [[ ! "$no_out" =~ Grepme-fct ]]; equal 0 $? "Run stdout not"
  [[ "$all_err" =~ fct_proxy ]]; equal 0 $? "Run stderr"
  [[ ! "$no_err" =~ fct_proxy ]]; equal 0 $? "Run stderr not"
}


test_function_unit_dispatch_run


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
