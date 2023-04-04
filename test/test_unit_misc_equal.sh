#!/usr/bin/env bash
# Unit test for function_equal

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

depend ""


test_function_equal(){
  : 'test me first as they all depend on me!'
  # 1: Integer success and stdout
  out=$(g_junit_file="" equal 0 0 'Test self' 2> /dev/null)
  equal 0 $? 'Equal: equal 0 0: must return 0'
  equal '' "$out" 'Equal: equal 0 0: must have no standard output'

  # 2 Integer failure and stdout
  out=$(g_junit_file="" gi_summary_write_fd=0 equal 1 0 'Test self' 2> /dev/null); equal 1 $? 'Equal: equal 1 0: must return exit status 1'
  equal '' "$out" 'Equal: equal 1 0: must have no standard output'
  equal '' "$out" 'Equal: equal 1 0: must have no standard output'

  # 3 String success and stderr
  out=$(g_junit_file="" equal '  aa b ' '  aa b '  'grepme  equal1' 2>&1); equal 0 $? 'Equal: equal with same string must return 0'
  # shellcheck disable=SC2076  # Remove quotes
  [[ "$out" =~ "[+]" ]]; equal 0 $? "Equal: if equal success, it must have a [plus] symbol"
  [[ "$out" =~ "Success" ]]; equal 0 $? "Equal: if equal success, it must have a 'Success' string"
  [[ "$out" =~ "grepme  equal1" ]]; equal 0 $? "Equal: equal function must print the comment argument"

  # 4 String failure and stderr
  out=$(g_junit_file="" gi_summary_write_fd=0 equal ' aa b ' 'aa b '  'grepme  equal2' 2>&1); equal 1 $? 'Equal: equal with different strings must return 1'
  [[ "$out" == *"[-]"* ]]; equal 0 $? "Equal: equal string OK with [mimus]"
  [[ "$out" == *"Error"* ]]; equal 0 $? 'equal string OK with (the bad word)'
  [[ "$out" == *"grepme  equal2"* ]]; equal 0 $? 'equal string OK with Arg3'

  # 5 Introspection
  out=$(g_junit_file="" equal 'grepme equal3' 'grepme equal3' 2>&1); equal 0 $? 'equal same string again => ret 0'
  [[ "$out" =~ "grepme equal3" ]]; equal 0 $? 'equal can inspect line where sent'

  # 6 Writing to g_junit_file
  junit=$(mktemp)
  out=$(g_junit_file="$junit" equal 'grepme-junit1' 'grepme-junit1' "grepme-junit2" 2>&1); equal 0 $? 'equal junit same string again => ret 0'
  junit_content=$(<"$junit")
  [[ "$junit_content" =~ Success ]]; equal 0 $? "equal is writing to junit: Success"
  [[ "$junit_content" =~ grepme-junit1 ]]; equal 0 $? "equal is writing to junit: grepme-junit1 => the string to match"
  [[ "$junit_content" =~ grepme-junit2 ]]; equal 0 $? "equal is writing to junit: grepme-junit2 => the comment"
}


test_function_equal

>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
