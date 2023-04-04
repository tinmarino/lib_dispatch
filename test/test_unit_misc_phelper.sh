#!/usr/bin/env bash
# Unit test for function_unit_misc_phelper

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


test_function_unit_misc_phelper(){
  : 'Test function_unit_misc_phelper'
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


test_function_unit_misc_phelper || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
