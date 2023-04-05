#!/usr/bin/env bash
# Unit test for function_unit_dispatch_print_usage_fct

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr is_in_array colorize_docstring


test_function_unit_dispatch_print_usage_fct(){
  : 'Test function_unit_dispatch_print_usage_fct'
  # --1: No function dict, no work
  unset g_dispatch_d_fct &> /dev/null
  out=$(print_usage_fct 2> /dev/null); equal "$E_REQ" $? "print_usage_fct status 1: without g_dispatch_d_fct"
  equal '' "$out" "print_usage_fct no in no out"

  # --2: void function dict
  declare -gA g_dispatch_d_fct=(); : "${g_dispatch_d_fct[*]}"
  out=$(print_usage_fct --doc function); equal 0 $? "print_usage_fct status2: without g_dispatch_d_fct"
  equal '' "$out" "print_usage_fct no in no out bis"

  declare -gA g_dispatch_d_fct=(
    [fct1]='description  function 1'
    [fct2]=$'description  function 2\ntwo lines'
  )

  # --3: void arguments (no functions asked)
  out=$(print_usage_fct --doc function); equal 0 $? "print_usage_fct status 3"
  equal '' "$out" "print_usage_fct no in no out ter"

  # --4: Ask fct1
  out=$(print_usage_fct --doc function fct1); equal 0 $? "print_usage_fct status 4"
  [[ "$out" =~ 'fct1' ]]; equal 0 $? "print_usage_fct fct1 name"
  [[ "$out" =~ 'description  function 1' ]]; equal 0 $? "print_usage_fct fct1 desc"

  # --5: Ask fct2
  out=$(print_usage_fct --doc function fct2); equal 0 $? "print_usage_fct status 5"
  [[ "$out" =~ 'fct2' ]]; equal 0 $? "print_usage_fct fct2 name"
  [[ "$out" =~ $'description  function 2\ntwo lines' ]]; equal 0 $? "print_usage_fct fct2 desc"

  # --5: Ask fct1 fct2
  out=$(print_usage_fct --doc function fct1 fct2); equal 0 $? "print_usage_fct status 6"
  [[ "$out" =~ fct1.*description[[:space:]][[:space:]]function[[:space:]]1.*fct2.*description[[:space:]][[:space:]]function[[:space:]]2.*two[[:space:]]lines ]]; equal 0 $? 'print_usage_fct fct1 fct2'

  # --6: Ask fct2 fct1
  out=$(print_usage_fct --doc function fct2 fct1); equal 0 $? "print_usage_fct status 6"
  [[ "$out" =~ fct2.*description[[:space:]][[:space:]]function[[:space:]]2.*two[[:space:]]lines.*fct1.*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct fct2 fct1'

  declare -gA g_dispatch_d_fct=(
    [fct1]='description  function 1'
    [fct2]=$'description  function 2\ntwo lines'
    [mm_opt1]=$'description  option 1'
    [mm_opt2]=$'description  option 2\ntwo lines'
  )

  # --7 Option not appearing if not asked
  out1=$(print_usage_fct --doc function fct2 fct1 mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 7"
  out2=$(print_usage_fct --doc function fct2 fct1); equal 0 $? "print_usage_fct status 7 bis"
  equal "$out1" "$out2" "print_usage_fct same output without options"

  # --8 Function not appearing if not asked
  out1=$(print_usage_fct --doc option fct2 fct1 mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 8"
  out2=$(print_usage_fct --doc option mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 8 bis"
  out=$out2
  equal "$out1" "$out2" "print_usage_fct same output without options"
  [[ "$out" =~ --opt1.*description[[:space:]][[:space:]]option[[:space:]]1.*--opt2.*description[[:space:]][[:space:]]option[[:space:]]2.*two[[:space:]]lines ]];  equal 0 $? 'print_usage_fct mm_opt1 mm_opt2'

  # --9 complete
  out=$(print_usage_fct --complete function fct1 fct2); equal 0 $? "print_usage_fct status 9 bis"
  [[ "$out" =~ fct1[[:space:]]*:[[:space:]]*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct --complete fct1'
  [[ "$out" =~ fct2[[:space:]]*:[[:space:]]*description[[:space:]][[:space:]]function[[:space:]]2 ]]; equal 0 $? 'print_usage_fct --complete fct2'
  [[ ! "$out" =~ "two lines" ]]; equal 0 $? 'print_usage_fct --complete fct2 value not second line'

  # --9 help
  out=$(print_usage_fct --help function fct1 fct2); equal 0 $? "print_usage_fct status 9 bis"
  [[ "$out" =~ fct1.*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct --complete fct1'
  [[ "$out" =~ fct2.*description[[:space:]][[:space:]]function[[:space:]]2 ]]; equal 0 $? 'print_usage_fct --complete fct2'
  [[ ! "$out" =~ "two lines" ]]; equal 0 $? 'print_usage_fct --complete fct2 value not second line'
}


test_function_unit_dispatch_print_usage_fct


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
