#!/usr/bin/env bash
# Unit test for function_unit_dispatch_print_usage_env

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


test_function_unit_dispatch_print_usage_env(){
  : 'Test function_unit_dispatch_print_usage_env'
  # --1: No __set_env no problem
  unset __set_env &> /dev/null
  out=$(print_usage_env 2>&1); equal 0 $? 'print_usage_env always succeed (1)'
  equal '' "$out" 'print_usage_env silent even if no __set_env'

  # --2: __set_env with traps
  __set_env(){
    : 'Internal helper to set environment variables'
    set -a
    # Required
    # shellcheck disable=SC2092  # Remove backticks to avoid executing output (or use eval if intentional)
    `#: "${GREPMEREQ:=default_req}"`
    : "${EXAMPLE:=default_example_value}"
    : echo otot
    : "dosting sutpid"
    set +a
    magic
  }
  out=$(print_usage_env 2>&1); equal 0 $? 'print_usage_env function always succeed (2)'
  [[ "$out" =~ EXAMPLE.*default_example_value ]]; equal 0 $? 'print_usage_env contains default env'
  [[ "$out" =~ GREPMEREQ.*default_req.*Required ]]; equal 0 $? 'print_usage_env contains required env parameter'
}


test_function_unit_dispatch_print_usage_env


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
