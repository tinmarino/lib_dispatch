#!/usr/bin/env bash
# Unit test for function_unit_misc_pipe_10

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


test_function_unit_misc_pipe_10(){
  : 'Test function_unit_misc_pipe_10'
  # Helper for pipe
  p_pipe(){ for ((i=1; i<= ${1:-1000}; i++)); do echo "$i"; done; }
  p_join(){ join_by $'\n' "$@"; }

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10 100 200 300 400 500 600 700 800 900 1000 991 992 993 994 995 996 997 998 999 1000)
  equal "$ref" "$(p_pipe | pipe_10)" "Pipe_10 1000 lines"
  # TODO if called from bin and not lib
  # equal "$ref" "$(p_pipe | dispatch dispatch pipe_10)" "Pipe_10 same, calling with dispatch"

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10)
  equal "$ref" "$(p_pipe 10 | pipe_10)" "Pipe_10 10 lines"

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10 21 22 23 24 25 26 27 28 29 30)
  equal "$ref" "$(p_pipe 30 | pipe_10)" "Pipe_10 30 lines"
}


test_function_unit_misc_pipe_10


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
