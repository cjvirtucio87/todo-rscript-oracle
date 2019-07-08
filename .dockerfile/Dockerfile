FROM centos:7

ENV CONTAINER_USER=foo
ENV CONTAINER_USER_HOME="/home/${CONTAINER_USER}"

ARG R_PACKAGES_MIRROR=http://rweb.crmda.ku.edu/cran/
ENV ORACLE_LINUX_VERSION=ol7 \
    ORACLE_INSTANT_CLIENT_VERSION=18.3
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
    chmod -R a+x /usr/local/bin;

RUN set -e; \
    curl -o /usr/bin/confd 'https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64'; \
    chmod u+x /usr/bin/confd;

RUN set -e; \
    rpm --import ${ORACLE_LINUX_URL}/${ORACLE_LINUX_GPG_KEY}; \
    curl -o /etc/yum.repos.d/${ORACLE_LINUX_REPO} ${ORACLE_LINUX_URL}/${ORACLE_LINUX_REPO}; \
    sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/${ORACLE_LINUX_REPO}; \
    yum-config-manager --enable ol7_oracle_instantclient; \
    yum install -y epel-release; \
    yum update -y; \
    ACCEPT_EULA=Y yum install -y \
      libaio-devel \
      oracle-instantclient18.3-basic \
      oracle-instantclient18.3-sqlplus \
      oracle-instantclient18.3-tools \
      oracle-instantclient18.3-devel \
      R; \
    yum clean all; \
    mkdir -p "${ORACLE_HOME}/rdbms/public"; \
    mkdir "${CONTAINER_USER_HOME}/rscript"; \
    echo "${ORACLE_HOME}/lib" > '/etc/ld.so.conf.d/oracle.conf'; \
    ldconfig;

COPY rscript "${CONTAINER_USER_HOME}/rscript"

RUN set -e; \
    cd "${CONTAINER_USER_HOME}/rscript"; \ 
    R -e "install.packages('packrat', repos='${R_PACKAGES_MIRROR}')"; \
    R -e "packrat::restore()";

COPY .dockerfile/docker-entrypoint.sh "/docker-entrypoint.sh"

WORKDIR "${CONTAINER_USER_HOME}/rscript"

ENV HOME="${CONTAINER_USER_HOME}"
USER "${CONTAINER_USER}"
WORKDIR "${CONTAINER_USER_HOME}"

ENTRYPOINT ["/docker-entrypoint.sh"]

