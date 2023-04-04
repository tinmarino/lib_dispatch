#!/usr/bin/env bash
# Unit test for function_unit_misc_print_unindent

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


test_function_unit_misc_print_unindent(){
  : 'Test function_unit_misc_print_unindent'
  ref=$'toto\n    titi\n  tata'

  out=$(echo -e $'  toto\n      titi\n    tata\n' | print_unindent); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent 2 spaces in pipe"

  out=$(print_unindent "$(echo -e '  toto\n      titi\n    tata\n')"); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent 2 spaces args"

  out=$(print_unindent "$ref"); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent do not modify not indented strings => idempotent"

  out=$(echo -e '  toto\n    titi\n  tata\nend' | print_unindent); equal 0 $? 'print_unindent never fails'
  [[ "$out" =~ end ]]; equal 0 $? "print_unindent print full line even it not indented"
}


test_function_unit_misc_print_unindent


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
