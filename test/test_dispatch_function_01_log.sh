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

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

depend ""


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
