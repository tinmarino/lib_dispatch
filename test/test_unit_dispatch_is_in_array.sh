#!/usr/bin/env bash
# Unit test for function_unit_dispatch_is_in_array

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


test_function_unit_dispatch_is_in_array(){
  : 'Test function_unit_dispatch_is_in_array'
  array=("something to search for" "a string" "test2000")
  out=$(is_in_array 2>&1); equal 1 $? 'is_in_array no argument => 1'
  equal '' "$out" "is_in_array no output 1"
  out=$(is_in_array arg1 2>&1); equal 1 $? 'is_in_array one argument => 1'
  equal '' "$out" "is_in_array no output 2"
  out=$(is_in_array "a string" "${array[@]}" 2>&1); equal 0 $? 'is_in_array found 1'
  equal '' "$out" "is_in_array no output 3"
  is_in_array "a" "${array[@]}"; equal 1 $? 'is_in_array not found a'
  is_in_array "a strin" "${array[@]}"; equal 1 $? 'is_in_array not found substring'
  out=$(is_in_array "a stringg" "${array[@]}" 2>&1); equal 1 $? 'is_in_array not found superstring'
  equal '' "$out" "is_in_array no output 4"
}


test_function_unit_dispatch_is_in_array


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
