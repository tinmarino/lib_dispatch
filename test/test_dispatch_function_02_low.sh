#!/usr/bin/env bash
# Unit test for dispatch low level function (only depending on log and equal)

# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"
    gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi

go(){
  local a_fct_to_test=(
    get_all_opt_alias
    fcp
    vcp
    trim
    ask_confirmation
    user_at_host
    get_opt
    wait_pid_array
    pipe_10
    pipe_one_line
    escape_array
    read_file_as_array
    substract_array
    is_in_array
    print_args
    print_unindent
    columnize
  )

  # Removed parrallel "Improvement" for Buildfarm as it is not working already, see ART
  #art_parallel_suite Self/Function02 "${a_fct_to_test[@]}"

  local fct=''
  for fct in "${a_fct_to_test[@]}"; do
    start_test_function "$fct" function
    test_function_"$fct"  # Sync edit the global g_dispatch_i_res
  done

  return "$g_dispatch_i_res"
}

test_function_get_all_opt_alias(){
  g_dispatch_i_res=0

  set -- "var with space" --param1 "param 1" --param2 "param 2" end
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails"
  equal "param 1" "$param1" "get_all_opt_alias param1 set"
  equal "param 2" "$param2" "get_all_opt_alias param2 set"
  
  # No arg
  set --
  get_all_opt_alias

  # No param
  set -- --param1
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails"
  equal "param 1" "$param1" "get_all_opt_alias param1 not reseted"

  # Empty param
  set -- --param1 ''
  get_all_opt_alias
  equal 0 $? "get_all_opt_alias never fails"
  equal "" "$param1" "get_all_opt_alias param1 reseted"

  return "$g_dispatch_i_res"
}


