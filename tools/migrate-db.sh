#!/usr/bin/env bash
# migrate-db.sh - Database Migration Script for PostgreSQL and MariaDB
#
# PostgreSQL Usage:
#   ./migrate-db.sh \
#     --image postgres:18 \
#     --old-name nextcloud_db \
#     --old-port 5432 \
#     --network my_network \
#     [--old-user postgres] \
#     [--old-password oldpw] \
#     [--new-password newpw] \
#     [--out-dir /tmp]
#
# MariaDB Usage:
#   ./migrate-db.sh \
#     --image mariadb:11.4 \
#     --old-name nextcloud_db \
#     --old-port 3306 \
#     --network my_network \
#     --old-user root \
#     [--old-password oldpw] \
#     [--new-password newpw] \
#     [--out-dir /tmp]
#
# PostgreSQL Migration:
#  - Creates a host dir /tmp/db_migration_<ts>
#  - Starts a new postgres container (from --image) on the same network
#  - Uses the NEW image's pg_dumpall to dump FROM the OLD container and pipe into psql inside the NEW container
#  - Stops and removes the new container but keeps the data at the host dir for inspection/testing
#
# MariaDB Migration:
#  - Creates a host dir /tmp/db_migration_<ts>
#  - Copies existing MariaDB data to the migration directory
#  - Starts new MariaDB container with --skip-grant-tables
#  - Runs mariadb-upgrade to upgrade the database structure
#  - Stops and removes the new container but keeps the upgraded data
#
# SECURITY NOTE:
#  - For PostgreSQL: Sets POSTGRES_HOST_AUTH_METHOD=trust for the temporary instance
#  - For MariaDB: Uses --skip-grant-tables during upgrade process
#  - These are done only for short-lived temporary instances. Don't use in insecure multi-tenant networks.
set -euo pipefail

print_usage() {
  cat <<EOF
migrate-db.sh - Database Migration Script for PostgreSQL and MariaDB

Required:
  --image           Docker image string for the NEW database (example: postgres:18, mariadb:11.4)
  --old-name        Docker container name or hostname of the OLD database (as reachable on the docker network)
  --old-port        Port on which the OLD database is listening (container internal port, usually 5432 for PostgreSQL, 3306 for MariaDB)

Optional:
  --network         Docker network name where both containers are reachable (default: empty)
  --old-user        Old DB user (default: postgres for PostgreSQL, root for MariaDB)
  --old-password    Old DB password (default: empty)
  --new-password    New DB password (default: migrate_tmp_pass)
  --out-dir         Host base directory to place migration dir (default: /tmp)
  --data-mount      Container data mount path (auto-detected from image if not specified)
  --old-data-path   Path to existing data directory for MariaDB in-place upgrades

Examples:
  # PostgreSQL migration
  ./migrate-db.sh --image postgres:18 --old-name nextcloud_db --old-port 5432 --network nextcloud_net

  # MariaDB migration (dump/restore)
  ./migrate-db.sh --image mariadb:11.4 --old-name nextcloud_db --old-port 3306 --network nextcloud_net --old-user root

  # MariaDB in-place upgrade (existing data)
  ./migrate-db.sh --image mariadb:11.4 --old-data-path /path/to/existing/mariadb/data

Note:
  The script automatically detects the database type from the image name (postgres/mariadb) and applies
  the appropriate migration strategy. For MariaDB, it can either dump/restore from an existing container
  or perform an in-place upgrade of existing data files.
EOF
}

# Default values
OLD_USER=""  # Will be set based on database type
OLD_PASSWORD=""
NEW_PASSWORD="migrate_tmp_pass"
OUT_BASE="/tmp"
DATA_MOUNT_PATH=""  # Will be auto-detected based on database type and version
OLD_DATA_PATH=""    # For MariaDB in-place upgrades

# Parse args
if [ $# -eq 0 ]; then
  print_usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2;;
    --old-name) OLD_NAME="$2"; shift 2;;
    --old-port) OLD_PORT="$2"; shift 2;;
    --network) NETWORK="$2"; shift 2;;
    --old-user) OLD_USER="$2"; shift 2;;
    --old-password) OLD_PASSWORD="$2"; shift 2;;
    --new-password) NEW_PASSWORD="$2"; shift 2;;
    --out-dir) OUT_BASE="$2"; shift 2;;
    --data-mount) DATA_MOUNT_PATH="$2"; shift 2;;
    --old-data-path) OLD_DATA_PATH="$2"; shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

# Required checks
: "${IMAGE:?--image is required}"

