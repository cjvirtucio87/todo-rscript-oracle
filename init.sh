#!/bin/bash

readonly ROOT_DIR="$(dirname "$(readlink -f "$0")")";
readonly APP_ORACLE_IMAGE_NAME="${APP_ORACLE_IMAGE_NAME:-orangehrm/oracle-xe-11g}";
readonly APP_ORACLE_IMAGE_TAG="${APP_ORACLE_IMAGE_TAG:-latest}";
readonly APP_ORACLE_PASSWORD="${APP_ORACLE_PASSWORD:-oracle}";
readonly APP_ORACLE_SID="${APP_ORACLE_SID:-xe}";
readonly APP_ORACLE_PORT="${APP_ORACLE_PORT:-1521}";
readonly APP_ORACLE_SHM_SIZE="${APP_ORACLE_SHM_SIZE:-2g}";
readonly APP_ORACLE_USER="${APP_ORACLE_USER:-system}";

cleanup() {
  local network_name=$1;
  shift;

  for name in "$@"; do
    echo "removing ${name}";
    docker container stop "${name}";
    docker container rm "${name}";
  done

  docker network rm "${network_name}";
}

main() {
  local name='todo';
  local network_name="${name}-net";
  local oracle_name="${name}-oracle";
  local runner_name="${name}-runner";
  local runner_image_name="cjvirtucio87/${runner_name}";
  local runner_image_version='latest';

  # shellcheck disable=SC2086
  # shellcheck disable=SC2064
  trap "cleanup ${network_name} ${oracle_name} ${runner_name}" EXIT

  if [[ -n "$(docker network ls -f "name=^${network_name}" --format "{{.Name}}")" ]]; then
    echo "Network ${network_name} already exists; skipping creation";
  else
    docker network create "${network_name}";
  fi

  if [[ -n "${REBUILD}" ]]; then
    echo "removing runner image, ${runner_image_name}";
    docker image rm "${runner_image_name}";
  fi

  # shellcheck disable=SC2154
  docker build \
    --build-arg "http_proxy=${http_proxy}" \
    --build-arg "https_proxy=${https_proxy}" \
    --build-arg "no_proxy=${no_proxy},${hashed_name}" \
    --network "${network_name}" \
    -t "${runner_image_name}" \
    -f "${ROOT_DIR}/.dockerfile/Dockerfile" \
    .

  local common_network_args=(
      --network "${network_name}" \
      --env "http_proxy=${http_proxy}" \
      --env "https_proxy=${https_proxy}" \
      --env "no_proxy=${no_proxy}"
  )

  if [[ -n "$(docker container ps -af "name=${oracle_name}" --format '{{.ID}}')" ]]; then
    echo "service ${oracle_name} already exists; skipping creation";
  else
    echo 'running oracle container';
    docker run \
      --tty \
      --detach \
      --rm \
      "${common_network_args[@]}" \
      --shm-size="${APP_ORACLE_SHM_SIZE}" \
      --name "${oracle_name}" \
      "${APP_ORACLE_IMAGE_NAME}:${APP_ORACLE_IMAGE_TAG}" 
  fi

  echo 'running runner container';

  local common_runner_args=(
      --env "APP_ORACLE_TIMEOUT=60" \
      --env "APP_ORACLE_HOST=${oracle_name}" \
      --env "APP_ORACLE_PORT=${APP_ORACLE_PORT}" \
      --env "APP_ORACLE_DB=${APP_ORACLE_SID}" \
      --env "APP_ORACLE_USER=${APP_ORACLE_USER}" \
      --env "APP_ORACLE_PASSWORD=${APP_ORACLE_PASSWORD}"
  )

  if [ -n "${TEST_DEBUG+x}" ]; then
    # shellcheck disable=SC2154
    docker run \
      --entrypoint='' \
      --interactive \
      --tty \
      --rm \
      "${common_network_args[@]}" \
      "${common_runner_args[@]}" \
      --name "${runner_name}" \
      "${runner_image_name}:${runner_image_version}" \
      '/bin/bash'
  else
    # shellcheck disable=SC2154
    docker run \
      --tty \
      --rm \
      "${common_network_args[@]}" \
      "${common_runner_args[@]}" \
      --name "${runner_name}" \
      "${runner_image_name}:${runner_image_version}" 
  fi
}

main "$@";
