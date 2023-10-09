#!/bin/bash

# Global variables
PostgreSqlContainer="bpm_postgres"
ContainerNames=("bpm_postgres" "bpm_pgadmin" "bpm_redis" "bpm_constructor")
DbComposeFile="docker-compose.bpm-db.yml"
BpmConstructorComposeFile="docker-compose.bpm-constructor.yml"
PostgreSqlHost="postgres-15-3"
PostgreSqlPort=5432
PostgreSqlAdminUser="postgres"
PostgreSqlAdminPassword="postgres"
PostgreSqlUser="puser"
PostgreSqlPassword="BPMSoft+"
PostgreSqlDb="creatio_7185_sales_enterprise_linux"
PostgreSqlDbBackup="db/creatio_7185_sales_enterprise_linux.backup"
RedisHost="redis-7"
RedisPort=6379
RedisPassword="redispwd"
RedisDb=1
DbPuser="puser"
DbPuserPass="creatio+"

# DB connection strings
PostgreSqlConnectionString="Pooling=True;Database=$PostgreSqlDb;Host=$PostgreSqlHost;Port=$PostgreSqlPort;Username=$PostgreSqlUser;Password=$PostgreSqlPassword;Timeout=500;Command Timeout=400"
RedisConnectionString="host=$RedisHost;db=$RedisDb;port=$RedisPort;password=$RedisPassword"

function clear_last_exit_code {
    LASTEXITCODE=0
}

function check_last_error_code {
    local ScriptExitCode=$1

    if [ $LASTEXITCODE -ne 0 ]; then
        echo "Last command error exit code: $LASTEXITCODE, terminating script"
        exit $ScriptExitCode
    fi
}

function check_containers {
    echo "Checking existing containers"

    for name in "${ContainerNames[@]}"; do
        local checkContainerCmdOutput
        checkContainerCmdOutput=$(docker ps -q -f name="$name")

        check_last_error_code -1

        if [ -n "$checkContainerCmdOutput" ]; then
            echo "Container $name exists. Please remove container $name and try again."
            exit -2
        fi
    done
}

function create_db_containers {
    echo "Creating DB containers"
    docker compose -f $DbComposeFile up -d
    check_last_error_code -3
}

function create_postgresql_user_bad {
    echo "Creating PostgreSQL user $PostgreSqlUser"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \"
    DO
    \$$
    BEGIN
        IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$PostgreSqlUser') THEN
            RAISE EXCEPTION 'Role $PostgreSqlUser already exists';
        ELSE
            CREATE ROLE $PostgreSqlUser LOGIN PASSWORD '$PostgreSqlPassword';
        END IF;
    END
    \$$;\""

    check_last_error_code -4
}
function create_postgresql_user {
    echo "Creating PostgreSQL user $PostgreSqlUser"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \"CREATE ROLE $PostgreSqlUser LOGIN PASSWORD '$PostgreSqlPassword';\""

    check_last_error_code -4
}

function create_postgresql_user_puser {
    echo "Creating PostgreSQL user $DbPuser"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \"
    DO
    \$$
    BEGIN
        IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DbPuser') THEN
            RAISE EXCEPTION 'Role $DbPuser already exists';
        ELSE
            CREATE ROLE $DbPuser LOGIN PASSWORD '$DbPuserPass';
        END IF;
    END
    \$$;\""

    check_last_error_code -4
}

function create_postgresql_db_bad {
    echo "Creating PostgreSQL DB $PostgreSqlDb"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \"
    DO
    \$$
    BEGIN
       CREATE EXTENSION IF NOT EXISTS dblink;
       IF EXISTS (SELECT FROM pg_database WHERE datname = '$PostgreSqlDb') THEN
          RAISE EXCEPTION 'Database $PostgreSqlDb exists';
       ELSE
          PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE $PostgreSqlDb WITH OWNER = $PostgreSqlUser ENCODING = ''UTF8''');
       END IF;
    END
    \$$;\""

    check_last_error_code -5
}

function create_postgresql_db {
    echo "Creating PostgreSQL DB $PostgreSqlDb"

    docker exec bpm_postgres psql -U $PostgreSqlAdminUser -c "CREATE DATABASE $PostgreSqlDb WITH OWNER = $PostgreSqlUser ENCODING = 'UTF8'"

    check_last_error_code -5
}

function restore_postgresql_db {
    echo "Restoring PostgreSQL DB $PostgreSqlDb from backup $PostgreSqlDbBackup"

    docker exec -i -e PGPASSWORD=$PostgreSqlAdminPassword $PostgreSqlContainer pg_restore --host $PostgreSqlHost --port $PostgreSqlPort --username=$PostgreSqlAdminUser --dbname=$PostgreSqlDb /$PostgreSqlDbBackup
    check_last_error_code -6
}

function create_bpm_container {
    echo "Creating BPM Constructor container"
    docker compose -f $BpmConstructorComposeFile up -d
    check_last_error_code -7
}

function update_file {
    local Path=$1
    local SearchPattern=$2
    local ReplacePattern=$3

    echo "Updating file $Path"

    local fileContent
    fileContent=$(cat "$Path")
    local selectString
    selectString=$(echo "$fileContent" | grep -E "(.*)($SearchPattern)(.*)")

    if [ $(echo "$selectString" | wc -l) -gt 0 ]; then
        local replaceString
        replaceString=$(echo "$selectString" | sed "s/$SearchPattern/$ReplacePattern/")
        echo "$fileContent" | sed "s/$selectString/$replaceString/" > "$Path"
    fi

    check_last_error_code -8
}

# Main script flow

clear_last_exit_code
check_containers
create_db_containers
create_postgresql_user
#create_postgresql_user_puser
create_postgresql_db
restore_postgresql_db
#update_file "Terrasoft.WebHost.dll.config" '<fileDesignMode enabled="false" />' '<fileDesignMode enabled="true" />'
#update_file "Terrasoft.WebHost.dll.config" '<add key="UseStaticFileContent" value="true" />' '<add key="UseStaticFileContent" value="false" />'
#update_file "ConnectionStrings.config" '<add name="db" connectionString=".*" />' "<add name=\"db\" connectionString=\"$PostgreSqlConnectionString\" />"
#update_file "ConnectionStrings.config" '<add name="redis" connectionString=".*" />' "<add name=\"redis\" connectionString=\"$RedisConnectionString\" />"
create_bpm_container
