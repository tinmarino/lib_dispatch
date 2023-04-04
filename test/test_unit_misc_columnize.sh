#!/usr/bin/env bash
# Unit test for function_unit_misc_columnize

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend perr get_opt


test_function_unit_misc_columnize(){
  : 'Test function_unit_misc_columnize'
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
}


test_function_unit_misc_columnize


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
