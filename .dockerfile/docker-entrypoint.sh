#!/bin/bash
healthcheck_oracle() {
    local timeout;
    local host;
    local port;
    local db;
    local user
    local pw;

    while getopts ":t:h:p:d:u:w:" opt; do
      case "${opt}" in
        t)
          timeout="${OPTARG}";
          ;;
        h)
          host="${OPTARG}";
          ;;
        p)
          port="${OPTARG}";
          ;;
        d)
          db="${OPTARG}";
          ;;
        u)
          user="${OPTARG}";
          ;;
        w)
          pw="${OPTARG}";
          ;;
        *)
          echo "invalid flag";
          exit 1;
          ;;
      esac
    done

    for i in $(seq 0 "$timeout"); do
        if (( i == timeout )); then
            echo "oracle: timeout";
            exit 1;
        fi

        # https://stackoverflow.com/a/3779738/2346823
        if echo "exit" | "${APP_ORACLE_HOME}/bin/sqlplus" -L "${user}/${pw}@//${host}:${port}/${db}" | grep Connected > /dev/null; then
            echo "oracle: ok"
            break;
        fi

        echo "oracle: '${host}:${port}' ruok"
        sleep 1
    done
}

main() {
  set -e;

  echo "HOST: ${APP_ORACLE_HOST}, PORT: ${APP_ORACLE_PORT}"

  healthcheck_oracle \
    -t "${APP_ORACLE_TIMEOUT}" \
    -h "${APP_ORACLE_HOST}" \
    -p "${APP_ORACLE_PORT}" \
    -d "${APP_ORACLE_DB}" \
    -u "${APP_ORACLE_USER}" \
    -w "${APP_ORACLE_PASSWORD}";

  echo 'templating config.yml';

  confd -onetime -backend 'env' -confdir 'confd' -log-level 'debug' 

  cat config.yml

  echo "executing todo.R";

  Rscript 'src/todo.R';

  echo "done!";

  set +e;
}

main "$@";
