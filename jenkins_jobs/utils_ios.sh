#!/bin/bash
function normalize() {
  if ! dir="$(unset CDPATH && cd "${!1}" > /dev/null 2>&1 && pwd)" ; then
    echo "Variable '$1' is not set to an existing directory! Exiting."
    exit 1;
  fi
  eval "$1=$dir"
}

function check_not_empty() {
  if [ -z "${!1}" ];  then
    echo "Variable '$1' is not set or is empty string! Exiting."
    exit 1;
  else
    echo "Using $1=${!1}"
  fi
}

function check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "File '$1' not found! Exiting."
    exit 1
  fi
}

function check_dir_exists() {
  if [ ! -d "$1" ]; then
    echo "Directory '$1' not found! Exiting."
    exit 1
  fi
}

#Sets up admin credentials and properties.yml for designer studio
function set_up_credentials() {
  a="s/\(.*UID:.*\)/:UID: ${!1}/g"
  b="s/\(.*PWD:.*\)/:PWD: ${!2}/g"
  
  echo "Using a=$a"
  echo "Using b=$b"
  
  check_file_exists "$3"
  sed -i '' "$a" "$3"
  sed -i '' "$b" "$3"
  
  echo "Updated properties: $3"
}

function check_server_connection() {
  server="UNKNOWN"
  server_pattern="^:URL: ([:\./0-9a-zA-Z\-]*)"
  if [[ `echo $PROPERTIES` =~ $server_pattern ]]; then server=${BASH_REMATCH[1]}; fi
  
  conn_status=`curl -o /dev/null --silent --speed-limit 5 --speed-time 5 --head --write-out '%{http_code}\n' $server`
  if [ $conn_status -ge 400 ] ; then
    msg="Connection to $server failed with status $conn_status"
    echo $msg
    create_junit_report $msg
    exit 1
  fi
  echo "Connection with server: '$server' verified SUCCESSFULLY!"
}

function set_up_global_properties() {
  echo "${!1}" > "$GIZA_HOME/data/properties.yml"
}

function check_working_dir() {
  WORKING_DIR=$(pwd)
  echo "Working direcotry=$WORKING_DIR"
  
  if [ ! "${WORKING_DIR}" == "${JENKINS_WORKSPACE}" ]; then
    echo "Working directory '$WORKING_DIR' does not match Jenkins workspace '$JENKINS_WORKSPACE'! Exiting."
    exit 1
  fi
}

function clean_reports() {
  echo "Deleting old reports..."
  rm -rf $GIZA_HOME/rspec_html_reports
  mkdir -p $GIZA_HOME/rspec_html_reports
  rm -rf $JENKINS_WORKSPACE/reports
  mkdir -p $JENKINS_WORKSPACE/reports/screenshots
  rm -rf $JENKINS_WORKSPACE/rspec_html_reports
  rm -rf $JENKINS_WORKSPACE/rspec_html_reports_build
  rm -rf $JENKINS_WORKSPACE/rspec_html_reports_run
  rm -rf $JENKINS_WORKSPACE/logs
  mkdir $JENKINS_WORKSPACE/logs
}

function remove_apps_from_device() {
  ideviceinstaller -l | grep "$1" | awk '{print $1}' | xargs -I '{}' ideviceinstaller -u $(get_udid_ios_device) -U {}
  echo "$2"
}

function get_udid_ios_device(){
  idevice_id -l | head -1 | xargs echo
}

function get_properties_file_path() {
  PATH_TO_PROPERTIES=$(dirname "$1")
  echo "${PATH_TO_PROPERTIES/spec/data}/properties.yml"
}

function run_bundle_install() {
  bundle install > $JENKINS_WORKSPACE/logs/bundle_install.log
}

function start_appium() {
  echo 'Starting appium'
  cd ~/appium
  ./bin/appium.js --session-override --port 4444 --udid $(get_udid_ios_device) --native-instruments-lib > $JENKINS_WORKSPACE/logs/appium.log 2>&1 &
  sleep 10
  ./bin/ios-webkit-debug-proxy-launcher.js -c $(get_udid_ios_device):27753 -d > $JENKINS_WORKSPACE/logs/ios_webkit_proxy.log 2>&1 &
  cd $JENKINS_WORKSPACE
  sleep 10
}

function kill_dirty_processes() {
  if ps aux | grep -q '[n]ode'; then
    ps aux | grep '[n]ode' | awk '{print $2}' | xargs -I '{}' kill {}
  fi
}

function cleanup_on_exit() {
  if type -t local_cleanup ; then
    local_cleanup
  fi
  echo "Exit result: $?"
  kill_dirty_processes
  exit 0
}

function create_junit_report() {
  junit_report="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <testsuite name=\"Setup failed\" tests=\"1\">
  <testcase name=\"Error message\">
  <!--failure message=\"$1\" type=\"failed\"/-->
  </testcase>
  </testsuite>"
  
  mkdir -p $JENKINS_WORKSPACE/reports
  echo "$junit_report" > $JENKINS_WORKSPACE/reports/report.xml
}

function setup_begin() {
  create_junit_report "Unknown reason"
}
