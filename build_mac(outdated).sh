#!/bin/bash

# 2. Put build_mac.sh , docker-compose.bpm-db.yml , docker-compose.bpm-linux.yml inside work catalogue: /Creatio_7.18.5.1501/.
# 3. Replace backup name in ./db/backup_name.backup (contains only lowercase, without ".") like $PostgreSqlDbBackup
# 4. Use $PostgreSqlUser = as owner db in backup

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
DockerNetwork="creatio_environment_service_network" # as docker-compose

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

function create_network {
    echo "Start creating network for app and env"

    if docker network inspect "$DockerNetwork" >/dev/null 2>&1; then
        echo "Network $DockerNetwork already exists."
    else
        echo "Network $DockerNetwork: Creating network for app and environment"
        docker network create --driver bridge --subnet 172.22.0.0/16 "$DockerNetwork"
        echo "Network created!"
    fi
    #docker network create --driver bridge $DockerNetwork     
}
function create_db_containers {
    echo "Creating DB containers"
    docker compose -f $DbComposeFile up -d
    check_last_error_code -3
}

function create_postgresql_user {
    echo "Creating PostgreSQL user $PostgreSqlUser"

    docker exec $PostgreSqlContainer /bin/sh -c "psql -U $PostgreSqlAdminUser -c \"CREATE ROLE $PostgreSqlUser LOGIN PASSWORD '$PostgreSqlPassword';\""

    check_last_error_code -4
}

function create_postgresql_db {
    echo "Creating PostgreSQL DB $PostgreSqlDb"

    docker exec $PostgreSqlContainer psql -U $PostgreSqlAdminUser -c "CREATE DATABASE $PostgreSqlDb WITH OWNER = $PostgreSqlUser ENCODING = 'UTF8'"

    check_last_error_code -5
}

function restore_postgresql_db {
    echo "Restoring PostgreSQL DB $PostgreSqlDb from backup $PostgreSqlDbBackup"

    docker exec -i -e PGPASSWORD=$PostgreSqlAdminPassword $PostgreSqlContainer pg_restore --host $PostgreSqlHost --port $PostgreSqlPort --username=$PostgreSqlAdminUser --dbname=$PostgreSqlDb /$PostgreSqlDbBackup
    check_last_error_code -6
}

function create_bpm_container {
    echo "Creating Creatio container"
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
create_network
create_db_containers
create_postgresql_user
create_postgresql_db
restore_postgresql_db
#update_file "Terrasoft.WebHost.dll.config" '<fileDesignMode enabled="false" />' '<fileDesignMode enabled="true" />'
#update_file "Terrasoft.WebHost.dll.config" '<add key="UseStaticFileContent" value="true" />' '<add key="UseStaticFileContent" value="false" />'
#update_file "ConnectionStrings.config" '<add name="db" connectionString=".*" />' "<add name=\"db\" connectionString=\"$PostgreSqlConnectionString\" />"
#update_file "ConnectionStrings.config" '<add name="redis" connectionString=".*" />' "<add name=\"redis\" connectionString=\"$RedisConnectionString\" />"
create_bpm_container
