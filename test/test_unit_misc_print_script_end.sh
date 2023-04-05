#!/usr/bin/env bash
# Unit test for function_unit_dispatch_print_script_end

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


test_function_unit_dispatch_print_script_end(){
  : 'Test function_unit_dispatch_print_script_end'
  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_end 2>&1 > /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ -n "$out" ]]; equal 0 $? 'print_script_start gets something in stderr'

  # Stdout gets nothing
  declare -g g_dispatch_b_print=1
  out=$(print_script_end a b ccc 2> /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_end gets nothing in stdout'

  # Nothing if silenced
  declare -g g_dispatch_b_print=0
  out=$(echo | print_script_end 2>&1); equal 0 $? 'print_script_end always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_end gets nothing if silenced'

  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_end 0 grepme_print_script_end1 "grepme  print_script_end  with space" 2>&1 > /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ "$out" =~ grepme_print_script_end ]]; equal 0 $? 'print_script_start gets arg1 in stderr'
  [[ "$out" =~ "grepme  print_script_end  with space" ]]; equal 0 $? 'print_script_start gets arg2 in stderr'

  # After 0 second
  # shellcheck disable=SC2034  # g_dispatch_b_print appears unused
  declare -g g_dispatch_b_print=1
  out=$({ print_script_start; print_script_end; } 2>&1 > /dev/null | grep -o 'After:.*$')
  equal 0 $? 'print_script_end always status 0'

  [[ "$out" == 'After: 0h:0m:0s' ]] || [[ "$out" == 'After: 0h:0m:1s' ]]; equal 0 $? "print_script_end after 0 or 1 seconds"

  # Commented out as I do not like to sleep
  # # After 1 second
  # out=$({ print_script_start; sleep 1.1;  print_script_end; } 2>&1 > /dev/null | grep -o 'After:.*$')
  # equal 0 $? 'print_script_end always status 0'
  # equal 'After: 0h:0m:1s' "$out" 'print_script_end after 1 second'
}


test_function_unit_dispatch_print_script_end


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
