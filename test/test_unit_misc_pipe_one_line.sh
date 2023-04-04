#!/usr/bin/env bash
# Unit test for function_unit_misc_pipe_one_line

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


test_function_unit_misc_pipe_one_line(){
  : 'Test function_unit_misc_pipe_one_line'
  out=$(echo -n 'grepme-one-line' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 1"
  [[ "$out" =~ grepme-one-line ]]; equal 0 $? "pipe_one_line one line no return"

  out=$(echo 'grepme-one-line' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 1"
  [[ "$out" =~ grepme-one-line ]]; equal 0 $? "pipe_one_line one line with newline in end"

  out=$(echo -e 'a\nb c\nd' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 2"
  [[ "$out" =~ d ]]; equal 0 $? "pipe_one_line outputs last line"
}


test_function_unit_misc_pipe_one_line


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
