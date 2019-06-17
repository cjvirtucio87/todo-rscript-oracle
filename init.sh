#!/bin/bash

readonly ROOT_DIR="$(dirname "$(readlink -f "$0")")";
readonly BUILD_DIR="${ROOT_DIR}/.build";

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

start_dependency_service() {
  local service_name=$1;
  shift;
  local network_name=$1;
  shift;
  local image_name=$1;
  shift;

  echo "starting service: ${service_name}";

  # shellcheck disable=SC2154
  docker run \
    --detach \
    --interactive \
    --tty \
    --rm \
    --network "${network_name}" \
    --env "http_proxy=${http_proxy}" \
    --env "https_proxy=${https_proxy}" \
    --env "no_proxy=${no_proxy}" \
    --name "${service_name}" \
    "${image_name}" \
    "$@";
}

start_service() {
  local service_name=$1;
  shift;
  local network_name=$1;
  shift;
  local image_name=$1;
  shift;

  echo "starting service: ${service_name}";

}

main() {
  local name='todo';
  local network_name="${name}-net";
  local oracle_name="${name}-oracle";
  local oracle_image_name="artifacts.mitre.org:8200/asias-etl-oracle";
  local oracle_image_version=1.0.2;
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

  if [[ -n "$(docker images ${runner_image_name} --format "{{.ID}}")" ]]; then
    echo "Docker image ${runner_image_name} already exists; skipping creation";
  else
    # shellcheck disable=SC2154
    docker build \
      --build-arg "http_proxy=${http_proxy}" \
      --build-arg "https_proxy=${https_proxy}" \
      --build-arg "no_proxy=${no_proxy},${hashed_name}" \
      --network "${network_name}" \
      -t "${runner_image_name}" \
      -f "${ROOT_DIR}/.dockerfile/Dockerfile" \
      .
  fi

  if [[ -n "$(docker container ps -af "name=${oracle_name}" --format '{{.ID}}')" ]]; then
    echo "service ${oracle_name} already exists; skipping creation";
  else
    start_dependency_service "${oracle_name}" "${network_name}" "${oracle_image_name}:${oracle_image_version}";
  fi

  # shellcheck disable=SC2154
  docker run \
    --tty \
    --rm \
    --network "${network_name}" \
    --env "http_proxy=${http_proxy}" \
    --env "https_proxy=${https_proxy}" \
    --env "no_proxy=${no_proxy}" \
    --env "ORACLE_TIMEOUT=20" \
    --env "ORACLE_HOST=${oracle_name}" \
    --env "ORACLE_PORT=${oracle_port}" \
    --env "ORACLE_DB=${ORACLE_DB}" \
    --env "ORACLE_USER=${ORACLE_USER}" \
    --env "ORACLE_PASSWORD=${ORACLE_PASSWORD}" \
    --name "${runner_name}" \
    "${runner_image_name}:${runner_image_version}" \
    "$@";
}

main "$@";
