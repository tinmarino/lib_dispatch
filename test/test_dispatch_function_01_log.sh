#!/usr/bin/env bash
# Unit test for dispatch very lowest level utilities
# Those used for printing errors in other utilities

# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"; gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi


  test_function_equal(){
  : "test me first as they all depend on me!"
  # -- 1: Integer success and stdout
  out=$(g_junit_file="" equal 0 0 'Test self' 2> /dev/null); equal 0 $? 'equal 0 0 => ret 0'
  equal '' "$out" 'equal no output 1'

  # -- 2 Integer failure and stdout
  out=$(g_junit_file="" equal 1 0 'Test self' 2> /dev/null); equal 1 $? 'equal 1 0 => ret 1'
  equal '' "$out" 'equal no output 2'

  # -- 3 String success and stderr
  out=$(g_junit_file="" equal '  aa b ' '  aa b '  'grepme  equal1' 2>&1); equal 0 $? 'equal same string => ret 0'
  # shellcheck disable=SC2076  # Remove quotes
  [[ "$out" =~ "[+]" ]]; equal 0 $? 'equal string OK with [plus]'
  [[ "$out" =~ "Success" ]]; equal 0 $? 'equal string OK with Success'
  [[ "$out" =~ "grepme  equal1" ]]; equal 0 $? 'equal string OK with Arg3'

  # -- 4 String failure and stderr
  out=$(g_junit_file="" equal ' aa b ' 'aa b '  'grepme  equal2' 2>&1); equal 1 $? 'equal different string => ret 0'
  # shellcheck disable=SC2076  # Remove quotes
  [[ "$out" =~ "[-]" ]]; equal 0 $? 'equal string OK with [mimus]'
  [[ "$out" =~ "Error" ]]; equal 0 $? 'equal string OK with (the bad word)'
  [[ "$out" =~ "grepme  equal2" ]]; equal 0 $? 'equal string OK with Arg3'

  # -- 5 Introspection
  out=$(g_junit_file="" equal 'grepme equal3' 'grepme equal3' 2>&1); equal 0 $? 'equal same string again => ret 0'
  [[ "$out" =~ "grepme equal3" ]]; equal 0 $? 'equal can inspect line where sent'

  # -- 6 Writing to g_junit_file
  junit=$(mktemp)
  out=$(g_junit_file="$junit" equal 'grepme-junit1' 'grepme-junit1' "grepme-junit2" 2>&1); equal 0 $? 'equal junit same string again => ret 0'
  junit_content=$(<"$junit")
  [[ "$junit_content" =~ Success ]]; equal 0 $? "equal is writing to junit: Success"
  [[ "$junit_content" =~ grepme-junit1 ]]; equal 0 $? "equal is writing to junit: grepme-junit1 => the string to match"
  [[ "$junit_content" =~ grepme-junit2 ]]; equal 0 $? "equal is writing to junit: grepme-junit2 => the comment"
}


test_function_abat(){
  : "IDEA test if bat is available"
  # -- 1: Normal
  out=$(echo -e 'this\n is an unk_string yes\nend' | abat); equal 0 $? 'abat never fails'
  [[ "$out" =~ unk_string ]]; equal 0 $? 'abat do not highlight an unknown string'

  # -- 2: No in no out
  # Comment out as not wokring if bat not installed, there are some escape sequences
  # -- out=$(echo -n | abat); equal 0 $? 'abat never fails'
  # -- [[ -z "$out" ]]; equal 0 $? 'abat no in no out'

  # -- N: no input
  # Comment out as not running in jenkins ...
  # -- out=$(timeout 1 bash -c "source \"$gs_root_path/test/lib_test.sh\"; abat 2> /dev/null"); equal "$E_REQ" $? 'abat must complain if not run in a pipe'
  # -- equal '' "$out" 'abat out of pipe should not print to stdout'
}


test_function_join_by(){
  # -- 1: No space in delimiter
  out=$(join_by , a b c); equal 0 $? 'join_by never fails 1'
  equal a,b,c "$out" 'join by out 1'

  # -- 2: Space in delimiter
  out=$(join_by ' , ' a b c); equal 0 $? 'join_by never fails 2'
  equal 'a , b , c' "$out" 'join by 2'

  # -- 3: Weird delimiter
  out=$(join_by ')|(' a b c); equal 0 $? 'join_by never fails 3'
  equal 'a)|(b)|(c' "$out" 'join by 3'

  # -- 4: Percent-like delimiter
  out=$(join_by ' %s ' a b c); equal 0 $? 'join_by never fails 4'
  equal 'a %s b %s c' "$out" 'join by 4'

  # -- 5: Newline delimiter
  out=$(join_by $'\n' a b c); equal 0 $? 'join_by never fails 5'
  equal $'a\nb\nc' "$out" 'join by 5'

  # -- 5: Newline in delimiter
  out=$(join_by $'dd\nee' a b c); equal 0 $? 'join_by never fails 5'
  equal $'add\neebdd\neec' "$out" 'join by 5'

  # -- 6: Minus delimiter
  out=$(join_by - a b c); equal 0 $? 'join_by never fails 6'
  equal 'a-b-c' "$out" 'join by 6'

  # -- 7: backslash delimiter
  out=$(join_by "\\" a b c); equal 0 $? 'join_by never fails 7'
  equal 'a\b\c' "$out" 'join by 7'

  # -- 8: Minus arguments
  out=$(join_by '-n' '-e' '-E' '-n'); equal 0 $? 'join_by never fails 8'
  equal '-e-n-E-n-n' "$out" 'join by 8'

  # -- 9: Argument missing => nothing
  out=$(join_by ,); equal 0 $? 'join_by never fails 9'
  equal '' "$(join_by ,)" 'join by 9'

  # -- 10: Only one argument
  out=$(join_by , a); equal 0 $? 'join_by never fails 10'
  equal 'a' "$(join_by , a)" 'join by 10'
}


