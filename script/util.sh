#!/usr/bin/env bash
# Utilities scripts
# -- IDEA: Get list for the bands to filter like 3,5,7 or even 3410 for 3,4,10

set -u

[[ ! -v gi_source_lib_dispatch ]] && {
  [[ ! -v gs_root_path ]] && { gs_root_path=$(readlink -f "${BASH_SOURCE[0]}"); gs_root_path=$(dirname "$gs_root_path"); gs_root_path=$(dirname "$gs_root_path"); }
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path"/script/lib_dispatch.sh
}


# Main options default


unit_test(){
  : '--/ Check current code (dispatch)'
  local -i res=0

  export ART_NAMESPACE="dispatch self"
  export ART_VERBOSE=1

  # Go to local dir
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Declare output filename and clear it
  export g_junit_file="$gs_root_path"/junit_last_result.xml
  : > "$g_junit_file"

  # Write report head
  local title=${JOB_NAME:-"Custom from $(user_at_host) at $(date '+%Y-%m-%dT%H:%M:%S')"}
  # Ref: https://llg.cubic.org/docs/junit/
  print_unindent "
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <testsuites name=\"$title\" tests=\"\" errors=\"\" failures=\"\" time=\"\">
    " >> "$g_junit_file"

  # Run the test
  run ./run_test.sh "$@"; res=$?

  # Write report tail
  echo '</testsuites>' >> "$g_junit_file"

  # Go back
  popd &> /dev/null || return "$E_CD"

  return "$res"
}


__complete_unit_test(){
  : "Internal for completion of lib_dispatch master unit_test"
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Echo all test file
  for test_file in async test_*.sh; do
    if [[ async == "$test_file" ]]; then
      local desc="Run asynchronously all tests (faster)"
    else
      local desc=$(get_file_docstring "$test_file")
    fi
    echo -e "$test_file : $desc"
  done

  popd &> /dev/null || return "$E_CD"
}


make_temp_dir(){
  : 'Just mktemp -d'
  mktemp -d "/tmp/art_$(date '+%Y-%m-%dT%H:%M:%S.%3N')_XXXXXX"
  return $?
}


doc_api(){
  : '99/ Helper to create recursive doc
  From: for the jenkins xml: https://bitbucket.sco.alma.cl/projects/ALMA/repos/adc-sw/browse/GIT/scripts/integrator/integrator.py (tk @camilo.saldias)
  '
  format=${1:-stdout}  # xml, stdout (maybe text in futur)

  local a_subcmd line_cmd line_fct

  # Check current script
  if [[ ! -e "$0" ]]; then
    perr "Cannot execute file $0 for retrieving the api doc"
    return "$E_REQ"
  fi

  local cmd=$0
  local cmd_name=${cmd##*/}

  # Fill a_subcmd
  readarray -t a_subcmd < <(
    "$cmd" --complete "$cmd_name" | grep -v '^-'
  )

  # If Xml: Print hi: main head
  if [[ xml == "$format" ]]; then
    # Redirect stdout
    touch "$cmd_name"_doc_api.xml
    exec 1> "$cmd_name"_doc_api.xml
    echo -e '
      <section name="dispatch online buildfarm API" fontcolor="">

      <table sorttable="yes">
      <tr>
      <td value="Sub Command" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      <td value="Tail Function" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      <td value="Description" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      </tr>
    '
  elif [[ html == "$format" ]]; then
    # Redirect stdout
    touch "$cmd_name"_doc_api.html
    exec 1> "$cmd_name"_doc_api.html
    echo -e "$(print_unindent '
      <!DOCTYPE html>
      <html>
      <head>
      <title>'"$cmd_name"' functions</title>
      <style>
      '"$(<"$gs_root_path"/res/table.css)"'
      </style>
      </head>
      <body>
      <table>
      <tr>
        <th>Sub Command</th>
        <th>Tail Function</th>
        <th>Description</th>
      </tr>
      ')"
  fi

  # For all subcommand
  for line_cmd in "${a_subcmd[@]}"; do
    local subcmd="${line_cmd%% *}"
    local subcomment="${line_cmd#*:}"
    subcomment=$(echo -e "$subcomment" \
      | sed 's/\x1b[^m]*m *//g' \
      | sed 's/&/\&amp;/g' \
      | sed 's/</\&lt;/g' \
      | sed 's/>/\&gt;/g' \
      | sed 's/"/\&quot;/g' \
      | sed "s/'/\\&#39;/g"
    )

    # Print hi: current subcommand head
    if [[ xml == "$format" ]]; then
      echo -e '
        <tr></tr>
        <tr>
          <td value="'"${subcmd^^}"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="'"$subcomment"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
        </tr>
        '
    elif [[ html == "$format" ]]; then
      echo -e "$(print_unindent '
        <tr></tr>
        <tr>
          <th>'"${subcmd^^}"'</th>
          <th></th>
          <th>'"$subcomment"'</th>
        </tr>
      ')"
    else  # Including if [[ stdout == "$format" ]]; then
      echo "# $line_cmd"
    fi

    # Get tail workers (aka subsub)
    readarray -t a_subsub < <(
      "$cmd" --complete "$subcmd" | grep -v '^-'
    )

    # Print current function
    for line_fct in "${a_subsub[@]}"; do
      local function=${line_fct%% :*}
      local comment=${line_fct#*: }
      # Delete escape colors
      # shellcheck disable=SC2001  # See if you can use ${variable//search/replace}
      comment=$(echo -e "$comment" \
        | sed 's/\x1b[^m]*m *//g' \
        | sed 's/&/\&amp;/g' \
        | sed 's/</\&lt;/g' \
        | sed 's/>/\&gt;/g' \
        | sed 's/"/\&quot;/g' \
        | sed "s/'/\\&#39;/g"
      )
      if [[ xml == "$format" ]]; then
        echo -e '
          <tr></tr>
          <tr>
            <td value="'"$subcmd"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$function"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$comment"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
          </tr>
        '
      elif [[ html == "$format" ]]; then
        echo -e "$(print_unindent '
          <tr></tr>
          <tr>
            <td>'"$subcmd"'</td>
            <td>'"$function"'</td>
            <td>'"$comment"'</td>
          </tr>
        ')"
      else  # including if [[ stdout == "$format" ]]; then
        echo "$cmd $subcmd $function  # $comment"
      fi
    done

    # Print Bye
    echo
  done

  # Print Bye: close main head
  if [[ xml == "$format" ]]; then
    echo -e '
      </table>
      </section>
    '
    # Close stdout redirection
    exec 1>&-
  elif [[ html == "$format" ]]; then
    echo -e "$(print_unindent '
      </table>
      </body>
      </html>
    ')"
    exec 1>&-
  fi

  # It consumes an argument
  return 1
}


__complete_doc_api(){
  # From GSiringo presentation: https://confluence.alma.cl/display/ESG/ALMA+Band+Integration
  echo "
    stdout : in text format to stdout
    xml : in xml to local file: ${cmd_name}_doc_api.xml
    html : in html to local file: ${cmd_name}_doc_api.html
  "
  return 1
}


__at_init(){ print_script_start "$@"; }
__at_finish(){ print_script_end "$@"; }

if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi
