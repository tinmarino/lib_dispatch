#!/usr/bin/env bash
# Unit test for function_unit_misc_abat

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

depend

test_unit_misc_abat(){
  : 'IDEA test if bat is available'
  # -- 1: Normal
  out=$(echo -e 'this\n is an unk_string yes\nend' | abat); equal 0 $? 'abat never fails'
  [[ "$out" =~ unk_string ]]; equal 0 $? 'abat do not highlight an unknown string'

  # -- 2: No in no out
  # Comment out as not working if bat not installed, there are some escape sequences
  # -- out=$(echo -n | abat); equal 0 $? 'abat never fails'
  # -- [[ -z "$out" ]]; equal 0 $? 'abat no in no out'

  # -- N: no input
  # Comment out as not running in jenkins ...
  # -- out=$(command_timeout 1 bash -c "source \"$gs_root_path/test/lib_test.sh\"; abat 2> /dev/null"); equal "$E_REQ" $? 'abat must complain if not run in a pipe'
  # -- equal '' "$out" 'abat out of pipe should not print to stdout'
}


test_unit_misc_abat || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
