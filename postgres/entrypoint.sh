#!/bin/ash
cd /home/container

# Output current postgres version
postgres --version

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

function wait-port {
    local port=${1:-$SERVER_PORT}
    until nc -z 127.0.0.1 $port ; do
        sleep 1
    done
}

DATA_DIR="/home/container/postgres_db"
NEW_VERSION="${PG_VERSION:-18}"

mkdir -p "$DATA_DIR"

# Check version status
if [ -f "$DATA_DIR/PG_VERSION" ]; then
    OLD_VERSION=$(cat "$DATA_DIR/PG_VERSION")
else
    OLD_VERSION=""
fi

echo "Old version: $OLD_VERSION"
echo "New version: $NEW_VERSION"

# -------------------------------------------------------------------
# Auto-Initialize PostgreSQL if the database files do not exist yet
# -------------------------------------------------------------------
if [ ! -f "$DATA_DIR/postgresql.conf" ]; then
    echo "No PostgreSQL configuration found at $DATA_DIR. Initializing DB..."

    # Run initdb using standard input for the password (Ash compatible)
    echo "${PGPASSWORD:-postgres}" | initdb -D "$DATA_DIR" -U "${PGUSER:-postgres}" -A md5 --pwfile=-

    # Save current version file
    echo "$NEW_VERSION" > "$DATA_DIR/PG_VERSION"
    echo "Database initialized successfully!"
fi
# -------------------------------------------------------------------

# Ensure remote connection rules are present in pg_hba.conf
if [ -f "$DATA_DIR/pg_hba.conf" ] && ! grep -q "# Custom rules" "$DATA_DIR/pg_hba.conf"; then
    echo -e "# Custom rules\nhost    all             all             0.0.0.0/0               md5" >> "$DATA_DIR/pg_hba.conf"
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}

# Ensure the server has a clean exit
pg_ctl -D "$DATA_DIR" stop