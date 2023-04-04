#!/usr/bin/env bash
# Unit test for function_unit_dispatch_substract_array

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


test_function_unit_dispatch_substract_array(){
  : 'Test function_unit_dispatch_substract_array'
  readarray -t a_out < <(substract_array);
  equal "" "${a_out[*]}" 'substract_array no argument'
  readarray -t a_out < <(substract_array -- 1)
  equal "" "${a_out[*]}" 'substract_array -- 1'
  readarray -t a_out < <(substract_array 1 "2 3" 4 -- "2 3" 4 1)
  equal "" "${a_out[*]}" 'substract_array remove them all'
  readarray -t a_out < <(substract_array 1 "2 3" 4 -- "2 3" 4 1 1 4)
  equal "" "${a_out[*]}" 'substract_array remove them all and more'
  readarray -t a_out < <(substract_array 1)
  equal "1" "${a_out[*]}" 'substract_array 1'
  readarray -t a_out < <(substract_array 1 "2 3" 4 5 -- "2 3")
  [[ "${a_out[*]}" =~ 1 ]]; equal 0 $? 'substract_array stupid 1'
  [[ "${a_out[*]}" =~ 2 ]]; equal 1 $? 'substract_array stupid 2'
  [[ "${a_out[*]}" =~ 3 ]]; equal 1 $? 'substract_array stupid 3'
  [[ "${a_out[*]}" =~ 4 ]]; equal 0 $? 'substract_array stupid 4'
  [[ "${a_out[*]}" =~ 5 ]]; equal 0 $? 'substract_array stupid 5'
}


test_function_unit_dispatch_substract_array


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
