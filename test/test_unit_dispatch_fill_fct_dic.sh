#!/usr/bin/env bash
# Unit test for function_unit_dispatch_fill_fct_dic

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"


# Declare dependencies
depend perr subtract_array get_fct_docstring


test_function_unit_dispatch_fill_fct_dic(){
  : 'Test function_unit_dispatch_fill_fct_dic'
  unset toto &> /dev/null
  unset titi &> /dev/null
  declare -ga g_dispatch_a_fct_to_hide=()  # Array of already defined function to hide (Filled by lib_dispatch)
  declare -ga g_dispatch_a_dispach_args=()  # Array of arguments given by the first user command
  declare -gA g_dispatch_d_fct_default=()  # Default functions defined by hardcode
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
  : "${g_dispatch_a_dispach_args[*]}"
  : "${g_dispatch_d_fct_default[*]}"
  : "${g_dispatch_a_fct_to_hide[*]}"

  # --1: With nothing gets nothing
  out=$(fill_fct_dic); equal 0 $? "fill_fct_dic succeed 1"
  equal '' "$out" "fill_fct_dic null in null out"
  fill_fct_dic &> /dev/null
  # shellcheck disable=SC2154  # g_dispatch_d_fct
  equal 0 "${#g_dispatch_d_fct[@]}" "fill_fct_dic dictionarry out should be empty (keys=${!g_dispatch_d_fct[*]})"

  # --2: Define toto and titi
  startup
  out=$(fill_fct_dic); equal 0 $? "fill_fct_dic succeed 2"
  equal '' "$out" "fill_fct_dic null in null out"
  fill_fct_dic &> /dev/null
  equal 4 "${#g_dispatch_d_fct[@]}" "fill_fct_dic no out in dict (keys=${!g_dispatch_d_fct[*]})"
  equal $'Doc  toto\ntwo lines' "${g_dispatch_d_fct[toto]}" "fill_fct_dic toto and his doc"
  equal $'Doc  titi' "${g_dispatch_d_fct[titi]}" "fill_fct_dic titi and his doc"
}


test_function_unit_dispatch_fill_fct_dic


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
