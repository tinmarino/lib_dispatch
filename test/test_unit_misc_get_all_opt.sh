#!/usr/bin/env bash
# Unit test for function_unit_misc_get_all_opt

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


test_function_unit_misc_get_all_opt(){
  : 'Test function_unit_misc_get_all_opt'
  set -- "var with space" --param1 "param 1" --param2 "param 2" end
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails"
  # shellcheck disable=SC2154  # param1 is referenced but not assigned
  equal "param 1" "$param1" "get_all_opt_alias should set param1" \
    --desc "Called with $*"
  # shellcheck disable=SC2154  # param1 is referenced but not assigned
  equal "param 2" "$param2" "get_all_opt_alias should set param2" \
    --desc "Called with $*"
  
  # No arg
  set --
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias should never fails, here with no arg" \
    --desc "Called with $*"

  # No param
  set -- --param1
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails, here with option but no associated parameter" \
    --desc "Called with $*"
  equal "param 1" "$param1" "get_all_opt_alias should not reset param1 if it did not receive the desired value" \
    --desc "Called with $*"

  # Empty param
  set -- --param1 ''
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails, here called with empty srtring as option value" \
    --desc "Called with $*"
  equal "" "$param1" "get_all_opt_alias should have reseted param1 as it was explicited" \
    --desc "Called with $*"
}


test_function_unit_misc_get_all_opt


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
