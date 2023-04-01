#!/usr/bin/env bash
# Unit test for dispatch function level 4


# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"
    gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi


start_test_function get_os_name function
  equal 0 0 'ToUpdate: commented out as bad dictionary for RH7'
  #uname=$(uname -a)
  #os_name=$(get_os_name); equal 0 $? "get_os_name succeed (and returned: $os_name)"
  #shopt_nocasematch=$(shopt -p nocasematch)
  #shopt -s nocasematch
  #case $uname in
  #  *el8*)
  #    [[ "$os_name" =~ 8 ]]; equal 0 $? 'get_os_name with a 8 inside <= el8'
  #    ;;
  #  *el7*)
  #    [[ "$os_name" =~ 7 ]]; equal 0 $? 'get_os_name with a 7 inside <= el7'
  #    ;;
  #  *ubuntu*)
  #    [[ "$os_name" =~ ubuntu ]]; equal 0 $? 'get_os_name with ubuntu inside <= ubuntu'
  #    ;;
  #esac
  #$shopt_nocasematch


start_test_function get_fct_docstring function
  # No argument
  out=$(get_fct_docstring 2> /dev/null); equal "$E_REQ" $? 'get_fct_docstring REQUIRES an argument'
  equal '' "$out" 'get_fct_docstring silence stdout even if fail'

  # Bad argument
  unset toto &> /dev/null
  out=$(get_fct_docstring toto 2> /dev/null); equal "$E_REQ" $? 'get_fct_docstring REQUIRES an argument which is a defined function'
  equal '' "$out" 'get_fct_docstring silence stdout even if fail (bis)'

  # No docstring one line function, the one in Tip
  toto(){ :; }
  out=$(get_fct_docstring toto); equal 0 $? 'get_fct_docstring succeed one line'
  equal '' "$out" 'get_fct_docstring no doc no out'

  # One line
  toto(){
    : 'grepme  one line'
  }
  out=$(get_fct_docstring toto); equal 0 $? 'get_fct_docstring succeed one line'
  equal "grepme  one line" "$out" 'get_fct_docstring output ok one line'

  # Multiple line
  toto(){
    : 'grepme  with
      Multiple
        indented
      lines
    '
    echo "do not grepme toto"
  }
  out=$(get_fct_docstring toto); equal 0 $? 'get_fct_docstring succeed one line'
  equal $'grepme  with\nMultiple\n  indented\nlines' "$out" 'get_fct_docstring output ok one line'

  # Double quotes
  toto(){
    : "grepme  double  quotes
      just  two  lines
    "
    echo "do not grepme toto"
  }
  out=$(get_fct_docstring toto); equal 0 $? 'get_fct_docstring succeed double quotes'
  equal $'grepme  double  quotes\njust  two  lines' "$out" 'get_fct_docstring output ok with double quotes'


