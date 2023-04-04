#!/usr/bin/env bash
# Unit test for function_unit_misc_print_args

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


test_function_unit_misc_print_args(){
  : 'Test function_unit_misc_print_args'
  out=$(print_args); equal 0 $? "print_args always succeed"
  equal '' "$out" "print_args no arg no out"
  out=$(print_args 1 2); equal 0 $? "print_args always succeed"
  equal $'1/ 1\n2/ 2' "$out" "print_args 1 2"
  out=$(print_args 1 2 "3 titi" toto); equal 0 $? "print_args always succeed"
  equal $'1/ 1\n2/ 2\n3/ 3 titi\n4/ toto' "$out" "print_args big"
}


test_function_unit_misc_print_args


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
