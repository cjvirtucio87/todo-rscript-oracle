#!/bin/bash

readonly ROOT_DIR="$(dirname "$(readlink -f "$0")")";
readonly APP_ORACLE_IMAGE_NAME="${APP_ORACLE_IMAGE_NAME:-orangehrm/oracle-xe-11g}";
readonly APP_ORACLE_IMAGE_TAG="${APP_ORACLE_IMAGE_TAG:-latest}";
readonly APP_ORACLE_PASSWORD="${APP_ORACLE_PASSWORD:-oracle}";
readonly APP_ORACLE_SID="${APP_ORACLE_SID:-xe}";
readonly APP_ORACLE_PORT="${APP_ORACLE_PORT:-1521}";
readonly APP_ORACLE_REQUESTS="${APP_ORACLE_REQUESTS:-cpu=1,memory=2G}";
readonly APP_ORACLE_USER="${APP_ORACLE_USER:-system}";

main() {
  local name='todo';
  local oracle_name="${name}-oracle";
  local oracle_selector="${oracle_name}=default";
  local runner_name="${name}-runner";
  local runner_image_name="cjvirtucio87/${runner_name}";
  local runner_image_version='latest';

  # shellcheck disable=SC2154
  docker build \
    --build-arg "http_proxy=${http_proxy}" \
    --build-arg "https_proxy=${https_proxy}" \
    --build-arg "no_proxy=${no_proxy}" \
    -t "${runner_image_name}:${runner_image_version}" \
    -f "${ROOT_DIR}/.dockerfile/Dockerfile" \
    .

  echo 'running oracle container';
  oc run "${oracle_name}" \
    --image="${APP_ORACLE_IMAGE_NAME}:${APP_ORACLE_IMAGE_TAG}" \
    --requests="${APP_ORACLE_REQUESTS}" \
    --labels="${oracle_selector}" \
    --replicas=3 \
    --port=1521 \
    --generator=run/v1 \
    "${APP_ORACLE_IMAGE_NAME}:${APP_ORACLE_IMAGE_TAG}"

  oc expose rc "${oracle_name}" \
    --selector="${oracle_selector}" \
    --port="${APP_ORACLE_PORT}" \
    --target-port="${APP_ORACLE_PORT}";
}

main "$@";
