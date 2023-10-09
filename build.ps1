# 1. PowerShell (admin): "Get-ExecutionPolicy -list" - change to "Unrestricted" (https://learn.microsoft.com/ru-ru/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.3)
# for LOCAL MAHINE and CURRENT USER
# 2. Put build.ps1 , docker-compose.bpm-db.yml , docker-compose.bpm-linux.yml inside work catalogue: /Creatio_7.18.5.1501/.
# 3. Replace backup name in ./db/backup_name.backup (contains only lowercase, without ".") like $PostgreSqlDbBackup
# 4. Use $PostgreSqlUser = as owner db in backup

# Compatible with Windows host and Docker v4 (compose v >3.9) 
# Tested with 7_18_5_1501_SalesEnterprise_Linux_Softkey_PostgreSQL_ENU_NetCore

# GLOBAL VARIABLES
# containers
$PostgreSqlContainer = "bpm_postgres"
$ContainerNames = @($PostgreSqlContainer, "bpm_pgadmin", "bpm_redis", "bpm_linux")
$DbComposeFile = "docker-compose.bpm-db.yml"
$BpmConstructorComposeFile = "docker-compose.bpm-linux.yml"
# psql
$PostgreSqlHost = "postgres-15-3"
$PostgreSqlPort = 5432
$PostgreSqlAdminUser = "postgres"
$PostgreSqlAdminPassword = "postgres"
$PostgreSqlUser = "puser"
$PostgreSqlPassword = "Creatio+"
$PostgreSqlDb = "creatio_7185_sales_enterprise_linux"
$PostgreSqlDbBackup = "db/creatio_7185_sales_enterprise_linux.backup"
# redis
$RedisHost = "redis-7"
$RedisPort = 6379
$RedisPassword = "redispwd"
$RedisDb = 1

# DB connection strings
$PostgreSqlConnectionString = "Pooling=True;Database=$PostgreSqlDb;Host=$PostgreSqlHost;Port=$PostgreSqlPort;Username=$PostgreSqlUser;Password=$PostgreSqlPassword;Timeout=500;Command Timeout=400"
$RedisConnectionString = "host=$RedisHost;db=$RedisDb;port=$RedisPort;password=$RedisPassword"

function ClearLastExitCode {
    $Global:LASTEXITCODE = 0
}

function CheckLastErrorCode() {
    param([int] $ScriptExitCode)

    if ($Global:LASTEXITCODE -ne 0) {
        Write-Host "Last command error exit code: $LASTEXITCODE, terminating script"
        Exit $ScriptExitCode
    }
}

function CheckContainers() {
    Write-Output "Checking exiting conatiners"

    foreach ($name in $ContainerNames) {
        $checkContainerCmdOutput = docker ps -q -f name="$name"

        CheckLastErrorCode -ScriptExitCode -1

        if ($checkContainerCmdOutput) {
            Write-Output "Container $name exists. Please remove container $name and try again."
            Exit -2
        }
    }
    Write-Host "Done"
}

function CreateDbContainers {
    Write-Host "Creating DB conatiners"
    docker compose -f $DbComposeFile up -d
    Write-Host "Done"
    CheckLastErrorCode -ScriptExitCode -3
}
function CreatePostgreSqlUser {
    Write-Host "Creating PostgreSQL user $PostgreSqlUser"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \""`
    DO`
    \`$\`$`
    BEGIN`
        IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$PostgreSqlUser') THEN`
            RAISE EXCEPTION 'Role $PostgreSqlUser already exists';`
        ELSE`
            CREATE ROLE $PostgreSqlUser LOGIN PASSWORD '$PostgreSqlPassword';`
        END IF;`
    END`
    \`$\`$;\"""
    Write-Host "Done"
    CheckLastErrorCode -ScriptExitCode -4
}

function CreatePostgreSqlDb {
    Write-Host "Creating PostgreSQL DB $PostgreSqlDb"

    docker exec bpm_postgres /bin/sh -c "psql -U $PostgreSqlAdminUser -c \""`
    DO`
    \`$\`$`
    BEGIN`
       CREATE EXTENSION IF NOT EXISTS dblink;`
       IF EXISTS (SELECT FROM pg_database WHERE datname = '$PostgreSqlDb') THEN`
          RAISE EXCEPTION 'Database $PostgreSqlDb exists';
       ELSE
          PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE $PostgreSqlDb WITH OWNER = $PostgreSqlUser ENCODING = ''UTF8''');
       END IF;
    END
    \`$\`$;\"""
    Write-Host "Done"
    CheckLastErrorCode -ScriptExitCode -5
}

function RestorePostgreSqlDb {
    Write-Host "Restoring PostgreSQL DB $PostgreSqlDb from backup $PostgreSqlDbBackup"

    docker exec -i -e PGPASSWORD=$PostgreSqlAdminPassword $PostgreSqlContainer pg_restore --host $PostgreSqlHost --port $PostgreSqlPort --username=$PostgreSqlAdminUser --dbname=$PostgreSqlDb /$PostgreSqlDbBackup
    Write-Host "Done"
    CheckLastErrorCode -ScriptExitCode -6
}

function CreateBpmContainer {
    Write-Host "Creating BPM Constructor conatiner"
    docker compose -f $BpmConstructorComposeFile up -d
    Write-Host "Done"
    CheckLastErrorCode -ScriptExitCode -7
}

function UpdateFile() {
    param (
        [string] $Path,
        [string] $SearchPattern,
        [string] $ReplacePattern
    )

    Write-Host "Updating file $Path"

    $fileContent = Get-Content -Path $Path
    $selectString = ($fileContent | Select-String -Pattern "(.*)($SearchPattern)(.*)")

    if ($selectString.Matches.Count -gt 0) {
        $replaceString = $selectString.Matches[0].Groups[1].Value + $ReplacePattern + $selectString.Matches[0].Groups[3].Value
        $updatedFileContent = $fileContent -replace [Regex]::Escape($selectString.Line), $replaceString
        $updatedFileContent | Set-Content -Path $Path -Encoding UTF8
    }
    Write-Host "Done. Current value: $ReplacePattern"
    CheckLastErrorCode -ScriptExitCode -8
}

# Main script flow

ClearLastExitCode
CheckContainers
CreateDbContainers
CreatePostgreSqlUser
CreatePostgreSqlDb
RestorePostgreSqlDb
UpdateFile -Path "Terrasoft.WebHost.dll.config" -SearchPattern '<fileDesignMode enabled="false" />' -ReplacePattern '<fileDesignMode enabled="true" />'
UpdateFile -Path "Terrasoft.WebHost.dll.config" -SearchPattern '<add key="UseStaticFileContent" value="true" />' -ReplacePattern '<add key="UseStaticFileContent" value="false" />'
UpdateFile -Path "Terrasoft.WebHost.dll.config" -SearchPattern '<add key="CookiesSameSiteMode" value="None" />' -ReplacePattern '<add key="CookiesSameSiteMode" value="Lax" />'
UpdateFile -Path "ConnectionStrings.config" -SearchPattern '<add name="db" connectionString=".*" />' -ReplacePattern "<add name=`"db`" connectionString=`"$PostgreSqlConnectionString`" />"
UpdateFile -Path "ConnectionStrings.config" -SearchPattern '<add name="redis" connectionString=".*" />' -ReplacePattern "<add name=`"redis`" connectionString=`"$RedisConnectionString`" />"
CreateBpmContainer
