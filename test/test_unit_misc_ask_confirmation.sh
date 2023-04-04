#!/usr/bin/env bash
# Unit test for function_unit_misc_ask_confirmation

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend ##


test_function_unit_misc_ask_confirmation(){
  : 'Test function_unit_misc_ask_confirmation'
  out=$(echo y | ask_confirmation 'msg' 2> /dev/null); res=$?
  equal "" "$out" 'ask_confirmation should not print on stdout'
  equal 0 "$res" "ask_confirmation OK"

  out=$(echo n | ask_confirmation 'msg' 2> /dev/null); equal 1 $? "ask_confirmation NO"

  err=$(echo n | ask_confirmation 'msg' 2>&1); equal 1 $? "ask_confirmation NO"
  [[ "$err" =~ NO ]]; equal 0 $? "ask_confirmation if say no, NO should be visible"
  err=$(echo y | ask_confirmation 'msg' 2>&1); [[ "$err" =~ OK ]]; equal 0 $? "ask_confirmation if say yes, OK should be visible"
}


test_function_unit_misc_ask_confirmation


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
