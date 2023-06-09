#!/usr/bin/env bash

# shellcheck disable=SC2059  # Don't use variables in the printf format string

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Declate the report fd
# g: global, i: integer, x: export
declare -gix gi_summary_write_fd=0
declare -gix g_dispatch_i_res=0

# Silence shellcheck
: "${cgreen:=}" "${cred:=}" "${cend:=}"

main(){
  : 'Check dispatch project
    # Ref: Use GLOBIGNORE: https://unix.stackexchange.com/a/246103/257838
  '
  # TODO warn if remote
  if [[ osx != $(get_os) ]]; then
    # In millisecond
    local -i start_time=$(date +%s%N)
  else
    local -i start_time=$(date +%s)
  fi
  local -i res=0 ret=0 i_fd=0 b_async=0 #i_fd_summary=0
  local -A d_pid=()  # Array of pid
  local -A d_test_file=()  # Array of test file name to execute
  local -A d_fd=()  # Array of fd corresponding to the stdout of this file to lock
  local -A d_status=()  # Array exit status
  #local -a a_fd_summary=()  # Array of child summary to return (list of errors)
  local -a a_test_file=()  # Array of test file name to execute
  local -a a_key_sorted=()  # For better output
  local test_file='' key=''

  # Clause: test files must be present
  # See: https://stackoverflow.com/a/34195247/2544873
  compgen -G "$gs_root_path"/test/test_*sh &> /dev/null || {
    perr "Check self: Cannot test self <= test files are not present" \
         "Tip: try to run locally <= test files seems to not have been copied"
    return "$E_REQ"
  }

  is_in_array async "$@" && b_async=1

  # Save env
  local globignore_save=$GLOBIGNORE

  # Get files to test
  if [[ -z "$*" ]] || [[ async == "$*" ]]; then
    local glob=''
    # A/ Dispatch
    GLOBIGNORE="$gs_root_path/test/test_fail.sh:"

    # 0/ Equal function
    glob="$gs_root_path/test/test_unit_misc_equal.sh"
    # shellcheck disable=SC2206  # Quote to prevent word splitting/globbing
    # -- Okay as it is a glob pattern
    a_test_file+=($glob)
    GLOBIGNORE+="$glob:"

    # 0/ Run Test script
    glob="$gs_root_path/test/test_run_test.sh"
    # shellcheck disable=SC2206  # Quote to prevent word splitting/globbing
    # -- Okay as it is a glob pattern
    a_test_file+=($glob)
    GLOBIGNORE+="$glob:"

    # 1/ Dispatch unit tests
    glob="$gs_root_path/test/test_unit_dispatch*.sh"
    # shellcheck disable=SC2206  # Quote to prevent word splitting/globbing
    a_test_file+=($glob)
    GLOBIGNORE+="$glob:"

    # 2/ All unit tests
    glob="$gs_root_path/test/test_unit_*.sh"
    # shellcheck disable=SC2206  # Quote to prevent word splitting/globbing
    a_test_file+=($glob)
    GLOBIGNORE+="$glob:"

    # C/ Subcommands but not dispatch
    a_test_file+=("$gs_root_path"/test/test*.sh)
  else
    local test_file=''
    for test_file; do
      # Prepend absolute path of test
      # local a_test_file=("${@/#/$gs_root_path/test/}")
      [[ "$test_file" != test_* ]] && test_file="test_$test_file"
      [[ "$test_file" != *.sh ]] && test_file="$test_file.sh"
      # Voluntarily expand globs
      # shellcheck disable=SC2206  # Quote to prevent word splitting/globbing or use readarray
      local -a a_tmp_test_file=("$gs_root_path"/test/$test_file)
      a_test_file+=("${a_tmp_test_file[@]}")
    done
  fi

  # Restore env
  export GLOBIGNORE=$globignore_save

  # Create keys
  for test_file in "${a_test_file[@]}"; do
    key=${test_file#"$gs_root_path"}
    key=${key#/}
    key=${key#test/}
    key=${key#test_}
    key=${key%.sh}
    d_test_file[$key]=$test_file
  done

  # Sort keys
  local -a a_key01=() a_key02=() a_key1=() a_key2=() a_key3=() a_key9=()
  for key in "${!d_test_file[@]}"; do
    [[ "$key" == unit_misc_equal ]] && { a_key01+=("$key"); continue; }
    [[ "$key" == run_test ]] && { a_key02+=("$key"); continue; }
    [[ "$key" == unit_dispatch* ]] && { a_key1+=("$key"); continue; }
    [[ "$key" == unit_misc* ]] && { a_key2+=("$key"); continue; }
    [[ "$key" == dispatch* ]] && { a_key3+=("$key"); continue; }
    a_key9+=("$key")
  done
  a_key_sorted=("${a_key01[@]}" "${a_key02[@]}" "${a_key1[@]}" "${a_key2[@]}" "${a_key3[@]}" "${a_key9[@]}")

  # Message what will be tested
  pinfo "Will test files with key:" \
    "${a_key_sorted[*]}"

  # Get 'dispatch' in path
  PATH="$gs_root_path:$PATH"
  
  # Create a summary fifo: child -> parent
  # From: https://superuser.com/questions/184307/bash-create-anonymous-fifo
  # start a background pipeline with two processes running forever
  tail -f /dev/null | tail -f /dev/null &
  # save the process ids
  local pid2=$!
  local pid1=$(jobs -p %+)
  # hijack the pipe's file descriptors using procfs
  # l-wx------ 1 mtourneb mtourneb 64 ene  6 00:46 42 -> pipe:[4317132]
  # lr-x------ 1 mtourneb mtourneb 64 ene  6 00:46 43 -> pipe:[4317132]
  # Steal write fd
  exec {gi_summary_write_fd}>/proc/"$pid1"/fd/1
  # Steal read fd
  exec {gi_summary_read_fd}</proc/"$pid2"/fd/0
  
  # kill the background processes we no longer need
  # (using disown suppresses the 'Terminated' message)
  disown "$pid2"
  kill "$pid1" "$pid2"

  # Say Hi
  local commit="$(git -C "$gs_root_path" log -n 1 --pretty=format:"%C(yellow)%h %ad%Cred%d %Creset%s%Cblue [%cn]" --decorate --date=short 2> /dev/null)"
  >&2 echo -e "Testing dispatch. version=$VERSION_DISPATCH commit:\n$commit"

  # Start run all file in test like test_*
  for key in "${!d_test_file[@]}"; do
    test_file=${d_test_file[$key]}
    # Clause: do not test async <= is a keyword
    [[ async == "$test_file" ]] && continue

    # Clause: file must be executable
    if [[ ! -x "$test_file" ]]; then
      >&2 echo -e "Warning: file '$test_file' is not executable => skipping"
      continue
    fi

    # Hi
    >&2 echo -e "\n====================================="
    >&2 echo -e "Testing $test_file ..."
    
    # Set Namespace
    # Get filename without path and extension
    local filename=${test_file##*/}
    filename=${filename//.sh}
    export ART_NAMESPACE="dispatch self $filename"

    # Write junit test_suite start
    if [[ -v g_junit_file && -w "$g_junit_file" ]]; then
      echo "  <testsuite name=\"$test_file\" tests=\"\" errors=\"\" failures=\"\" hostname=\"\" id=\"\" package=\"\" skipped=\"\" time=\"\" timestamp=\"\">"$'\n' >> "$g_junit_file"
    fi

    # Go Sync
    if ((! b_async)); then
      "$test_file"; ret=$?
      d_status[$key]=$ret
      >&2 echo -e "Returned: $ret\n"
      ((res|=ret))
     
    # Fork Async
    else
      # -- Copy file descriptor 1 -> i_fd_stdout
      exec {i_fd_stdout}>&1

      # FORK
      # -- tty dirty trick is dirty to see stdout in terminal but grap it
      exec {i_fd}< <({
        set -o pipefail
        "$test_file" | tee /dev/fd/"$i_fd_stdout"
      })

      # -- Save pid of async
      d_pid[$key]=$!
      # -- Save fd of async
      # shellcheck disable=SC2034  # d_fd appears unused
      d_fd[$key]=$i_fd
    fi

    # Write junit test_suite end
    if [[ -v g_junit_file && -w "$g_junit_file" ]]; then
      echo $'  </testsuite>\n' >> "$g_junit_file"
    fi
  done

  # So can close write fs
  # -- required to close the pipe when children are OK
  exec {gi_summary_write_fd}>&-

  # Async wait
  if ((b_async)); then
    ## Wait for all jobs
    #wait_pid_array "${d_pid[@]}"; ((res|=$?))
    local -i pid=0 ret=0
    for key in "${!d_pid[@]}"; do
      pid=${d_pid[$key]}
      wait "$pid" &> /dev/null; ret=$?
      d_status[$key]=$ret
      (( 0 == ret )) && continue
      (( 127 == ret )) && break
      ((res |= ret ))
    done
  fi

  # Lock Grep interesting output (error and warning)
  local err_summary=$(cat <&"$gi_summary_read_fd")
  if [[ -n "$err_summary" ]]; then
    # Echo Tail
    >&2 echo -e "\nError summary\n====================================="
    >&2 echo -e "$err_summary"
  fi
  
  # Close read fd
  exec {gi_summary_read_fd}>&-

  # Safely set status if grep error,
  # for bash-4.2 that has trouble to get status
  (( res == 0 )) && [[ -n "$err_summary" ]] && res=1

  # Write file summary
  >&2 echo -e "\n\nFile Summary\n============================="
  local -a a_col=(30 7 3)
  local format1="| %-${a_col[0]}s | %-${a_col[1]}s | %-${a_col[2]}s |\n"
  # Each cell take 3, the last 1
  # 25 + 20 + 3 + 3 * 3 + 1 = 5
  local br=$(printf -- '-%.0s' {1..63}; echo)
  >&2 echo "$br"
  >&2 printf "$format1" "File" "Result" "Sts"
  >&2 printf "$format1" \
    "$(printf -- '-%.0s' {1..30})" \
    "$(printf -- '-%.0s' {1..7})" \
    "$(printf -- '-%.0s' {1..3})"

  # Print cell colored values
  for key in "${a_key_sorted[@]}"; do
    [[ async == "$key" ]] && continue
    local color='' tail=''
    local -i status=${d_status[$key]}
    if (( 0 == status )); then
      color="$cgreen"
      tail="SUCCESS"
    else
      color="$cred"
      tail="ERROR"
    fi
    # 12345678901234567890
    # E[38;5;124m
    local -i color_len=$(( ${#color} + ${#cend} ))
    local format2="| %-$((a_col[0] + color_len))s | %-$((a_col[1] + color_len))s | %-$((a_col[2] + color_len))s |\n"
    >&2 printf "$format2" "$color$key$cend" "$color$tail$cend" "$color$status$cend"
  done
  >&2 echo "$br"

  # Calculate time spent
  if [[ osx != $(get_os) ]]; then
    local -i end_time=$(date +%s%N)
    local -i total_time=$((end_time - start_time))
    local -i sec_time=$((total_time / 1000000000))  # mili, micro, nano
    local -i mili_time=$(((total_time / 1000000) % 1000 ))  # mili, micro, nano
  else
    local -i end_time=$(date +%s)
    local -i total_time=$((end_time - start_time))
    local -i sec_time=$((total_time))  # mili, micro, nano
    local -i mili_time=000
  fi

  # Craft goodbye message
  printf -v script_time '%dh:%dm:%ds.%dms' $((sec_time/3600)) $((sec_time%3600/60)) $((sec_time%60)) $((mili_time))
  local msg=""
  (( res == 0 )) \
    && msg+="${cgreen}[+] Main Success:" \
    || msg+="${cred}[-] Main Error:"
  msg+="'Dispatch util unit_test $*' returned with $res status in $script_time$cend"

  # Say Bye
  >&2 echo -e "\nGoodbye\n============================="
  >&2 echo -e "$msg"

  return "$res"
}


main "$@"; exit $?
