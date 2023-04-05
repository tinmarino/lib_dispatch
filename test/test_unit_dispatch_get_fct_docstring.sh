#!/usr/bin/env bash
# Unit test for function_unit_dispatch_get_fct_docstring

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


test_function_unit_dispatch_get_fct_docstring(){
  : 'Test function_unit_dispatch_get_fct_docstring'
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
}


test_function_unit_dispatch_get_fct_docstring


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
