FROM centos:7

ENV CONTAINER_USER=foo
ENV CONTAINER_USER_HOME="/home/${CONTAINER_USER}"

ARG R_PACKAGES_MIRROR=http://rweb.crmda.ku.edu/cran/
ENV ORACLE_LINUX_VERSION=ol7 \
    ORACLE_INSTANT_CLIENT_VERSION=19.3
ENV ORACLE_HOME=/usr/lib/oracle/${ORACLE_INSTANT_CLIENT_VERSION}/client64
ENV ORACLE_LINUX_URL=https://yum.oracle.com \
    ORACLE_LINUX_REPO=public-yum-${ORACLE_LINUX_VERSION}.repo \
    ORACLE_LINUX_GPG_KEY=RPM-GPG-KEY-oracle-${ORACLE_LINUX_VERSION} \
    PATH=${ORACLE_HOME}/bin:${PATH} \
    OCI_LIB=${ORACLE_HOME}/lib \
    OCI_INC=/usr/include/oracle/${ORACLE_INSTANT_CLIENT_VERSION}/client64 \
    LD_LIBRARY_PATH=${ORACLE_HOME}/lib \
    TZ=UTC

USER root

RUN set -e; \
    useradd \
      -u 1001 \
      -m \
      -c "Container User" \
      -d "${CONTAINER_USER_HOME}" \
      -g 0 \
      "${CONTAINER_USER}"; \
    chgrp -R 0 /usr/local/bin; \
    chmod -R g+x /usr/local/bin;

ENV HOME="${CONTAINER_USER_HOME}"
USER "${CONTAINER_USER}"
WORKDIR "${CONTAINER_USER_HOME}"

USER root

RUN set -e; \
    curl -Lo /usr/bin/confd 'https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64'; \
    chmod u+x /usr/bin/confd; \
    chgrp 0 /usr/bin/confd; \
    chmod g+u /usr/bin/confd;

RUN set -e; \
    rpm --import ${ORACLE_LINUX_URL}/${ORACLE_LINUX_GPG_KEY}; \
    curl -o /etc/yum.repos.d/${ORACLE_LINUX_REPO} ${ORACLE_LINUX_URL}/${ORACLE_LINUX_REPO}; \
    sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/${ORACLE_LINUX_REPO}; \
    yum-config-manager --enable ol7_oracle_instantclient; \
    yum install -y epel-release; \
    yum update -y; \
    ACCEPT_EULA=Y yum install -y \
      libaio-devel \
      "oracle-instantclient${ORACLE_INSTANT_CLIENT_VERSION}-basic" \
      "oracle-instantclient${ORACLE_INSTANT_CLIENT_VERSION}-sqlplus" \
      "oracle-instantclient${ORACLE_INSTANT_CLIENT_VERSION}-tools" \
      "oracle-instantclient${ORACLE_INSTANT_CLIENT_VERSION}-devel" \
      vim \
      R; \
    yum clean all; \
    mkdir -p "${ORACLE_HOME}/rdbms/public"; \
    mkdir "${CONTAINER_USER_HOME}/rscript"; \
    echo "${ORACLE_HOME}/lib" > '/etc/ld.so.conf.d/oracle.conf';

COPY rscript "${CONTAINER_USER_HOME}/rscript"

RUN set -e; \
    chgrp -R 0 "${CONTAINER_USER_HOME}"; \
    chmod -R g+u "${CONTAINER_USER_HOME}"; \
    cd "${CONTAINER_USER_HOME}/rscript"; \ 
    R -e "install.packages('packrat', repos='${R_PACKAGES_MIRROR}')"; \
    R -e "packrat::restore()";

COPY .dockerfile/docker-entrypoint.sh "/docker-entrypoint.sh"
COPY .dockerfile/rscript/confd "${CONTAINER_USER_HOME}/rscript/confd"

RUN set -e; \
    chgrp 0 '/docker-entrypoint.sh'; \
    chmod u+x '/docker-entrypoint.sh'; \
    chmod g+u '/docker-entrypoint.sh';

ENV HOME="${CONTAINER_USER_HOME}"
USER "${CONTAINER_USER}"
WORKDIR "${CONTAINER_USER_HOME}/rscript"

ENTRYPOINT ["/docker-entrypoint.sh"]

