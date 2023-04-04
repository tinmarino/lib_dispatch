#!/usr/bin/env bash
# Unit test for function_unit_misc_fcp

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


test_function_unit_misc_fcp(){
  : 'Test function_unit_misc_fcp'
  toto(){ echo grepme-toto; }

  out=$(fcp toto titi 2>&1); equal 0 $? 'fcp succeed'
  equal '' "$out" 'fcp silent'

  fcp toto titi
  out=$(titi); equal 0 $? "fcp function called"
  [[ "$out" == grepme-toto ]]; equal 0 $? "fcp good function copied"

  unset toto
  out=$(fcp toto titi 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp first argument must be defined'
  equal '' "$out" 'fcp stdout silent 1'

  out=$(fcp toto 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 2'
  equal '' "$out" 'fcp stdout silent 2'

  out=$(fcp 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 3'
  equal '' "$out" 'fcp stdout silent 3'

  out=$(fcp toto titi tata tutu "" 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 4'
  equal '' "$out" 'fcp stdout silent 4'

  return "$g_dispatch_i_res"
}


test_function_unit_misc_fcp


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
