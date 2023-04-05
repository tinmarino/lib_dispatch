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
  local string="  string  content  ";
  local -a ind_array=(Betty "  string  content  " Berta)
  local -A asso_array=([one]=Harry [two]=Betty [some_signs]=" +*.<\$~,'/ ")
  # Silence shellcheck
  : "$string" "${string_2:=}" "${asso_array_2:=}" "${ind_array_2:=}"

  # 0/ Void
  vcp; equal 0 $? "vcp: with no argument: never fails"

  # 1/ String
  vcp string string_2; equal 0 $? "vcp: with a string: never fails"
  [[ "$(declare -p ind_array_2 2> /dev/null)" == "declare --"* ]]; equal 0 $? "vcp: copy string: resulted in string"
  equal "  string  content  " "$string_2" "vcp: copy string: resulted in the same string"

  # 2/ Array
  vcp ind_array ind_array_2; equal 0 $? "vcp: with an array: never fails"
  [[ "$(declare -p ind_array_2 2> /dev/null)" == "declare -a"* ]]; equal 0 $? "vcp: copy array: resulted in array"
  equal Betty "${ind_array[0]}" "vcp: copy array: element 0 is the same"
  equal "  string  content  " "${ind_array[1]}" "vcp: copy array: element 1 is the same"
  equal Berta "${ind_array[2]}" "vcp: copy array: element 2 is the same"

  # 3/ Dic
  vcp asso_array asso_array_2; equal 0 $? 'vcp: with a dic: never fails'
  [[ "$(declare -p asso_array_2 2> /dev/null)" == "declare -A"* ]]; equal 0 $? "vcp: with a dic: returned a dic"
  equal Harry "${asso_array[one]}" "vcp: copy dic: element one is the same"
  equal Betty "${asso_array[two]}" "vcp: copy dic: element two is the same"
  equal " +*.<\$~,'/ " "${asso_array[some_signs]}" "vcp: copy dic: element some_signs is the same"

  return "$g_dispatch_i_res"
}


test_function_unit_misc_vcp


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
