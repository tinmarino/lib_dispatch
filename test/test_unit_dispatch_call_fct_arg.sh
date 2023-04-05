#!/usr/bin/env bash
# Unit test for function_unit_dispatch_call_fct_arg

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr is_in_array print_complete_main print_usage_main mm_at print_usage_main


test_function_unit_dispatch_call_fct_arg(){
  : 'Test function_unit_dispatch_call_fct_arg'
  startup
  fill_fct_dic &> /dev/null; equal 0 $? 'fill_fct_dic status 0'

  # -- 1: void
  out=$(call_fct_arg); equal 0 $? 'call_fct_arg status (1)'
  # TODO
  # THis is still not well formalised
  # "$out" 'call_fct_arg void out'

  # -- 2: toto
  out=$(call_fct_arg toto); equal 0 $? 'call_fct_arg status (2)'
  equal 'grepme-toto:::|' "$out" 'call_fct_arg toto out'

  # -- 3: titi
  out=$(call_fct_arg titi); equal 42 $? 'call_fct_arg status (3)'
  equal 'grepme-titi:::|' "$out" 'call_fct_arg toto out'

  # -- 4: --opt value titi
  out=$(call_fct_arg --opt value titi); equal 42 $? 'call_fct_arg status (4)'
  equal 'grepme-titi:value::|' "$out" 'call_fct_arg toto out'

  # -- 5: titi --opt value
  out=$(call_fct_arg titi --opt value); equal 42 $? 'call_fct_arg status (5)'
  equal 'grepme-titi:value::--opt value|' "$out" 'call_fct_arg toto out'

  # -- 6: --opt value
  out=$(call_fct_arg --opt value); equal 0 $? 'call_fct_arg status (6). Must return 0 (as argument passing succeeded) or could have side effect'
  equal '' "$out" 'call_fct_arg --opt value no out'

  # -- 7: -f 1
  out=$(call_fct_arg titi --opt value -f); equal 42 $? 'call_fct_arg status (7)'
  equal 'grepme-titi:value:flag:--opt value -f|' "$out" 'call_fct_arg toto out'

  # -- 8: -f 2
  out=$(call_fct_arg -f titi --opt value ); equal 42 $? 'call_fct_arg status (8)'
  equal 'grepme-titi:value:flag:--opt value|' "$out" 'call_fct_arg toto out'
}


test_function_unit_dispatch_call_fct_arg


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
