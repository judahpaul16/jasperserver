FROM tomcat:9.0-jdk17-temurin

LABEL org.opencontainers.image.title="JasperReports Server CE 8.2.0" \
      org.opencontainers.image.source="https://sourceforge.net/projects/jr-community-installers/"

# Tools (includes 'file' if you keep the MIME check variant)
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip file mysql-client git ca-certificates procps && \
    rm -rf /var/lib/apt/lists/*

# Set JS_VERSION so entrypoint can safely reference it
ENV JS_VERSION=8.2.0

RUN set -eux; \
    echo "Downloading JasperReports Server CE ${JS_VERSION} (direct /download URL)"; \
    wget -O /tmp/jasperserver.zip "https://sourceforge.net/projects/jr-community-installers/files/Server/TIB_js-jrs-cp_${JS_VERSION}_bin.zip/download"; \
    FILE_TYPE="$(file -b /tmp/jasperserver.zip)"; \
    echo "Detected file type: ${FILE_TYPE}"; \
    if ! echo "${FILE_TYPE}" | grep -qi zip; then \
       echo "Downloaded file does NOT look like a ZIP"; \
       head -n 40 /tmp/jasperserver.zip || true; \
       exit 1; \
    fi; \
    SIZE="$(stat -c%s /tmp/jasperserver.zip)"; \
    if [ "${SIZE}" -lt 5000000 ]; then \
       echo "Downloaded file too small (${SIZE}) - aborting"; \
       head -n 40 /tmp/jasperserver.zip || true; \
       exit 1; \
    fi; \
    unzip /tmp/jasperserver.zip -d /usr/src; \
    rm /tmp/jasperserver.zip; \
    mv /usr/src/jasperreports-server-cp-${JS_VERSION}-bin /usr/src/jasperreports-server; \
    rm -rf /usr/src/jasperreports-server/samples

ADD wait-for-it.sh /wait-for-it.sh
ADD entrypoint.sh /entrypoint.sh
ADD .do_deploy_jasperserver /.do_deploy_jasperserver

RUN chmod +x /wait-for-it.sh /entrypoint.sh

ENV DB_TYPE=mysql \
    DB_HOST=mysql_jasperserver \
    DB_PORT=3306 \
    DB_NAME=jasperserver \
    DB_USER=root \
    DB_PASSWORD=changeme \
    JAVA_OPTS="-Xms1024m -Xmx2048m" \
    TZ=America/New_York

EXPOSE 8080
VOLUME ["/jasperserver-import"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh", "run"]
