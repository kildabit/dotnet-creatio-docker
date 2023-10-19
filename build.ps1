# 1. PowerShell (admin): "Get-ExecutionPolicy -list" - change to "Unrestricted" (https://learn.microsoft.com/ru-ru/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.3)
# for LOCAL MAHINE and CURRENT USER
# 2. Put build.ps1 , docker-compose.creatio-db.yml , docker-compose.creatio-linux.yml inside work catalogue: /Creatio_7.18.5.1501/.
# 3. Replace backup name in ./db/backup_name.backup (contains only lowercase, without ".") like $PostgreSqlDbBackup
# 4. Use $PostgreSqlUser = as owner db in backup

# Compatible with Windows host and Docker v4 (compose v >3.9) 
# Tested with 7_18_5_1501_SalesEnterprise_Linux_Softkey_PostgreSQL_ENU_NetCore

# GLOBAL VARIABLES

$ProjectName = "creatio"
$ApplicationDockerComposeOutputName = "docker-compose.creatio-linux.yml"
$EnvironmentDockerComposeOutputName = "docker-compose.creatio-db.yml"


# ---------------------------
$PostgreSqlContainer = "${ProjectName}_postgres"
$ContainerNames = @($PostgreSqlContainer, "${ProjectName}_pgadmin", "${ProjectName}_redis", "${ProjectName}_linux")
$DbComposeFile = "$EnvironmentDockerComposeOutputName"
$CreatioComposeFile = "$ApplicationDockerComposeOutputName"
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

# network 
$DockerNetwork = "${ProjectName}_environment_service_network"
$NetworkIP = 172.24.0.0/16

# DB connection strings
$PostgreSqlConnectionString = "Pooling=True;Database=$PostgreSqlDb;Host=$PostgreSqlHost;Port=$PostgreSqlPort;Username=$PostgreSqlUser;Password=$PostgreSqlPassword;Timeout=500;Command Timeout=400"
$RedisConnectionString = "host=$RedisHost;db=$RedisDb;port=$RedisPort;password=$RedisPassword"

function ClearLastExitCode {
    $Global:LASTEXITCODE = 0
}

function CheckLastErrorCode() {
    param([int] $ScriptExitCode)

    if ($Global:LASTEXITCODE -ne 0) {
        Write-Host "Last command error exit code: $LASTEXITCODE, terminating script" -ForegroundColor DarkRed
        Exit $ScriptExitCode
    }
}
function GenerateEnvComposeFromTemplate {
    $ContainerNameCompose = "${ProjectName}_environment"
    $PostgresContainerName = "${ProjectName}_postgres"
    $PgAdminContainerName = "${ProjectName}_pgadmin"
    $RedisContainerName = "${ProjectName}_redis"
    $NetworkNameCompose = "${ProjectName}_environment_service_network"

    # Загрузите содержимое Docker Compose файла
    $dockerComposeContent = Get-Content -Path "docker-compose.creatio-db-template.yml"

    # Замените <container_name> на значение из PowerShell
    $dockerComposeContent = $dockerComposeContent -replace "<%= environment_name %>", $ContainerNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= postgres_container_name %>", $PostgresContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= pgadmin_container_name %>", $PgAdminContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= redis_container_name %>", $RedisContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= network_name %>", $NetworkNameCompose

    # Сохраните обновленное содержимое в новом файле
    $dockerComposeContent | Set-Content -Path "$EnvironmentDockerComposeOutputName"
    Write-Host "Docker-compose file (env) generated! $EnvironmentDockerComposeOutputName" -ForegroundColor Cyan
}
function GenerateAppComposeFromTemplate {
    $ContainerNameCompose = "${ProjectName}_linux"
    $SystemNameCompose = "${ProjectName}_system"
    $HostNameCompose = "${ProjectName}-linux"
    $NetworkNameCompose = "${ProjectName}_environment_service_network"

    # Загрузите содержимое Docker Compose файла
    $dockerComposeContent = Get-Content -Path "docker-compose.creatio-linux-template.yml"

    # Замените <container_name> на значение из PowerShell
    $dockerComposeContent = $dockerComposeContent -replace "<%= name %>", $SystemNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= container_name %>", $ContainerNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= hostname %>", $HostNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= network_name %>", $NetworkNameCompose

    # Сохраните обновленное содержимое в новом файле
    $dockerComposeContent | Set-Content -Path "$ApplicationDockerComposeOutputName"
    Write-Host "Docker-compose file (app) generated! $ApplicationDockerComposeOutputName" -ForegroundColor Cyan
}
function RenameDbBackup {
    
    $pathToBackup = "db/"
    $FileNameExtension = ".backup"
    
    $BackupFile = Get-ChildItem -Path $pathToBackup -Filter *$FileNameExtension
    
    
    if ($BackupFile.Count -eq 1) {
            $OldName = $BackupFile.Name
            $NewName = "$PostgreSqlDb.backup"
            $OldFullPath = $BackupFile.FullName
            $NewFullPath = Join-Path -Path $pathToBackup -ChildPath $NewName

            Rename-Item -Path $OldFullPath -NewName $NewName
            Write-Host "Backup File '$OldName' renamed '$NewName' succesfully." -ForegroundColor Green
    } 
    elseif ($BackupFile.Count -eq 0) {
            Write-Host "File with extension '$FileNameExtension' not found." -ForegroundColor Red
    } 
    else {
            Write-Host "There are more then 1 file  *.'$FileNameExtension' in pathToBackup." -ForegroundColor Red
    
    }
    Write-Host "Done" -ForegroundColor Green
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -10
}
function CheckContainers() {
    Write-Host "Checking exiting conatiners" -ForegroundColor Magenta

    foreach ($name in $ContainerNames) {
        $checkContainerCmdOutput = docker ps -q -f name="$name"

        CheckLastErrorCode -ScriptExitCode -1

        if ($checkContainerCmdOutput) {
            Write-Host "Container $name exists. Please remove container $name and try again." -ForegroundColor Red
            Exit -2
        }
    }
    Write-Host "Done" -ForegroundColor Green
    Write-Host " "
}
function CreateNetwork {
    Write-Host "Start creating network for app and env. Name : $DockerNetwork " -ForegroundColor Magenta
    
    $networkInfo = docker network inspect $DockerNetwork -f '{{.Name}}'
    if ($networkInfo -eq $DockerNetwork) {
        Write-Host "Network $DockerNetwork already exists." -ForegroundColor Red
    }
    else {
        Write-Host "Creating network ' $DockerNetwork ' for app and environment"
        docker network create --driver bridge --subnet $NetworkIP $DockerNetwork
        Write-Host "Network created!" -ForegroundColor Green
    }
    CheckLastErrorCode -ScriptExitCode -3
}