# Detect database type from image
detect_db_type() {
  local image="$1"
  if [[ "$image" =~ postgres ]]; then
    echo "postgresql"
  elif [[ "$image" =~ mariadb ]]; then
    echo "mariadb"
  elif [[ "$image" =~ mysql ]]; then
    echo "mysql"
  else
    echo "unknown"
  fi
}

DB_TYPE=$(detect_db_type "$IMAGE")
echo "Detected database type: $DB_TYPE"

# Set default user based on database type if not provided
if [ -z "$OLD_USER" ]; then
  case "$DB_TYPE" in
    postgresql) OLD_USER="postgres";;
    mariadb|mysql) OLD_USER="root";;
    *) echo "Error: Unknown database type. Cannot set default user."; exit 1;;
  esac
fi

# Validate required parameters based on database type and operation mode
if [ -n "$OLD_DATA_PATH" ]; then
  # In-place upgrade mode (MariaDB only)
  if [ "$DB_TYPE" != "mariadb" ]; then
    echo "Error: --old-data-path is only supported for MariaDB in-place upgrades"
    exit 1
  fi
  if [ ! -d "$OLD_DATA_PATH" ]; then
    echo "Error: Old data path $OLD_DATA_PATH does not exist or is not a directory"
    exit 1
  fi
else
  # Dump/restore mode - requires old database connection info
  : "${OLD_NAME:?--old-name is required for dump/restore mode}"
  : "${OLD_PORT:?--old-port is required for dump/restore mode}"
  : "${NETWORK:?--network is required for dump/restore mode}"
fi

