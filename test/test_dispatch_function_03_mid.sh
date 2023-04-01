#!/usr/bin/env bash
# Unit test for dispatch function level 3

# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"
    gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi


start_test_function run function
  fct(){
    echo Grepme-fct
    return 3
  }
  fct_proxy(){
    fct "$@"
    return $?
  }
  return_42(){ return 42; }
  return_0(){ return 0; }
  run return_0 &> /dev/null; equal 0 $? "Run proxy status 0"
  run return_42 &> /dev/null; equal 42 $?  "Run proxy status 42"
  all_out=$(g_dispatch_b_print=1 g_dispatch_b_run=1; run fct_proxy a "b c" d1); equal 3 $? "Run fct status"
  all_err=$(g_dispatch_b_print=1 g_dispatch_b_run=1; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 3 $? "Run fct status"
  no_out=$(g_dispatch_b_print=1 g_dispatch_b_run=0; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 0 $? "Run fct status without run"
  # shellcheck disable=SC2034  # g_dispatch_b_print appears unused
  no_err=$(g_dispatch_b_print=0 g_dispatch_b_run=1; run fct_proxy a "b c" d 2>&1 1> /dev/null); equal 3 $? "Run fct status without print"

  [[ "$all_out" =~ Grepme-fct ]]; equal 0 $? "Run stdout"
  [[ ! "$no_out" =~ Grepme-fct ]]; equal 0 $? "Run stdout not"
  [[ "$all_err" =~ fct_proxy ]]; equal 0 $? "Run stderr"
  [[ ! "$no_err" =~ fct_proxy ]]; equal 0 $? "Run stderr not"


start_test_function file_to_dic function
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


start_test_function print_script_start function
  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_start 2>&1 > /dev/null); equal 0 $? 'print_script_start always status 0'
  [[ -n "$out" ]]; equal 0 $? 'print_script_start gets something in stderr'

  # Stdout gets nothing
  declare -g g_dispatch_b_print=1
  out=$(print_script_start a b ccc 2> /dev/null); equal 0 $? 'print_script_start always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_start gets nothing in stdout'

  # Nothing if silenced
  declare -g g_dispatch_b_print=0
  out=$(echo | print_script_start 2>&1); equal 0 $? 'print_script_start always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_start gets nothing if silenced'

  # Just for lint
  : "$g_dispatch_b_print"


start_test_function print_script_end function
  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_end 2>&1 > /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ -n "$out" ]]; equal 0 $? 'print_script_start gets something in stderr'

  # Stdout gets nothing
  declare -g g_dispatch_b_print=1
  out=$(print_script_end a b ccc 2> /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_end gets nothing in stdout'

  # Nothing if silenced
  declare -g g_dispatch_b_print=0
  out=$(echo | print_script_end 2>&1); equal 0 $? 'print_script_end always status 0'
  [[ -z "$out" ]]; equal 0 $? 'print_script_end gets nothing if silenced'

  # Stderr get something
  declare -g g_dispatch_b_print=1
  out=$(print_script_end 0 grepme_print_script_end1 "grepme  print_script_end  with space" 2>&1 > /dev/null); equal 0 $? 'print_script_end always status 0'
  [[ "$out" =~ grepme_print_script_end ]]; equal 0 $? 'print_script_start gets arg1 in stderr'
  [[ "$out" =~ "grepme  print_script_end  with space" ]]; equal 0 $? 'print_script_start gets arg2 in stderr'

  # After 0 second
  declare -g g_dispatch_b_print=1
  out=$({ print_script_start; print_script_end; } 2>&1 > /dev/null | grep -o 'After:.*$')
  equal 0 $? 'print_script_end always status 0'
  equal 'After: 0h:0m:0s' "$out" "print_script_end after 0 seconds"

  # Commented out as I do not like to sleep
  # # After 1 second
  # out=$({ print_script_start; sleep 1.1;  print_script_end; } 2>&1 > /dev/null | grep -o 'After:.*$')
  # equal 0 $? 'print_script_end always status 0'
  # equal 'After: 0h:0m:1s' "$out" 'print_script_end after 1 second'


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
