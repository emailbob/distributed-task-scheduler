#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

CONSUL_HOST=${CONSUL_HOST:-localhost}
CONSUL_PORT=${CONSUL_PORT:-8500}
CONSUL_ADDR="http://${CONSUL_HOST}:${CONSUL_PORT}"
CURL_TIMEOUT=10

SERVER_NAME=${SERVER_NAME:-$(hostname)}
ROOT_KEY="tasks"
TASK_ID=""
PERIOD=${PERIOD:-60}

SLACK_WEBHOOK=${SLACK_WEBHOOK:-}
DATADOG_API_KEY=${DATADOG_API_KEY:-}

STATUS_AVAILABLE="available"
STATUS_RUNNING="running"
STATUS_FINISHED="finished"

enable_slack=0
enable_datadog=0

usage() {
  cat <<-EOF
  Usage: $0 -t <task id> -p <period> -s <command>

  This script runs a distributed task scheduler backed by consul

  Arguments:
    -t  Task id identify so you can group multiple sets of tasks
    -p  How often you want the task to run: default $PERIOD
    -r  Register node to consul [yes|no]
    -s  Enable sending task status to Slack
    -d  Enable sending task metrics to DataDog

  Example:
    $0 -t test -p 60 -s -d echo Hello World
    $0 -t test -r yes
EOF
  exit 1
}

