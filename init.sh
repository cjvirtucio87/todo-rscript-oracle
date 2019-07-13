#!/bin/bash

readonly ROOT_DIR="$(dirname "$(readlink -f "$0")")";
readonly ORACLE_IMAGE_NAME="${ORACLE_IMAGE_NAME:-orangehrm/oracle-xe-11g}";
readonly ORACLE_IMAGE_TAG="${ORACLE_IMAGE_TAG:-latest}";
readonly ORACLE_PASSWORD="${ORACLE_PASSWORD:-oracle}";
readonly ORACLE_SID="${ORACLE_SID:-xe}";
readonly ORACLE_PORT="${ORACLE_PORT:-1521}";
readonly ORACLE_SHM_SIZE="${ORACLE_SHM_SIZE:-2g}";
readonly ORACLE_USER="${ORACLE_USER:-system}";

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

  if [[ -n "$(docker container ps -af "name=${oracle_name}" --format '{{.ID}}')" ]]; then
    echo "service ${oracle_name} already exists; skipping creation";
  else
    echo 'running oracle container';
    docker run \
      --tty \
      --detach \
      --rm \
      --network "${network_name}" \
      --shm-size="${ORACLE_SHM_SIZE}" \
      --name "${oracle_name}" \
      "${ORACLE_IMAGE_NAME}:${ORACLE_IMAGE_TAG}" 
  fi

  echo 'running runner container';
  # shellcheck disable=SC2154
  docker run \
    --interactive \
    --tty \
    --rm \
    --network "${network_name}" \
    --env "http_proxy=${http_proxy}" \
    --env "https_proxy=${https_proxy}" \
    --env "no_proxy=${no_proxy}" \
    --env "ORACLE_TIMEOUT=60" \
    --env "ORACLE_HOST=${oracle_name}" \
    --env "ORACLE_PORT=${ORACLE_PORT}" \
    --env "ORACLE_DB=${ORACLE_SID}" \
    --env "ORACLE_USER=${ORACLE_USER}" \
    --env "ORACLE_PASSWORD=${ORACLE_PASSWORD}" \
    --name "${runner_name}" \
    "${runner_image_name}:${runner_image_version}" 
}

main "$@";