# Auto-detect database data mount path if not provided
detect_db_data_path() {
  local image="$1"
  local db_type="$2"

  case "$db_type" in
    postgresql)
      # Try to extract version from image tag
      local version=""
      if [[ "$image" =~ postgres:([0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
      elif [[ "$image" =~ postgres:([0-9]+\.[0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
        # Extract major version only
        version="${version%%.*}"
      fi

      if [ -n "$version" ] && [ "$version" -ge 18 ] 2>/dev/null; then
        # For PostgreSQL 18+, the data directory structure changed
        echo "/var/lib/postgresql/${version}/docker"
      else
        # Fallback for older versions
        echo "/var/lib/postgresql/data"
      fi
      ;;
    mariadb|mysql)
      # MariaDB/MySQL standard data directory
      echo "/var/lib/mysql"
      ;;
    *)
      echo "Error: Unknown database type for data path detection"
      exit 1
      ;;
  esac
}

# Set data mount path if not provided
if [ -z "$DATA_MOUNT_PATH" ]; then
  DATA_MOUNT_PATH=$(detect_db_data_path "$IMAGE" "$DB_TYPE")
  echo "Auto-detected $DB_TYPE data mount path: $DATA_MOUNT_PATH"
fi

# Generate names and paths
TS=$(date +%Y%m%d%H%M%S)
MIG_DIR="${OUT_BASE}/db_migration_${TS}"
NEW_CONTAINER="db_migrate_new_${TS}"

cleanup() {
  rc=$?
  echo "Cleaning up..."
  if docker ps -a --format '{{.Names}}' | grep -q "^${NEW_CONTAINER}\$"; then
    echo " - stopping and removing container ${NEW_CONTAINER}"
    docker rm -f "${NEW_CONTAINER}" >/dev/null 2>&1 || true
  fi
  echo "Temporary container removed. Data directory preserved at: ${MIG_DIR}"
  exit $rc
}
trap cleanup INT TERM EXIT

# MariaDB-specific functions
migrate_mariadb_dump_restore() {
  echo "Starting MariaDB dump/restore migration..."

  # Start new temporary MariaDB container
  echo "Starting new MariaDB container '${NEW_CONTAINER}' from image '${IMAGE}' on network '${NETWORK}'..."
  docker run -d \
    --name "${NEW_CONTAINER}" \
    --network "${NETWORK}" \
    -v "${MIG_DIR}":"${DATA_MOUNT_PATH}" \
    -e MYSQL_ROOT_PASSWORD="${NEW_PASSWORD}" \
    -e MYSQL_DATABASE=temp \
    "${IMAGE}" >/dev/null

  echo "Waiting for new MariaDB to become ready..."
  # Wait for MariaDB to accept connections
  MAX_RETRIES=30
  i=0
  until docker exec "${NEW_CONTAINER}" mysqladmin ping -h"localhost" --silent >/dev/null 2>&1; do
    i=$((i+1))
    if [ ${i} -ge ${MAX_RETRIES} ]; then
      echo "New MariaDB did not become ready after ${MAX_RETRIES} attempts."
      exit 2
    fi
    sleep 1
  done
  echo "New MariaDB is ready."

  # Run the migration: Use mysqldump to dump FROM the OLD container and pipe into mysql inside the new container
  echo "Starting dump from OLD (${OLD_NAME}:${OLD_PORT}) and restore into NEW (${NEW_CONTAINER}:3306)..."

  # Build the env prefix for old password if provided
  if [ -n "${OLD_PASSWORD}" ]; then
    OLD_PW_ARG="-p${OLD_PASSWORD}"
  else
    OLD_PW_ARG=""
  fi

  # Use the NEW IMAGE to run mysqldump and pipe into mysql
  set -o pipefail
  if docker run --rm --network "${NETWORK}" "${IMAGE}" \
       mysqldump -h "${OLD_NAME}" -P "${OLD_PORT}" -u "${OLD_USER}" ${OLD_PW_ARG} --all-databases --routines --triggers 2> >(sed 's/^/[mysqldump] /' >&2) \
     | docker exec -i "${NEW_CONTAINER}" mysql -u root -p"${NEW_PASSWORD}" 2> >(sed 's/^/[mysql] /' >&2); then
    echo "Dump and restore completed successfully."
  else
    echo "ERROR: dump/restore failed. Check the logs above for details."
    exit 3
  fi
}

migrate_mariadb_inplace_upgrade() {
  echo "Starting MariaDB in-place upgrade..."

  echo "Starting MariaDB container '${NEW_CONTAINER}' for upgrade..."
  docker run -d \
    --name "${NEW_CONTAINER}" \
    -v "${OLD_DATA_PATH}":/old_data:ro \
    -v "${MIG_DIR}":"${DATA_MOUNT_PATH}" \
    -e MYSQL_ROOT_PASSWORD="${NEW_PASSWORD}" \
    "${IMAGE}" \
    tail -f /dev/null # keep container running

  # Copy existing data
  echo "Copying existing MariaDB data from ${OLD_DATA_PATH} to ${MIG_DIR}..."
  docker exec "${NEW_CONTAINER}" cp -a "old_data/." "${DATA_MOUNT_PATH}/" >/dev/null 2>&1

  # Start MariaDB with --skip-grant-tables
  echo "Starting MariaDB with --skip-grant-tables..."
  docker exec "${NEW_CONTAINER}" docker-entrypoint.sh mariadbd --skip-grant-tables >/dev/null 2>&1 &

  echo "Waiting for MariaDB to start..."
  # Wait for MariaDB to start (it won't accept regular connections due to --skip-grant-tables)
  sleep 1

  # Check if MariaDB process is running inside container
  MAX_RETRIES=30
  i=0
  until docker exec "${NEW_CONTAINER}" pgrep -f mariadbd >/dev/null 2>&1; do
    i=$((i+1))
    if [ ${i} -ge ${MAX_RETRIES} ]; then
      echo "MariaDB process did not start after ${MAX_RETRIES} attempts."
      exit 2
    fi
    sleep 1
  done
  echo "MariaDB is running with --skip-grant-tables."

  # Run mariadb-upgrade
  echo "Running mariadb-upgrade to upgrade database structure..."
  if docker exec "${NEW_CONTAINER}" mariadb-upgrade --skip-version-check 2> >(sed 's/^/[mariadb-upgrade] /' >&2); then
    echo "MariaDB upgrade completed successfully."
  else
    echo "ERROR: mariadb-upgrade failed. Check the logs above for details."
    exit 3
  fi

  # Stop the container with --skip-grant-tables
  echo "Stopping upgrade container..."
  docker stop "${NEW_CONTAINER}" >/dev/null
  docker rm "${NEW_CONTAINER}" >/dev/null

  # Start a normal MariaDB container to verify the upgrade
  echo "Starting MariaDB container for verification..."
  docker run -d \
    --name "${NEW_CONTAINER}" \
    -v "${MIG_DIR}":"${DATA_MOUNT_PATH}" \
    -e MYSQL_ROOT_PASSWORD="${NEW_PASSWORD}" \
    "${IMAGE}" >/dev/null

  echo "Waiting for upgraded MariaDB to become ready..."
  i=0
  until docker exec "${NEW_CONTAINER}" mysqladmin ping -h"localhost" --silent >/dev/null 2>&1; do
    i=$((i+1))
    if [ ${i} -ge ${MAX_RETRIES} ]; then
      echo "Upgraded MariaDB did not become ready after ${MAX_RETRIES} attempts."
      exit 2
    fi
    sleep 1
  done
  echo "Upgraded MariaDB is ready and verified."
}

# PostgreSQL migration function
migrate_postgresql() {
  echo "Starting PostgreSQL dump/restore migration..."

  # Start new temporary Postgres container, bind mounting the host dir to the detected data path
  # Use POSTGRES_HOST_AUTH_METHOD=trust so psql inside container won't ask for password (temporary).
  echo "Starting new Postgres container '${NEW_CONTAINER}' from image '${IMAGE}' on network '${NETWORK}'..."
  docker run -d \
    --name "${NEW_CONTAINER}" \
    --network "${NETWORK}" \
    -v "${MIG_DIR}":"${DATA_MOUNT_PATH}" \
    -e POSTGRES_PASSWORD="${NEW_PASSWORD}" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    "${IMAGE}" >/dev/null

  echo "Waiting for new Postgres to become ready..."
  # Wait for postgres to accept connections (use psql inside container)
  MAX_RETRIES=30
  i=0
  until docker exec "${NEW_CONTAINER}" pg_isready -q >/dev/null 2>&1; do
    i=$((i+1))
    if [ ${i} -ge ${MAX_RETRIES} ]; then
      echo "New Postgres did not become ready after ${MAX_RETRIES} attempts."
      exit 2
    fi
    sleep 1
  done
  echo "New Postgres is ready."

  # Run the migration:
  # Use the NEW image's pg_dumpall to connect to the OLD DB, pipe to docker exec psql -U postgres running inside the new container.
  # We set PGPASSWORD for the pg_dumpall command to allow non-interactive auth for the old DB.
  echo "Starting dump from OLD (${OLD_NAME}:${OLD_PORT}) and restore into NEW (${NEW_CONTAINER}:5432)..."

  # Build the env prefix for old password if provided
  if [ -n "${OLD_PASSWORD}" ]; then
    # We'll pass PGPASSWORD into the docker run that runs pg_dumpall
    OLD_PW_ENV="-e PGPASSWORD=${OLD_PASSWORD}"
  else
    OLD_PW_ENV=""
  fi

  # Use the NEW IMAGE to run pg_dumpall (so the newer client's pg_dumpall drives the dump)
  # The command runs: docker run --rm --network $NETWORK $IMAGE pg_dumpall -h $OLD_NAME -p $OLD_PORT -U $OLD_USER
  # and pipes into: docker exec -i $NEW_CONTAINER psql -U postgres
  set -o pipefail
  if docker run --rm --network "${NETWORK}" ${OLD_PW_ENV} "${IMAGE}" \
       pg_dumpall -h "${OLD_NAME}" -p "${OLD_PORT}" -U "${OLD_USER}" 2> >(sed 's/^/[pg_dumpall] /' >&2) \
     | docker exec -i "${NEW_CONTAINER}" psql -U postgres 2> >(sed 's/^/[psql] /' >&2); then
    echo "Dump and restore completed successfully."
  else
    echo "ERROR: dump/restore failed. Check the logs above for details."
    exit 3
  fi
}

# Main migration logic based on database type and operation mode
case "$DB_TYPE" in
  postgresql)
    migrate_postgresql
    ;;
  mariadb)
    if [ -n "$OLD_DATA_PATH" ]; then
      migrate_mariadb_inplace_upgrade
    else
      migrate_mariadb_dump_restore
    fi
    ;;
  mysql)
    # MySQL uses same logic as MariaDB for dump/restore
    if [ -n "$OLD_DATA_PATH" ]; then
      echo "Error: In-place upgrade is not supported for MySQL. Use MariaDB image for upgrades."
      exit 1
    else
      migrate_mariadb_dump_restore
    fi
    ;;
  *)
    echo "Error: Unsupported database type: $DB_TYPE"
    exit 1
    ;;
esac

# After successful migration: stop and remove the temporary container but keep the data dir to inspect
echo "Stopping and removing temporary container ${NEW_CONTAINER} (data left at ${MIG_DIR})..."
docker rm -f "${NEW_CONTAINER}" >/dev/null

# Clear trap but still print path
trap - EXIT
echo "Migration finished. Migrated data is on host at: ${MIG_DIR}"
echo "You can now mount '${MIG_DIR}' into a service (or start a container mounting it as ${DATA_MOUNT_PATH}) to inspect the migrated DB."

# Provide database-specific examples
case "$DB_TYPE" in
  postgresql)
    echo "Example (start a read-only check):"
    echo "  docker run -it --rm -v ${MIG_DIR}:${DATA_MOUNT_PATH}:ro ${IMAGE} psql -U postgres -c '\\l'"
    ;;
  mariadb|mysql)
    echo "Example (start a read-only check):"
    echo "  docker run -it --rm -v ${MIG_DIR}:${DATA_MOUNT_PATH}:ro ${IMAGE} mysql -u root -p${NEW_PASSWORD} -e 'SHOW DATABASES;'"
    ;;
esac

exit 0