start_test_function get_file_docstring function

  # --1: Without argument
  out=$(get_file_docstring 2> /dev/null); equal "$E_REQ" $? 'get_file_docstring requires one argument'
  equal '' "$out" 'get_file_docstring silent stdout if fail'

  # --2: With bad argument
  out=$(get_file_docstring bad/file/path 2> /dev/null); equal "$E_REQ" $? 'get_file_docstring requires an existing file'
  equal '' "$out" 'get_file_docstring silent stdout if fail (bis)'

  # --3: Normal flow 1
  out=$(get_file_docstring <(print_unindent '#!/usr/bin/env bash
    # Grepme  first  line
    # Grepme  second  line
    #
    # Grepme last line
    echo toto
  '))
  equal 0 $? 'get_file_docstring success (3)'
  equal 'Grepme  first  line' "$out" "get_file_docstring output short"

  # --4: Normal flow 4
  out=$(get_file_docstring <(print_unindent '#!/usr/bin/env bash
    # Grepme  first  line
    # Grepme  second  line
    #
    # Grepme last line
    echo toto
  ') long)
  equal 0 $? 'get_file_docstring success (4)'
  equal $'Grepme  first  line\nGrepme  second  line\n\nGrepme last line' "$out" "get_file_docstring output short"


start_test_function print_usage_env function
  # --1: No __set_env no problem
  unset __set_env &> /dev/null
  out=$(print_usage_env 2>&1); equal 0 $? 'print_usage_env always succeed (1)'
  equal '' "$out" 'print_usage_env silent even if no __set_env'

  # --2: __set_env with traps
  __set_env(){
    : 'Internal helper to set environment variables'
    set -a
    # Required
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


start_test_function print_usage_fct function
  # --1: No function dict, no work
  unset g_dispatch_d_fct &> /dev/null
  out=$(print_usage_fct 2> /dev/null); equal "$E_REQ" $? "print_usage_fct status 1: without g_dispatch_d_fct"
  equal '' "$out" "print_usage_fct no in no out"

  # --2: void function dict
  declare -gA g_dispatch_d_fct=(); : "${g_dispatch_d_fct[*]}"
  out=$(print_usage_fct --doc function); equal 0 $? "print_usage_fct status2: without g_dispatch_d_fct"
  equal '' "$out" "print_usage_fct no in no out bis"

  declare -gA g_dispatch_d_fct=(
    [fct1]='description  function 1'
    [fct2]=$'description  function 2\ntwo lines'
  )

  # --3: void arguments (no functions asked)
  out=$(print_usage_fct --doc function); equal 0 $? "print_usage_fct status 3"
  equal '' "$out" "print_usage_fct no in no out ter"

  # --4: Ask fct1
  out=$(print_usage_fct --doc function fct1); equal 0 $? "print_usage_fct status 4"
  [[ "$out" =~ 'fct1' ]]; equal 0 $? "print_usage_fct fct1 name"
  [[ "$out" =~ 'description  function 1' ]]; equal 0 $? "print_usage_fct fct1 desc"

  # --5: Ask fct2
  out=$(print_usage_fct --doc function fct2); equal 0 $? "print_usage_fct status 5"
  [[ "$out" =~ 'fct2' ]]; equal 0 $? "print_usage_fct fct2 name"
  [[ "$out" =~ $'description  function 2\ntwo lines' ]]; equal 0 $? "print_usage_fct fct2 desc"

  # --5: Ask fct1 fct2
  out=$(print_usage_fct --doc function fct1 fct2); equal 0 $? "print_usage_fct status 6"
  [[ "$out" =~ fct1.*description[[:space:]][[:space:]]function[[:space:]]1.*fct2.*description[[:space:]][[:space:]]function[[:space:]]2.*two[[:space:]]lines ]]; equal 0 $? 'print_usage_fct fct1 fct2'

  # --6: Ask fct2 fct1
  out=$(print_usage_fct --doc function fct2 fct1); equal 0 $? "print_usage_fct status 6"
  [[ "$out" =~ fct2.*description[[:space:]][[:space:]]function[[:space:]]2.*two[[:space:]]lines.*fct1.*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct fct2 fct1'

  declare -gA g_dispatch_d_fct=(
    [fct1]='description  function 1'
    [fct2]=$'description  function 2\ntwo lines'
    [mm_opt1]=$'description  option 1'
    [mm_opt2]=$'description  option 2\ntwo lines'
  )

  # --7 Option not appearing if not asked
  out1=$(print_usage_fct --doc function fct2 fct1 mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 7"
  out2=$(print_usage_fct --doc function fct2 fct1); equal 0 $? "print_usage_fct status 7 bis"
  equal "$out1" "$out2" "print_usage_fct same output without options"

  # --8 Function not appearing if not asked
  out1=$(print_usage_fct --doc option fct2 fct1 mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 8"
  out2=$(print_usage_fct --doc option mm_opt1 mm_opt2); equal 0 $? "print_usage_fct status 8 bis"
  out=$out2
  equal "$out1" "$out2" "print_usage_fct same output without options"
  [[ "$out" =~ --opt1.*description[[:space:]][[:space:]]option[[:space:]]1.*--opt2.*description[[:space:]][[:space:]]option[[:space:]]2.*two[[:space:]]lines ]];  equal 0 $? 'print_usage_fct mm_opt1 mm_opt2'

  # --9 complete
  out=$(print_usage_fct --complete function fct1 fct2); equal 0 $? "print_usage_fct status 9 bis"
  [[ "$out" =~ fct1[[:space:]]*:[[:space:]]*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct --complete fct1'
  [[ "$out" =~ fct2[[:space:]]*:[[:space:]]*description[[:space:]][[:space:]]function[[:space:]]2 ]]; equal 0 $? 'print_usage_fct --complete fct2'
  [[ ! "$out" =~ "two lines" ]]; equal 0 $? 'print_usage_fct --complete fct2 value not second line'

  # --9 help
  out=$(print_usage_fct --help function fct1 fct2); equal 0 $? "print_usage_fct status 9 bis"
  [[ "$out" =~ fct1.*description[[:space:]][[:space:]]function[[:space:]]1 ]]; equal 0 $? 'print_usage_fct --complete fct1'
  [[ "$out" =~ fct2.*description[[:space:]][[:space:]]function[[:space:]]2 ]]; equal 0 $? 'print_usage_fct --complete fct2'
  [[ ! "$out" =~ "two lines" ]]; equal 0 $? 'print_usage_fct --complete fct2 value not second line'


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