test_function_print_stack(){
  # Helper to test stack
  fct2(){
    # Line before
    print_stack
    return $?
  }
  fct1(){
    fct2 "$@"
    return $?
  }
  # -- 1: Normal use
  out=$(fct1 a "b c" d)
  equal 0 $? "print_stack with function name"
  [[ "$out" =~ fct2.*fct1 ]]; equal 0 $? "print_stack the stack appears with desired function in desired order"
  [[ "$out" =~ lib_dispatch ]]; equal 0 $? "print_stack the stack contains 'test_dispatch_function.sh' name of the current file"

  # -- 2: With argument trace
  out=$(shopt -s extdebug; fct1 grepme-argument a "b c" d)
  [[ "$out" =~ "grepme-argument, a, b c, d" ]]; equal 0 $? "print_stack stack with argument if extdebug"
}


test_function_phelper(){
  # Pok
  out=$(pok toto titi 2>&1); equal 0 $? "pok never fails"
  [[ "$out" =~ "Succeed" ]]; equal 0 $? "pok contains Succeed"

  # Pwarn
  out=$(pwarn toto titi 2>&1); equal 0 $? "pwarn never fails"
  [[ "$out" =~ Warning ]]; equal 0 $? "pwarn contains Warning"

  # Pinfo
  out=$(pinfo toto titi 2>&1); equal 0 $? "pinfo never fails"
  [[ "$out" =~ Info ]]; equal 0 $? "pinfo contains Info"
  [[ "$out" =~ toto ]]; equal 0 $? "pinfo contains toto"
  [[ "$out" =~ titi ]]; equal 0 $? "pinfo contains titi"
  out=$(pinfo toto titi 2> /dev/null )
  equal '' "$out" "pinfo have no output to stdout"

  # Perr
  fct-for-perr(){
    # line before
    perr "You are lost?" \
      "Tip: follow me!"
  }
  out=$(fct-for-perr 72 2> /dev/null); equal 0 $? "perr never fails"
  equal '' "$out" "perr have no output to stdout"

  out=$(shopt -s extdebug; fct-for-perr 73 2>&1 1> /dev/null); equal 0 $? "perr never fails"
  [[ "$out" =~ "Error" ]]; equal 0 $? "perr contains Error"
  [[ "$out" =~ "are lost" ]]; equal 0 $? "perr contains arg1"
  [[ "$out" =~ "Tip: follow me" ]]; equal 0 $? "perr contains arg2"
  [[ "$out" =~ fct-for-perr ]]; equal 0 $? "perr contains function"
  [[ "$out" =~ "73" ]]; equal 0 $? "perr contains argument"
}


test_function_bash_timeout(){
  # Define helper function
  test_timeout(){
    # 1: max timout, 2: soft timeout
    timeout "$1" bash -c '
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


test_function_bash_sleep(){
  out=$(bash_sleep 0.001 2>&1); equal 0 $? "bash_sleep: normal return 0"
  equal "" "$out" "bash_sleep: no stdout nor stderr"

  out=$(bash_timeout 0.001 bash_sleep 0.2); equal 137 $? "bash_sleep: timedout"
  equal "" "$out" "bash_sleep and bash_timeout no stdout nor stderr"
}


test_function_bash_parallel(){
  pwarn "TODO: Not implemented bash_parallel function"
}


go(){
  local a_fct_to_test=(
    abat
    join_by
    print_stack
    phelper
    bash_timeout
    bash_sleep
    bash_parallel
  )

  # Removed parrallel "Improvement" for Buildfarm as it is not working already, see ART
  #art_parallel_suite Self/Function01

  local fct=''
  for fct in "${a_fct_to_test[@]}"; do
    start_test_function "$fct" function
    test_function_"$fct"  # Sync edit the global g_dispatch_i_res
  done

  return "$g_dispatch_i_res"
}

go || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res, at $tmp_bank"
exit "$g_dispatch_i_res"
