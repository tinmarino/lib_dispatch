#!/usr/bin/env bash

export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
gs_root_path="$(dirname "$gs_root_path")"
gs_root_path="$(dirname "$gs_root_path")"
# shellcheck disable=SC1091  # Not following
source "$gs_root_path/test/lib_test.sh"

main(){
  : "Check dispatch project"
  # TODO warn if remote
  if [[ osx != $(get_os) ]]; then
    # In milisecond
    local -i start_time=$(date +%s%N)
  else
    local -i start_time=$(date +%s)
  fi
  local -i res=0 ret=0 i_fd=0 b_async=0 #i_fd_summary=0
  local -a a_pid=()  # Array of pid
  local -a a_test_file=()  # Array of test file name to execute
  local -a a_fd=()  # Array of fd corresponding to the stdout of this file to lock
  #local -a a_fd_summary=()  # Array of child summary to return (list of errors)


  is_in_array async "$@" && b_async=1

  # Save env
  local globignore_save=$GLOBIGNORE

  # Get files to test
  if [[ -z "$*" ]] || [[ async == "$*" ]]; then
    # A/ Dispatch
    # From https://unix.stackexchange.com/a/246103/257838
    export GLOBIGNORE=''

    # A.1. Dispatch function
    a_test_file+=("$gs_root_path"/test/test_dispatch_function*.sh)

    # A.2. All dispatch
    GLOBIGNORE+="$gs_root_path/test/test_dispatch_function*.sh:"
    a_test_file+=("$gs_root_path"/test/test_dispatch*.sh)

    # C/ Subcommands but not dispatch
    GLOBIGNORE+="$gs_root_path/test/test_alma*.sh:"
    GLOBIGNORE+="$gs_root_path/test/test_art*.sh:"
    a_test_file+=("$gs_root_path"/test/test*.sh)

    # D/ Dispatch bin
    GLOBIGNORE=''
    a_test_file+=("$gs_root_path"/test/test_art*.sh)
  else
    # Prepend absolute path of test
    local a_test_file=("${@/#/$gs_root_path/test/}")
  fi

  # Restore env
  export GLOBIGNORE=$globignore_save

  # Clause: test files must be present
  # See: https://stackoverflow.com/a/34195247/2544873
  compgen -G "$gs_root_path"/test/test_*sh &> /dev/null || {
    perr "Check self: Cannot test self <= test files are not present" \
         "Tip: try to run locally <= test files seems to not have been copyed"
    return "$E_REQ"
  }

  # Get 'dispatch' in path
  PATH="$gs_root_path:$PATH"
  
  if ((b_async)); then
    # Run process async
    # Create a summary fifo: child -> parent
    # From: https://superuser.com/questions/184307/bash-create-anonymous-fifo
    # start a background pipeline with two processes running forever
    tail -f /dev/null | tail -f /dev/null &
    # save the process ids
    local PID2=$!
    local PID1=$(jobs -p %+)
    # hijack the pipe's file descriptors using procfs
    # l-wx------ 1 mtourneb mtourneb 64 ene  6 00:46 42 -> pipe:[4317132]
    # lr-x------ 1 mtourneb mtourneb 64 ene  6 00:46 43 -> pipe:[4317132]
    # 42 for Write
    # TODO remove 42 hardcode
    exec 42>/proc/"$PID1"/fd/1
    # 43 for Read
    exec 43</proc/"$PID2"/fd/0
    
    # kill the background processes we no longer need
    # (using disown suppresses the 'Terminated' message)
    disown "$PID2"
    kill "$PID1" "$PID2"
  fi

  # Say Hi
  local commit="$(git -C "$gs_root_path" log -n 1 --pretty=format:"%C(yellow)%h %ad%Cred%d %Creset%s%Cblue [%cn]" --decorate --date=short 2> /dev/null)"
  >&2 echo -e "Testing dispatch. version=$VERSION_DISPATCH commit:\n$commit"

  # Start run all file in test like test_*
  for test_file in "${a_test_file[@]}"; do
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
      a_pid+=($!)
      # -- Save fd of async
      a_fd+=("$i_fd")
      
    fi

    # Write junit test_suite end
    if [[ -v g_junit_file && -w "$g_junit_file" ]]; then
      echo $'  </testsuite>\n' >> "$g_junit_file"
    fi
  done

  # So can close 42, used for write, required to close the pipe when childs are OK
  # TODO hardcode
  exec 42>&-

  # Async wait
  if ((b_async)); then
    ## Wait for all jobs
    wait_pid_array "${a_pid[@]}"; ((res|=$?))

    # Lock Grep interesting output (error and warning)
    local s_error=$(cat <&43)
    if [[ -n "$s_error" ]]; then
      # Echo Tail
      >&2 echo -e "\n====================================="
      >&2 echo -e "$s_error"
    fi
    
    # Close fd
    exec 43>&-

    # Safely set status if grep error,
    # for bash-4.2 that has trouble to get status
    (( res == 0 )) && [[ -n "$s_error" ]] && res=1
  fi

  # Calcultate time spent
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

  # Craft message
  printf -v script_time '%dh:%dm:%ds.%dms' $((sec_time/3600)) $((sec_time%3600/60)) $((sec_time%60)) $((mili_time))
  local msg=""
  (( res == 0 )) \
    && msg+="${cgreen}[+] Main Success:" \
    || msg+="${cred}[-] Main Error:"
  msg+="'Dispatch check self $*' returned with $res status in $script_time$cend"

  # Say Bye
  >&2 echo -e "$msg"

  return "$res"
}


main "$@"; exit $?
