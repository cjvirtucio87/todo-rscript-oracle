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
readonly APP_SSH_PRIVATE_KEY="${APP_SSH_PRIVATE_KEY:-${HOME}/.ssh/id_rsa}";
readonly APP_SSH_PUBLIC_KEY="${APP_SSH_PUBLIC_KEY:-${HOME}/.ssh/id_rsa.pub}";

cleanup() {
  local runner_job_name="$1";
  local runner_build_name="$2";
  local runner_image_name="$3";
  local runner_ssh_secret_name="$4";
  local oracle_service_name="$5";
  local oracle_rc_name="$6";

  oc delete job "${runner_job_name}";
  oc delete bc "${runner_build_name}";
  oc delete imagestream "${runner_image_name}";
  oc secrets unlink builder "${runner_ssh_secret_name}";
  oc delete secret "${runner_ssh_secret_name}";
  oc delete service "${oracle_service_name}";
  oc delete rc "${oracle_rc_name}";
}

main() {
  local name='todo';
  local oracle_name="${name}-oracle";
  local oracle_pod_name="${name}-oracle-pod";
  local oracle_rc_name="${name}-oracle-rc";
  local oracle_service_name="${name}-oracle-service";
  local runner_name="${name}-runner";
  local runner_build_name="${name}-runner-build";
  local runner_ssh_secret_name="${name}-runner-ssh-key";
  local runner_pod_name="${name}-runner-pod";
  local runner_job_name="${name}-runner-job";
  local runner_image_name="${runner_name}";
  local runner_image_version="latest";

  if [[ "${CLEANUP_BEFORE}" ]]; then
    cleanup "${runner_job_name}" "${runner_build_name}" "${runner_image_name}" "${runner_ssh_secret_name}" "${oracle_service_name}" "${oracle_rc_name}"
  fi

  if [[ "${CLEANUP_AFTER}" ]]; then
    trap "cleanup ${runner_job_name} ${runner_build_name} ${runner_image_name} ${runner_ssh_secret_name} ${oracle_service_name} ${oracle_rc_name}"  EXIT
  fi

  oc create secret generic ${runner_ssh_secret_name} \
    --from-file=ssh-privatekey="${APP_SSH_PRIVATE_KEY}" \
    --from-file=ssh-publickey="${APP_SSH_PUBLIC_KEY}"

  oc secrets link builder "${runner_ssh_secret_name}";

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
      runner_ssh_secret_name="${runner_ssh_secret_name}" \
      envsubst \
    | oc create -f -

  oc start-build "bc/${runner_build_name}"

  echo 'creating oracle service';
  cat "${KUBE_DIR}/oracledb_service.yml" \
    | oracle_service_name="${oracle_service_name}" \
      oracle_pod_name="${oracle_pod_name}" \
      envsubst \
    | oc create -f -

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
