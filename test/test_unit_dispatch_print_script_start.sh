#!/usr/bin/env bash
# Unit test for function_unit_dispatch_print_script_start

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


test_function_unit_dispatch_print_script_start(){
  : 'Test function_unit_dispatch_print_script_start'
  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_start 2>&1 > /dev/null); equal 0 $? 'print_script_start always status 0'
  [[ -n "$out" ]]; equal 0 $? 'print_script_start gets something in stderr'

  # Stdout gets nothing
  declare -g g_dispatch_b_print=1
  out=$(print_script_start a b ccc 2> /dev/null); equal 0 $? 'print_script_start always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_start gets nothing in stdout'

  # Nothing if silenced
  declare -g g_dispatch_b_print=0
  out=$(echo | print_script_start 2>&1); equal 0 $? 'print_script_start always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_start gets nothing if silenced'

  # Just for lint
  : "$g_dispatch_b_print"
}


test_function_unit_dispatch_print_script_start


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
