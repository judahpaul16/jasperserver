#!/bin/bash
set -euo pipefail

# Provide safe defaults for required vars
JS_VERSION="${JS_VERSION:-8.2.0}"
DB_TYPE="${DB_TYPE:-mysql}"
DB_HOST="${DB_HOST:-mysql_jasperserver}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-jasperserver}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"

echo "[entrypoint] JasperReports Server CE ${JS_VERSION} startup"
echo "[entrypoint] Waiting for DB ${DB_HOST}:${DB_PORT} ..."

/wait-for-it.sh "${DB_HOST}:${DB_PORT}" -t 60

export BUILDOMATIC_MODE=script

BOOT_FLAG="/.do_deploy_jasperserver"
INIT_FILE="/usr/src/jasperreports-server/.initialized"

if [[ -f "$BOOT_FLAG" && ! -f "$INIT_FILE" ]]; then
  echo "[entrypoint] First-time bootstrap beginning..."
  pushd /usr/src/jasperreports-server/buildomatic >/dev/null

  # Pick correct master properties template
  if [[ -f "sample_conf/${DB_TYPE}_master.properties" ]]; then
    cp "sample_conf/${DB_TYPE}_master.properties" default_master.properties
  elif [[ "$DB_TYPE" == "postgres" && -f sample_conf/postgresql_master.properties ]]; then
    cp sample_conf/postgresql_master.properties default_master.properties
  else
    echo "[entrypoint] Unsupported DB_TYPE: ${DB_TYPE}"
    exit 1
  fi

  sed -i -E "s|^appServerDir.*|appServerDir = ${CATALINA_HOME:-/usr/local/tomcat}|g" default_master.properties
  sed -i -E "s|^dbHost.*|dbHost=${DB_HOST}|; s|^dbPort.*|dbPort=${DB_PORT}|; s|^dbUsername.*|dbUsername=${DB_USER}|; s|^dbPassword.*|dbPassword=${DB_PASSWORD}|" default_master.properties

  # Optional: deploy as ROOT
  if grep -q 'webAppNameCE' default_master.properties; then
    sed -i -E "s|^#?[[:space:]]*webAppNameCE.*|webAppNameCE = ROOT|g" default_master.properties
  else
    echo "webAppNameCE = ROOT" >> default_master.properties
  fi

  ./js-ant create-js-db || true
  ./js-ant init-js-db-ce
  ./js-ant import-minimal-ce
  ./js-ant deploy-webapp-ce

  touch "$INIT_FILE"
  rm -f "$BOOT_FLAG"

  # Optional plugin step can go here (left out for brevity)

  popd >/dev/null
  echo "[entrypoint] Bootstrap complete."
else
  echo "[entrypoint] Existing initialization detected or no bootstrap flag; skipping."
fi

echo "[entrypoint] Starting Tomcat..."
exec catalina.sh run
