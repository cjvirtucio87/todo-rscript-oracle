#!/bin/bash

readonly ROOT_DIR="$(dirname "$(readlink -f "$0")")";
readonly KUBE_DIR="${ROOT_DIR}/.kube";
readonly APP_ENV='dev';
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
  local oracle_pod_name="${name}-oracle-pod";
  local oracle_rc_name="${name}-oracle-rc";
  local runner_name="${name}-runner";
  local runner_build_name="${name}-runner-build";
  local runner_pod_name="${name}-runner-pod";
  local runner_job_name="${name}-runner-job";
  local runner_image_name="${runner_name}";
  local runner_image_version="latest";

  echo 'creating image stream';
  cat "${KUBE_DIR}/runner_imagestream.yml" \
    | runner_image_name="${runner_image_name}" \
      envsubst \
    | oc create -f -

  echo 'creating build config';
  cat "${KUBE_DIR}/runner_build.yml" \
    | runner_build_name="${runner_build_name}" \
      env="${APP_ENV}" \
      http_proxy="${http_proxy}" \
      https_proxy="${https_proxy}" \
      no_proxy="${no_proxy}" \
      app_oracle_host="${oracle_name}" \
      app_oracle_port="${APP_ORACLE_PORT}" \
      app_oracle_db="${APP_ORACLE_SID}" \
      app_oracle_user="${APP_ORACLE_USER}" \
      app_oracle_password="${APP_ORACLE_PASSWORD}" \
      dockerfile_path=".dockerfile/Dockerfile" \
      runner_image_name="${runner_image_name}" \
      runner_image_version="${runner_image_version}" \
      envsubst \
    | oc create -f -

  oc start-build "bc/${runner_build_name}"

  echo 'running oracle controller';
  cat "${ROOT_DIR}/.kube/oracledb.yml" \
    | oracle_rc_name="${oracle_rc_name}" \
      oracle_pod_name="${oracle_pod_name}" \
      env="${APP_ENV}" \
      oracle_image="${APP_ORACLE_IMAGE_NAME}:${APP_ORACLE_IMAGE_TAG}" \
      oracle_name=${oracle_name} \
      oracle_user="${APP_ORACLE_USER}" \
      oracle_pw="${APP_ORACLE_PASSWORD}" \
      oracle_host="localhost" \
      oracle_port="${APP_ORACLE_PORT}" \
      oracle_db="${APP_ORACLE_DB}" \
      envsubst \
    | oc create -f -

  echo 'running runner controller';
  cat "${ROOT_DIR}/.kube/runner.yml" \
    | runner_job_name="${runner_job_name}" \
      runner_pod_name="${runner_pod_name}" \
      env="${APP_ENV}" \
      runner_image="${runner_image_name}" \
      runner_name=${runner_name} \
      envsubst \
    | oc create -f -
}

main "$@";
