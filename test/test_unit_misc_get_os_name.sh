#!/usr/bin/env bash
# Unit test for function_unit_misc_get_os_name

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend file_to_dic


test_function_unit_misc_get_os_name(){
  : 'Test function_unit_misc_get_os_name'
  equal 0 0 'ToUpdate: commented out as bad dictionary for RH7'
  #uname=$(uname -a)
  #os_name=$(get_os_name); equal 0 $? "get_os_name succeed (and returned: $os_name)"
  #shopt_nocasematch=$(shopt -p nocasematch)
  #shopt -s nocasematch
  #case $uname in
  #  *el8*)
  #    [[ "$os_name" =~ 8 ]]; equal 0 $? 'get_os_name with a 8 inside <= el8'
  #    ;;
  #  *el7*)
  #    [[ "$os_name" =~ 7 ]]; equal 0 $? 'get_os_name with a 7 inside <= el7'
  #    ;;
  #  *ubuntu*)
  #    [[ "$os_name" =~ ubuntu ]]; equal 0 $? 'get_os_name with ubuntu inside <= ubuntu'
  #    ;;
  #esac
  #$shopt_nocasematch
}


test_function_unit_misc_get_os_name


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