#
# Add or remove the node in consul
#
register() {
  local option="$1"

  if [[ ${option} == "add" ]]; then
    ret="$(curl -s -X PUT -d "${STATUS_AVAILABLE}" \
    "${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/status/${SERVER_NAME}")"

    if [[ "${ret}" == "true" ]]; then
      msg="${SERVER_NAME} added to the task id: ${TASK_ID} in consul"
      echo "${msg}"
      post_to_slack "${msg}"
      exit 0
    fi
  else
    ret="$(curl -s -X DELETE "${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/status/${SERVER_NAME}")"

    if [[ "${ret}" == "true" ]]; then
      echo "${SERVER_NAME} removed from the task id: ${TASK_ID} in consul"
      exit 0
    fi
  fi
  exit 1
}

#
# Post status to Slack
#
post_to_slack() {
  local message="$1"

  if [[ "${enable_slack}" -eq 1 && "${enable_slack}" != "" ]] ; then
      ret=$(curl --connect-timeout ${CURL_TIMEOUT} -s -X POST -H "Content-type: application/json" \
      --data "{\"text\":\"${message}\"}" "${SLACK_WEBHOOK}")

      if [[ "$ret" != "ok" ]]; then
        echo "Error posting to slack: ${ret}"
        exit 1
      fi
  fi
}

#
# Post status to DataDog
#
post_to_datadog() {
  local metric="$1"
  local metric_type="$2"

  if [[ "${enable_datadog}" -eq 1 && "${enable_datadog}" != "" ]] ; then

      curl  -X POST -H "Content-type: application/json" \
      -d "{ \"series\" :
              [{\"metric\":\"${metric_type}.metric\",
                \"points\":[[$metric, 20]],
                \"type\":\"rate\",
                \"interval\": 20,
                \"host\":\"${SERVER_NAME}\",
                \"tags\":[\"environment:test\"]}
              ]
      }" \
      "https://api.datadoghq.com/api/v1/series?api_key=${DATADOG_API_KEY}"

  fi
}

#
# Check to see if a task is ready to be run in the current time period
#
check_open_slot() {
    current_run="$(date '+%s')"
    consul_url="${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/current_run"

    last_run_hash="$(curl -sS -X GET "${consul_url}" | jq -r '.[].Value')"

    if [[ "${last_run_hash}" != "null" ]]; then
      last_run=$(echo "${last_run_hash}" | base64 --decode)
    fi

    modify_index="$(curl -sS -X GET "${consul_url}" | jq -r '.[].ModifyIndex')"

    # Check if the task has already run on another node
    if [[ "${last_run:-0}" -ge "$((current_run-PERIOD))" ]]; then
      echo "The task already started on another node within the past ${PERIOD} seconds"
      exit 0
    fi

    # Check if the task has already run on this node
    is_node_available

    # Try to acquire a lock with consul
    ret="$(curl -sS -X PUT -d "${current_run}" "${consul_url}?cas=${modify_index:-0}")"
    if [[ "${ret}" != "true" ]]; then
        exit 0
    fi

    echo "Task ready to run"
}

#
# Check to see if the task has already been run on this node
#
is_node_available() {
  echo "Checking if this node is available to run the task"
  status=$(curl -s "${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/status/${SERVER_NAME}?raw")

  if [[ ${status} != "" ]]; then
    if [[ ${status} == "${STATUS_AVAILABLE}" ]]; then
      echo "This Node is available to run the task"
    else
      echo "The task has already been run on this node: SKIPPING"

      exit 0
    fi
  else
    echo "This node has not been registered in consul"
    exit 1
  fi
}

#
# Update the node status
#
change_node_status() {
  local status="$1"

  ret=$(curl -s -X PUT -d "${status}" \
  "${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/status/${SERVER_NAME}")

  echo "Updating node to: ${status}"
}

#
# Reset nodes back to available if the task has been run on all of them
#
check_for_finished_nodes () {
  # Get node status keys
  ret=$(curl -s  "${CONSUL_ADDR}/v1/kv/${ROOT_KEY}/${TASK_ID}/status/?keys" | jq -r '.[]')

  status_keys_array=($ret)
  finished_count=0

  # Increment a count for all nodes that are status="finished"
  for status_key in "${status_keys_array[@]}"
  do
      status=$(curl -s "${CONSUL_ADDR}/v1/kv/${status_key}?raw")

      if [[ ${status} == "${STATUS_FINISHED}" ]]; then
        finished_count=$((finished_count+1))
      fi
  done

  # Check if the number of status="finished" equals the number of nodes
  if [[ ${#status_keys_array[@]} == "${finished_count}" ]]; then
    msg="The task has run on each node. Setting all nodes back to being available"
    echo "${msg}"

    # Reset all nodes back to "available" status
    for status_key in "${status_keys_array[@]}"
    do
      ret="$(curl -s -X PUT -d "${STATUS_AVAILABLE}" "${CONSUL_ADDR}/v1/kv/${status_key}")"
      if [[ "${ret}" != "true" ]]; then
          echo "${status_key} did not updated to be available"
      fi
    done

    # Tell slack that all nodes have ran the tasks
    post_to_slack "_${msg}_"
  fi
}

#
# Execute the task
#
execute_command() {
  echo "Executing command: ${command[*]}"

  change_node_status "${STATUS_RUNNING}"

  post_to_slack "*Running*\nTask id: ${TASK_ID}\nNode: ${SERVER_NAME}\nCommand: \`${command[*]}\`"

  # Reset shell timer so we can see how long the task takes to run
  SECONDS=0;

  # Execute the command
  "${command[@]}"

  change_node_status "${STATUS_FINISHED}"

  post_to_datadog "${SECONDS}" "execution_time"

  post_to_slack "*Completed*\nTask id: ${TASK_ID}\nNode: ${SERVER_NAME}\nDuration: ${SECONDS} seconds"

}

while getopts ":t:p:r:hsd" opt; do
  case ${opt} in
    t) TASK_ID="${OPTARG}";;
    p) PERIOD="${OPTARG}";;
    r) register "${OPTARG}";;
    s) enable_slack=1;;
    d) enable_datadog=1;;
    h) usage;;
    ?)
      echo "Invalid flag on the command line: ${OPTARG}" 1>&2
      ;;
    *) usage;;
  esac
done
shift $((OPTIND -1))

if [[ -z "${TASK_ID}" ]] ; then
  usage
fi

command=("$@")

# Check if task is avaiable to be run
check_open_slot

# Start running your task
execute_command

# Reset nodes to available if tasks have been run on all nodes
check_for_finished_nodes