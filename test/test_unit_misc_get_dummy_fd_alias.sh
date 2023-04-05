#!/usr/bin/env bash
# Unit test for function_unit_misc_get_dummy_fd_alias

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


test_function_unit_misc_get_dummy_fd_alias(){
  : 'Test function_unit_misc_get_dummy_fd_alias
    Doc: Check if a file descriptor is opened:
    -- https://unix.stackexchange.com/questions/206786/testing-if-a-file-descriptor-is-valid
  '
  local -i fd=""
  local out=''

  # 1/ Basic usage
  # -- Create
  get_dummy_fd_alias
  (( fd )); equal 0 $? "get_dummy_fd_alias: created a non zero fd (=$fd)"
  # shellcheck disable=SC2261  # Multiple redirections compete for stderr
  : >&"$fd" 2> /dev/null; equal 0 $? "get_dummy_fd_alias: fd is valid and opened"
  # -- Write
  echo "  line  1  " >&"$fd"
  echo "  line  2  " >&"$fd"
  # -- Read1 shoudl block
  while IFS= read -r -t 0.001 -u "$fd" line; do
    out+=$line$'\n'
  done
  equal $'  line  1  \n  line  2  \n' "$out" "get_dummy_fd_alias: could read back what I wrote to fd"

  # -- Close
  exec {fd}>&-
  # shellcheck disable=SC2261  # Multiple redirections compete for stderr
  ! : >&"$fd" 2> /dev/null; equal 0 $? "get_dummy_fd_alias: could close its fd (i.e. not immortal zombie)" 
}


test_function_unit_misc_get_dummy_fd_alias


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
