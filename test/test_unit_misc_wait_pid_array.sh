#!/usr/bin/env bash
# Unit test for function_unit_misc_wait_pid_array

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


test_function_unit_misc_wait_pid_array(){
  : 'Test function_unit_misc_wait_pid_array'
  local -a a_pid=(); : "${a_pid[*]}"

  # Returned forked jobs
  # shellcheck disable=SC2016  # Expressions don't expand in single quotes
  bash_timeout 0.5 'for _i in {1..5}; do : & a_pid+=($!); done; wait_pid_array "${a_pid[@]}"'
  equal 0 $? 'wait_pid_array with job fork'

  # Timedout one fork job sleeping
  bash_timeout 0.1 'sleep 1 & wait_pid_array $!'
  (( 128 < $? )); equal 0 $? 'wait_pid_array with job fork'

  # Timedout multiple jobs, one sleeping
  # shellcheck disable=SC2016  # Expressions don't expand in single quotes
  bash_timeout 0.1 '
    for i in {1..5}; do
      if (( 3 == i )); then
        : & a_pid+=($!)
      else
        sleep 1 & a_pid+=($!)
      fi
    done
    wait_pid_array "${a_pid[@]}"
  '; equal 137 $? 'wait_pid_array with job fork'
}


test_function_unit_misc_wait_pid_array


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
