#!/usr/bin/env bash
# Unit test for function_unit_misc_bash_timeout

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend


test_function_unit_misc_bash_timeout(){
  : 'Test function_unit_misc_bash_timeout'
  # Define helper function
  test_timeout(){
    # 1: max timeout, 2: soft timeout
    system_timeout "$1" bash -c '
      '"$(declare -f bash_timeout)"'
      bash_timeout '"$2"' '"'$3'"'
      exit $?  # In subshell
    '
  }
  # -- 1: normal return
  test_timeout 2 1 'toto(){ return 42; }; toto'  # in subshell
  equal 42 $? "bash_timeout return without timeout"

  # -- 2: normal return fractional
  test_timeout 0.5 "0.2" 'toto(){ return 42; }; toto'  # in subshell
  equal 42 $? "bash_timeout return without timeout, fractional"

  # -- 3: timedout return fractional
  test_timeout 0.5 "0.1" 'toto(){ sleep 0.5; return 42; }; toto'  # in subshell
  equal 137 $? "bash_timeout timedout, fractional"

  # -- 4: failed return very fractional
  test_timeout 0.2 "0.01" 'toto(){ sleep 0.5; return 42; }; toto'  # in subshell
  equal 137 $? "bash_timeout timedout, fractional"

  # -- 5: failed return very fractional
  test_timeout 0.5 "0.1" 'sleep 2 & wait $!'  # in subshell
  equal 137 $? "bash_timeout timedout even if child waits"
}


test_function_unit_misc_bash_timeout || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
