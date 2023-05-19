#!/usr/bin/env bash
# Test dipatch autocompletion feature

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"


start_test_function "Completion"
  print_subresult(){
    # Check if completion is the first one
    local res="$(
      # Note: Redirecto to blackhole to avoid: bash: initialize_job_control: no job control in background: Bad file descriptor
      bash --norc -c "complete -C dispatch dispatch; $*" 2> /dev/null
    )"
    echo "$res"
  }
  print_complete(){
    print_subresult "COMP_TYPE=1 COMP_POINT=99 COMP_LINE='${*:2}' ${*:2}"
  }
  cmd="complete -p dispatch"
  expect="complete -C 'dispatch' dispatch"
  equal "$expect" "$(print_subresult "$cmd")" "Completion must be in current shell: if not ok, please put the same command in your bashrc: $expect"


start_test_function "Completion dispatch ex"
  equal example "$(print_complete 99 "dispatch exampl")" "Completion: dispatch example -> unique answer"
  equal --help "$(print_complete 99 "dispatch --hel")" "Completion: dispatch --hel -> unique answer"
  equal example "$(print_complete 99 "dispatch --help exampl")" "Completion: dispatch --help example -> unique answer"


start_test_function "Completion dispatch example"
  out=$(print_complete 99 "dispatch example \"\"")
  readarray -t a_example_complete_key < <(grep -o '^-*[a-z_]\+' <<< "$out")
  is_in_array --complete "${a_example_complete_key[@]}"; equal 0 $? "complete: dispatch example with --complete (keys=${a_example_complete_key[*]})"
  is_in_array --help "${a_example_complete_key[@]}"; equal 0 $? "complete dispatch example with --help"
  is_in_array example "${a_example_complete_key[@]}"; equal 1 $? "dispatch example --help without example"
  is_in_array shell "${a_example_complete_key[@]}"; equal 1 $? "dispatch example --help without shell"


start_test_function "Completion dispatch example succeed"
  out=$(print_complete 99 "dispatch example succeed \"\"")
  readarray -t a_example_succeed_complete_key < <(grep -o '^-*[a-z_]\+' <<< "$out")
  is_in_array example_one "${a_example_succeed_complete_key[@]}"; equal 0 $? "complete: dispatch example succeed custom completion (keys=${a_example_complete_key[*]})"
  is_in_array succeed "${a_example_succeed_complete_key[@]}"; equal 1 $? "complete: dispatch example succeed should not display succeed which is a subcommand (keys=${a_example_complete_key[*]})"
  is_in_array --complete "${a_example_succeed_complete_key[@]}"; equal 1 $? "complete: dispatch example succeed should not display --complete which is lib_dispatch related and not example succeed related (keys=${a_example_complete_key[*]})"


start_test_function "Completion dispatch --complete directly"
  out=$(dispatch --complete); [[ -n "$out" ]]; equal 0 $? "Completion: dispatch --complete not null"
  equal "" "$(grep -v '^[^ ]* *:' <<< "$out")" "Completion all separated with ':'"
  out=$(dispatch example --complete); [[ -n "$out" ]]; equal 0 $? "Completion2: dispatch --complete not null"
  equal "" "$(grep -v '^[^ ]* *:' <<< "$out")" "Completion2: all separated with ':'"


start_test_function "Completion Option"
  out=$(command dispatch --complete example --value "");
  [[ -n "$out" ]]; equal 0 $? "val1: dispatch --complete example --value not null"
  [[ "$out" =~ first_value ]]; equal 0 $? 'val1: first value'
  [[ "$out" =~ second_value ]]; equal 0 $? 'val1: second value'
  [[ "$out" =~ succeed ]]; equal 1 $? 'val1: succeed function abscent'
  # TODO test filtering with something more real like:
  # -- dispatch --complete example --value fir

  out=$(command dispatch --complete example --value toto "");
  [[ -n "$out" ]]; equal 0 $? "val2: not null"
  [[ "$out" =~ succeed ]]; equal 0 $? 'val0: succeed function present'
  [[ "$out" =~ first_value ]]; equal 1 $? 'val0: first value abscent'


start_test_function "Completion Option Trail"
  print_complete_fake(){
    print_subresult "COMP_TYPE=1 COMP_POINT=$1 COMP_LINE='dispatch ${*:2}' dispatch --complete ${*:2}"
  }

  # 0123456789012345678901234567890123456789
  # dispatch example --value fi example  # Cursor at 27, after 'fi'
  equal first_value "$(print_complete_fake 27 "example --value fi succeed")" "Completion trail1"


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
