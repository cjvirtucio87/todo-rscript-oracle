#!/bin/bash
function healthcheck_oracle {
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
        if echo "exit" | "${ORACLE_HOME}/bin/sqlplus" -L "${user}/${pw}@//${host}:${port}/${db}" | grep Connected > /dev/null; then
            echo "oracle: ok"
            break;
        fi

        echo "oracle: '${host}:${port}' ruok"
        sleep 1
    done
}

healthcheck_oracle \
  -t "${ORACLE_TIMEOUT}" \
  -h "${ORACLE_HOST}" \
  -p "${ORACLE_PORT}" \
  -d "${ORACLE_DB}" \
  -u "${ORACLE_USER}" \
  -w "${ORACLE_PASSWORD}";

echo "executing todo.R";

Rscript "${HOME}/rscript/src/todo.R";

echo "done!";
