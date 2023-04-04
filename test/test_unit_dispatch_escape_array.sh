#!/usr/bin/env bash
# Unit test for function_unit_dispatch_escape_array

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


test_function_unit_dispatch_escape_array(){
  : 'Test function_unit_dispatch_escape_array'
  equal "'a' ; 'b'" "$(escape_array a \; b)" "escape_array ;"
  equal "'a' | 'b'" "$(escape_array a \| b)" "escape_array |"
  equal "'a' |& 'b'" "$(escape_array a \|\& b)" "escape_array |&"
  equal "'a' > 'b'" "$(escape_array a \> b)" "escape_array >"
  equal "'a' >> 'b'" "$(escape_array a \>\> b)" "escape_array >>"
  equal "'a' 2> 'b'" "$(escape_array a 2\> b)" "escape_array 2>"
  equal "'a' && 'b'" "$(escape_array a \&\& b)" "escape_array &&"
  equal "'a' || 'b'" "$(escape_array a \|\| b)" "escape_array ||"
  equal "'a' 2>&1 'b'" "$(escape_array a 2\>\&1 b)" "escape_array 2>&1"
  equal "'find' \\;" "$(escape_array find \\\;)" "escape_array \\;"
  equal "'cmd1' | 'cmd2' 'a b' 2> '/dev/null'" "$(escape_array cmd1 \| cmd2 "a b" 2\> /dev/null)" "escape_array large example"
  equal "'bla-bla_bla' 'blabla'" "$(escape_array bla-bla_bla blabla)" "escape_array bla-bla"
  equal $'\'aa\' \'bb\ncc\'' "$(escape_array aa $'bb\ncc')" "escape_array with newline in one parameter"
  escape_array equal 0 0 "In an escaped command" 2\> /dev/null; equal 0 $? 'escape_array should not fail here, with equal'
}


test_function_unit_dispatch_escape_array


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