function CreateDbContainers {
    Write-Host "Creating DB conatiners" -ForegroundColor Magenta
    docker compose -f $DbComposeFile up -d
    Write-Host "Done" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -4
}
function CreatePostgreSqlUser {
    Write-Host "Creating PostgreSQL user $PostgreSqlUser" -ForegroundColor Magenta

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
    Write-Host "Done" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -5
}

function CreatePostgreSqlDb {
    Write-Host "Creating PostgreSQL DB $PostgreSqlDb" -ForegroundColor Magenta

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
    Write-Host "Done" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -6
}

function RestorePostgreSqlDb {
    Write-Host "Restoring PostgreSQL DB $PostgreSqlDb from backup $PostgreSqlDbBackup" -ForegroundColor Magenta

    docker exec -i -e PGPASSWORD=$PostgreSqlAdminPassword $PostgreSqlContainer pg_restore --host $PostgreSqlHost --port $PostgreSqlPort --username=$PostgreSqlAdminUser --dbname=$PostgreSqlDb /$PostgreSqlDbBackup
    Write-Host "Done" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -7
}

function CreateBpmContainer {
    Write-Host "Creating Application conatiner" -ForegroundColor Magenta
    docker compose -f $CreatioComposeFile up -d
    Write-Host "Done" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -8
}

function UpdateFile() {
    param (
        [string] $Path,
        [string] $SearchPattern,
        [string] $ReplacePattern
    )

    Write-Host "Updating file $Path" -ForegroundColor Magenta

    $fileContent = Get-Content -Path $Path
    $selectString = ($fileContent | Select-String -Pattern "(.*)($SearchPattern)(.*)")

    if ($selectString.Matches.Count -gt 0) {
        $replaceString = $selectString.Matches[0].Groups[1].Value + $ReplacePattern + $selectString.Matches[0].Groups[3].Value
        $updatedFileContent = $fileContent -replace [Regex]::Escape($selectString.Line), $replaceString
        $updatedFileContent | Set-Content -Path $Path -Encoding UTF8
    }
    Write-Host "Done. Current value: $ReplacePattern" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -9
}

# Main script flow

ClearLastExitCode
GenerateEnvComposeFromTemplate
GenerateAppComposeFromTemplate
CheckContainers
CreateNetwork
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
