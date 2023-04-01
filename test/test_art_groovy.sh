#!/usr/bin/env bash
# Check groovy files are linted (describe Jenkins jobs)

# shellcheck disable=SC2030,SC2031  # OK: subshell related + tests

# Source test utilities
  export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
  gs_root_path="$(dirname "$gs_root_path")"
  gs_root_path="$(dirname "$gs_root_path")"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"

  # Source code to test
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/script/lib_dispatch.sh"


# Startup
magic

lint_groovy(){
  local out=$(curl --silent -X POST -F "jenkinsfile=<$1" "$MASTER_URL"/pipeline-model-converter/validate)
  echo "$out"
  [[ "$out" =~ 'Errors encountered validating' ]]
  return $((! $?))
}

all_lint_groovy(){
  pushd "$gs_root_path" > /dev/null || {
    pwarn "Cannot goto root dir, pass test"
    return "$E_REQ"
  }

  # Craft parrallel jobs
  declare -gA gd_bash_parallel_command=()
  for file in job/*.groovy; do
    gd_bash_parallel_command["$file"]="lint_groovy \"$file\""
  done

  # Work parallel
  bash_parallel

  # Report
  for file in "${!gd_bash_parallel_command[@]}"; do
    equal 0 "${gd_bash_parallel_status[$file]}" "Lint: Groovy: \"$file\" job is well linted. stdout=${gd_bash_parallel_stdout[$file]}"
  done

  popd > /dev/null || return "$E_REQ"
}


# Single launch
start_test_function "Testing linting of jobs with Groovy syntax from master"
  all_lint_groovy

>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
