#!/usr/bin/env bash
# Unit test for function_unit_misc_vcp

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


test_function_unit_misc_vcp(){
  : 'Test function_unit_misc_vcp'
  # Declarations
  var="  345  89  "; : "$var"
  declare -a ind_array=(Betty "  345  89  ")
  declare -A asso_array=([one]=Harry [two]=Betty [some_signs]=" +*.<\$~,'/ ")

  # produce the copy
  vcp var var_2; equal 0 $? "vcp never fails"
  [[ "$var_2" == "  345  89  " ]]; equal 0 $? "vcp string"

  vcp ind_array ind_array_2; equal 0 $? "vcp never fails"
  [[ "$(declare -p ind_array_2 2> /dev/null)" =~ -a ]]; equal 0 $? "vcp array"
  [[ "${ind_array[0]}" == Betty ]]; equal 0 $? "vcp array content"

  vcp asso_array asso_array_2; equal 0 $? 'vcp never fails'
  [[ "$(declare -p asso_array_2 2> /dev/null)" =~ -A ]]; equal 0 $? "vcp dic"
  [[ "${asso_array[two]}" == Betty ]]; equal 0 $? "vcp dic content"

  return "$g_dispatch_i_res"
}


test_function_unit_misc_vcp


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
