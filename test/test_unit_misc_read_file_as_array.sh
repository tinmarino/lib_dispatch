#!/usr/bin/env bash
# Unit test for function_unit_misc_read_file_as_array

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


test_function_unit_misc_read_file_as_array(){
  : 'Test function_unit_misc_read_file_as_array'
  # First test, normal input
  read_file_as_array a_out <(echo -e '1\n2 3\n4'); equal 0 $? 'read_file_as_array should not fail here'
  equal 1 "${a_out[0]}" "read_file_as_array 1"
  equal "2 3" "${a_out[1]}" "read_file_as_array 2"
  equal 4 "${a_out[2]}" "read_file_as_array 3"
  # Second test, from stdin
  # -- Backup
  save_shop=$(shopt -p lastpipe)
  set_m=${-//[^m]/}
  a_out=()
  # -- Change option
  set +m  # Disable monitor mode
  shopt -s lastpipe  # Enable last pipe command in current shell (to set variable)
  # -- Work
  echo -e 'a\nb b\n#commented\nccc cc' | read_file_as_array a_out
  # -- Assert
  equal 0 $? 'read_file_as_array return 0'
  equal "a" "${a_out[0]}" "read_file_as_array 1"
  equal "b b" "${a_out[1]}" "read_file_as_array 2"
  equal "ccc cc" "${a_out[2]}" "read_file_as_array 3"
  # -- Restore option
  $save_shop
  [[ -n "$set_m" ]] && set -m
}


test_function_unit_misc_read_file_as_array


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
