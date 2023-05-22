#!/usr/bin/env bash
# Unit test for function_unit_dispatch_get_file_docstring

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr is_in_array colorize_docstring


test_function_unit_dispatch_get_file_docstring(){
  : 'Test function_unit_dispatch_get_file_docstring'
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

  # --3: Without awk command which is required
  out=$(
    command -v awk &> /dev/null && hash -d awk &> /dev/null
    PATH='' get_file_docstring 2>&1
  ); equal --not 0 $? "print_usage_env function should fail if there is no awk command"
  [[ "$out" =~ Error ]]; equal 0 $? "print_usage_env function should print E.r.r.o.r if awk command is not available"
}


test_function_unit_dispatch_get_file_docstring


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