test_function_fcp(){
  g_dispatch_i_res=0

  toto(){ echo grepme-toto; }

  out=$(fcp toto titi 2>&1); equal 0 $? 'fcp succeed'
  equal '' "$out" 'fcp silent'

  fcp toto titi
  out=$(titi); equal 0 $? "fcp function called"
  [[ "$out" == grepme-toto ]]; equal 0 $? "fcp good function copied"

  unset toto
  out=$(fcp toto titi 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp first argument must be defined'
  equal '' "$out" 'fcp stdout silent 1'

  out=$(fcp toto 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 2'
  equal '' "$out" 'fcp stdout silent 2'

  out=$(fcp 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 3'
  equal '' "$out" 'fcp stdout silent 3'

  out=$(fcp toto titi tata tutu "" 2> /dev/null);
  # shellcheck disable=SC2181  # Check exit code directly
  (( 0 != $? )); equal 0 $? 'fcp bad 4'
  equal '' "$out" 'fcp stdout silent 4'

  return "$g_dispatch_i_res"
}


test_function_vcp(){
  g_dispatch_i_res=0

  # Declarations
  var="  345  89  "; : "$var"
  declare -a ind_array=(Betty "  345  89  ")
  declare -A asso_array=([one]=Harry [two]=Betty [some_signs]=" +*.<\$~,'/ ")

  # produce the copy
  vcp var var_2; equal 0 $? "vcp never fails"
  [[ "$var_2" == "  345  89  " ]]; equal 0 $? "vcp string"

  vcp ind_array ind_array_2; equal 0 $? "vcp never fails"
  [[ "$(declare -p ind_array_2 2> /dev/null)" =~ -a ]]; equal 0 $? "vcp array"
  [[ "${ind_array[0]}" == Betty ]]; equal 0 $? "vcp array content"

  vcp asso_array asso_array_2; equal 0 $? 'vcp never fails'
  [[ "$(declare -p asso_array_2 2> /dev/null)" =~ -A ]]; equal 0 $? "vcp dic"
  [[ "${asso_array[two]}" == Betty ]]; equal 0 $? "vcp dic content"

  return "$g_dispatch_i_res"
}


test_function_trim(){
  g_dispatch_i_res=0

  equal "" "$(trim "")" "trim nothing"
  equal "" "$(trim "     ")" "trim pure space"
  equal "a b" "$(trim "  a b ")" "trim both side"
  equal "a b  c d" "$(trim "  a b  c d")" "trim left"
  equal "a bbb  d" "$(trim "a bbb  d    ")" "trim right"
  equal "a b  c d" "$(trim "a b  c d")" "trim no trim"
  equal 'aa bb' "$(trim $'	 \n   	 		\n aa bb \n 	')" "trim mixed with tab and newlines"
  equal $'aa  	 \n 	 bb' "$(trim $'	 \n   	 		\n aa  	 \n 	 bb \n 	')" "trim mixed with tab and newlines, even inside"

  return "$g_dispatch_i_res"
}


test_function_ask_confirmation(){
  g_dispatch_i_res=0

  out=$(echo y | ask_confirmation 'msg' 2> /dev/null); res=$?
  equal "" "$out" 'ask_confirmation should not print on stdout'
  equal 0 "$res" "ask_confirmation OK"

  out=$(echo n | ask_confirmation 'msg' 2> /dev/null); equal 1 $? "ask_confirmation NO"

  err=$(echo n | ask_confirmation 'msg' 2>&1); equal 1 $? "ask_confirmation NO"
  [[ "$err" =~ NO ]]; equal 0 $? "ask_confirmation if say no, NO should be visible"
  err=$(echo y | ask_confirmation 'msg' 2>&1); [[ "$err" =~ OK ]]; equal 0 $? "ask_confirmation if say yes, OK should be visible"

  return "$g_dispatch_i_res"
}


test_function_user_at_host(){
  g_dispatch_i_res=0

  out=$(USER=user HOSTNAME=hostname user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'user@hostname' "$out" 'user_at_host 2 var'

  out=$(unset USER; HOSTNAME=hostname user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'hostname' "$out" 'user_at_host 1 var: host'

  out=$(unset HOSTNAME; USER=user user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'user@localhost' "$out" 'user_at_host 1 var: user'

  out=$(unset HOSTNAME; unset USER; user_at_host); equal 0 $? 'user_at_host never fails'
  equal 'localhost' "$out" 'user_at_host 0 var'

  return "$g_dispatch_i_res"
}


test_function_get_opt(){
  g_dispatch_i_res=0

  equal "arg1 arg2" "$(get_opt --param --param arg1 arg2)" 'get_opt with only good parameter'
  equal "arg1 arg2" "$(get_opt --param --date 30 --param arg1 arg2)" 'get_opt prefixed with other parameter'
  equal "arg1 arg2" "$(get_opt --param positional --param arg1 arg2 --date 30)" 'get_opt with redundant parameter'
  equal "" "$(get_opt --param)" 'get_opt no aditional parameter, no output'
  out=$(get_opt 2> /dev/null); equal "$E_REQ" $? 'get_opt with zero parameter should fail'
  equal "" "$(get_opt 2> /dev/null)" 'get_opt with zero parameter should have no stdout'

  return "$g_dispatch_i_res"
}


test_function_wait_pid_array(){
  g_dispatch_i_res=0

  a_pid=(); : "${a_pid[*]}"

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

  return "$g_dispatch_i_res"
}


test_function_pipe_10(){
  g_dispatch_i_res=0

  # Helper for pipe
  p_pipe(){ for ((i=1; i<= ${1:-1000}; i++)); do echo "$i"; done; }
  p_join(){ join_by $'\n' "$@"; }

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10 100 200 300 400 500 600 700 800 900 1000 991 992 993 994 995 996 997 998 999 1000)
  equal "$ref" "$(p_pipe | pipe_10)" "Pipe_10 1000 lines"
  equal "$ref" "$(p_pipe | dispatch dispatch pipe_10)" "Pipe_10 same, calling with dispatch"

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10)
  equal "$ref" "$(p_pipe 10 | pipe_10)" "Pipe_10 10 lines"

  ref=$(p_join 1 2 3 4 5 6 7 8 9 10 21 22 23 24 25 26 27 28 29 30)
  equal "$ref" "$(p_pipe 30 | pipe_10)" "Pipe_10 30 lines"

  return "$g_dispatch_i_res"
}


test_function_pipe_one_line(){
  g_dispatch_i_res=0

  out=$(echo -n 'grepme-one-line' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 1"
  [[ "$out" =~ grepme-one-line ]]; equal 0 $? "pipe_one_line one line no return"

  out=$(echo 'grepme-one-line' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 1"
  [[ "$out" =~ grepme-one-line ]]; equal 0 $? "pipe_one_line one line with newline in end"

  out=$(echo -e 'a\nb c\nd' | pipe_one_line ); equal 0 $? "pipe_one_line never fails 2"
  [[ "$out" =~ d ]]; equal 0 $? "pipe_one_line outputs last line"

  return "$g_dispatch_i_res"
}


test_function_escape_array(){
  g_dispatch_i_res=0

  equal "'a' ; 'b'" "$(escape_array a \; b)" "escape_array ;"
  equal "'a' | 'b'" "$(escape_array a \| b)" "escape_array |"
  equal "'a' |& 'b'" "$(escape_array a \|\& b)" "escape_array |&"
  equal "'a' > 'b'" "$(escape_array a \> b)" "escape_array >"
  equal "'a' >> 'b'" "$(escape_array a \>\> b)" "escape_array >>"
  equal "'a' 2> 'b'" "$(escape_array a 2\> b)" "escape_array 2>"
  equal "'a' && 'b'" "$(escape_array a \&\& b)" "escape_array &&"
  equal "'a' || 'b'" "$(escape_array a \|\| b)" "escape_array ||"
  equal "'a' 2>&1 'b'" "$(escape_array a 2\>\&1 b)" "escape_array 2>&1"
  equal "'find' \\;" "$(escape_array find \\\;)" "escape_array \\;"
  equal "'cmd1' | 'cmd2' 'a b' 2> '/dev/null'" "$(escape_array cmd1 \| cmd2 "a b" 2\> /dev/null)" "escape_array large example"
  equal "'bla-bla_bla' 'blabla'" "$(escape_array bla-bla_bla blabla)" "escape_array bla-bla"
  equal $'\'aa\' \'bb\ncc\'' "$(escape_array aa $'bb\ncc')" "escape_array with newline in one parameter"
  out=$(escape_array equal 0 0 "In an escaped command" 2\> /dev/null); equal 0 $? 'escape_array should not fail here, with equal'

  return "$g_dispatch_i_res"
}


test_function_read_file_as_array(){
  g_dispatch_i_res=0

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

  return "$g_dispatch_i_res"

  return "$g_dispatch_i_res"
}


test_function_substract_array(){
  g_dispatch_i_res=0

  readarray -t a_out < <(substract_array);
  equal "" "${a_out[*]}" 'substract_array no argument'
  readarray -t a_out < <(substract_array -- 1)
  equal "" "${a_out[*]}" 'substract_array -- 1'
  readarray -t a_out < <(substract_array 1 "2 3" 4 -- "2 3" 4 1)
  equal "" "${a_out[*]}" 'substract_array remove them all'
  readarray -t a_out < <(substract_array 1 "2 3" 4 -- "2 3" 4 1 1 4)
  equal "" "${a_out[*]}" 'substract_array remove them all and more'
  readarray -t a_out < <(substract_array 1)
  equal "1" "${a_out[*]}" 'substract_array 1'
  readarray -t a_out < <(substract_array 1 "2 3" 4 5 -- "2 3")
  [[ "${a_out[*]}" =~ 1 ]]; equal 0 $? 'substract_array stupid 1'
  [[ "${a_out[*]}" =~ 2 ]]; equal 1 $? 'substract_array stupid 2'
  [[ "${a_out[*]}" =~ 3 ]]; equal 1 $? 'substract_array stupid 3'
  [[ "${a_out[*]}" =~ 4 ]]; equal 0 $? 'substract_array stupid 4'
  [[ "${a_out[*]}" =~ 5 ]]; equal 0 $? 'substract_array stupid 5'

  return "$g_dispatch_i_res"
}


test_function_is_in_array(){
  g_dispatch_i_res=0

  array=("something to search for" "a string" "test2000")
  out=$(is_in_array 2>&1); equal 1 $? 'is_in_array no argument => 1'
  equal '' "$out" "is_in_array no output 1"
  out=$(is_in_array arg1 2>&1); equal 1 $? 'is_in_array one argument => 1'
  equal '' "$out" "is_in_array no output 2"
  out=$(is_in_array "a string" "${array[@]}" 2>&1); equal 0 $? 'is_in_array found 1'
  equal '' "$out" "is_in_array no output 3"
  is_in_array "a" "${array[@]}"; equal 1 $? 'is_in_array not found a'
  is_in_array "a strin" "${array[@]}"; equal 1 $? 'is_in_array not found substring'
  out=$(is_in_array "a stringg" "${array[@]}" 2>&1); equal 1 $? 'is_in_array not foudn superstring'
  equal '' "$out" "is_in_array no output 4"

  return "$g_dispatch_i_res"
}


test_function_print_args(){
  g_dispatch_i_res=0

  out=$(print_args); equal 0 $? "print_args always succeed"
  equal '' "$out" "print_args no arg no out"
  out=$(print_args 1 2); equal 0 $? "print_args always succeed"
  equal $'1/ 1\n2/ 2' "$out" "print_args 1 2"
  out=$(print_args 1 2 "3 titi" toto); equal 0 $? "print_args always succeed"
  equal $'1/ 1\n2/ 2\n3/ 3 titi\n4/ toto' "$out" "print_args big"

  return "$g_dispatch_i_res"
}


test_function_print_unindent(){
  g_dispatch_i_res=0

  ref=$'toto\n    titi\n  tata'

  out=$(echo -e $'  toto\n      titi\n    tata\n' | print_unindent); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent 2 spaces in pipe"

  out=$(print_unindent "$(echo -e '  toto\n      titi\n    tata\n')"); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent 2 spaces args"

  out=$(print_unindent "$ref"); equal 0 $? 'print_unindent never fails'
  equal "$ref" "$out" "Unindent do not modify not indented strings => idempotent"

  out=$(echo -e '  toto\n    titi\n  tata\nend' | print_unindent); equal 0 $? 'print_unindent never fails'
  [[ "$out" =~ end ]]; equal 0 $? "print_unindent print full line even it not indented"

  return "$g_dispatch_i_res"
}


test_function_columnize(){
  g_dispatch_i_res=0

  # Nothing
  out=$(echo | columnize)
  equal "" "$out" "columnize: Nothing in, nothing out"

  # One column
  out=$(echo -e "
      L1
      L2
        L3
    " | columnize
  )
  desired=$(print_unindent "
    L1
    L2
    L3"
  )
  equal "$desired" "$out" "columnize: One column"

  # Basic
  out=$(
    echo -e "
      L1 | 123
      L2 |   123
      L3   | 123
         L4   |   123
      L5   1234567890 1234567890 12345 | 123
    " | columnize
  )
  desired=$(print_unindent "
    L1                   | 123
    L2                   | 123
    L3                   | 123
    L4                   | 123
    L5   1234567890 1234567890 12345 | 123"
  )
  [[ "$desired" == "$out" ]]; equal 0 $? "columnize: Basic 2 columns"

  # A little hard
  out=$(
    echo -e "
      L1 | 123 | 123 | 123 | 123
      L2 1234567890 12345 | 123  | 123 | 123 | 123
      L3 1234567890 12345 | 1234567890 12345 | 123 | 123 | 123
      L4 1234567890 | 1234567890 12345 | 1234567890 12345 | 123 | 123
      L5 1234567890 | 123 | 123 | 123 | 1234567890 1234567890
      L5 | 123 | 123 | 123 | 123
    " | columnize --col 15,15,15,15
  )
  desired=$(
    print_unindent "
      L1              | 123             | 123             | 123             | 123
      L2 1234567890 12345 | 123         | 123             | 123             | 123
      L3 1234567890 12345 | 1234567890 12345 | 123        | 123             | 123
      L4 1234567890   | 1234567890 12345 | 1234567890 12345 | 123           | 123
      L5 1234567890   | 123             | 123             | 123             | 1234567890 1234567890
      L5              | 123             | 123             | 123             | 123"
  )
  [[ "$desired" == "$out" ]]; equal 0 $? "columnize: Five columns hard"

  return "$g_dispatch_i_res"
}



go || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
