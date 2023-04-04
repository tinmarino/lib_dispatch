#!/usr/bin/env bash
# Unit test for function_unit_misc_print_stack

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend


test_function_unit_misc_print_stack(){
  : 'Test function_unit_misc_print_stack'
  # Helper to test stack
  fct2(){
    # Line before
    print_stack
    return $?
  }
  fct1(){
    fct2 "$@"
    return $?
  }
  # -- 1: Normal use
  out=$(fct1 a "b c" d)
  equal 0 $? "print_stack with function name"
  [[ "$out" =~ fct2.*fct1 ]]; equal 0 $? "print_stack: the stack should appear with desired function in desired order"
  [[ "$out" == *"${BASH_SOURCE[0]##*/}"* ]]; equal 0 $? "print_stack: the stack should contain string '${BASH_SOURCE[0]##*/}' name of the current test file"

  # -- 2: With argument trace
  out=$(shopt -s extdebug; fct1 grepme-argument a "b c" d)
  [[ "$out" =~ "grepme-argument, a, b c, d" ]]; equal 0 $? "print_stack stack with argument if extdebug"
}


test_function_unit_misc_print_stack || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
