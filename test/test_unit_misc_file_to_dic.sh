#!/usr/bin/env bash
# Unit test for function_unit_mist_file_to_dic

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr vcp


test_function_unit_mist_file_to_dic(){
  : 'Test function_unit_mist_file_to_dic'
  # -- 1: Fail if Not existing file
  out=$(file_to_dic not/existing/file 2> /dev/null)
  # shellcheck disable=SC2181
  (( 0 != $? )); equal 0 $? 'file_to_dic fail if no file'
  equal '' "$out" 'file_to_dic silent in stdout even if fail'

  # --2: Basic example
  file_to_dic <(echo $'v1=12\nvalue_two="grepme quoted"')
  equal 0 $? 'file_to_dic status 0 (basic)'
  # ToUpdate: not working on bash 4.2 as dict is not set here
  #equal 12 "${gd_from_file[v1]}" 'file_to_dic first value'
  #equal 'grepme quoted' "${gd_from_file["value_two"]}" 'file_to_dic second value (quoted)'

  # --3: One line example
  file_to_dic <(echo $'value_to_get_one_line="grepme quoted one line  "')
  equal 0 $? 'file_to_dic status 0 (one line)'
  # ToUpdate: not working on bash 4.2 as dict is not set here
  #equal 1 "${#gd_from_file[@]}" 'file_to_dic output with only one value'
  #equal 'grepme quoted one line  ' "${gd_from_file["value_to_get_one_line"]}" 'file_to_dic one line value (quoted)'
}


test_function_unit_mist_file_to_dic


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
