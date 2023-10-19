# Compatible with Windows host and Docker v4 (compose v >3.9) 
# Tested with 7_18_5_1501_SalesEnterprise_Linux_Softkey_PostgreSQL_ENU_NetCore

# GLOBAL VARIABLES
# EDIT ONLY $ProjectName and (if requiered) $NetworkIP 
# [!] DO NOT USE U-P-P-E-R-C-A-S-E in $ProjectName [!]
$ProjectName = "demo"
$NetworkIP = '172.24.0.0/16'
$ApplicationDockerComposeOutputName = "docker-compose_creatio-linux.yml"
$EnvironmentDockerComposeOutputName = "docker-compose_creatio-db.yml"

# ---------------------------
#Containers
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
# DB connection strings
$PostgreSqlConnectionString = "Pooling=True;Database=$PostgreSqlDb;Host=$PostgreSqlHost;Port=$PostgreSqlPort;Username=$PostgreSqlUser;Password=$PostgreSqlPassword;Timeout=500;Command Timeout=400"
$RedisConnectionString = "host=$RedisHost;db=$RedisDb;port=$RedisPort;password=$RedisPassword"

# Steps counter
$Global:CurrentStep = 0
$Global:TotalSteps = 15

#FUNCTIONS
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
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Generate Environment docker-compose from template" -ForegroundColor Magenta
    $ContainerNameCompose = "${ProjectName}_environment"
    $PostgresContainerName = "${ProjectName}_postgres"
    $PgAdminContainerName = "${ProjectName}_pgadmin"
    $RedisContainerName = "${ProjectName}_redis"
    $NetworkNameCompose = "${ProjectName}_environment_service_network"

    # Get context from template
    $dockerComposeContent = Get-Content -Path "docker-compose.creatio-db-template.yml"

    # Updating context in template
    $dockerComposeContent = $dockerComposeContent -replace "<%= environment_name %>", $ContainerNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= postgres_container_name %>", $PostgresContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= pgadmin_container_name %>", $PgAdminContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= redis_container_name %>", $RedisContainerName
    $dockerComposeContent = $dockerComposeContent -replace "<%= network_name %>", $NetworkNameCompose

    # Create docker-compose for this project
    $dockerComposeContent | Set-Content -Path "$EnvironmentDockerComposeOutputName"
    Write-Host "Docker-compose file (env) generated! $EnvironmentDockerComposeOutputName" -ForegroundColor Cyan
    Write-Host " "
}
function GenerateAppComposeFromTemplate {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Generate Application docker-compose from template" -ForegroundColor Magenta
    $ContainerNameCompose = "${ProjectName}_linux"
    $SystemNameCompose = "${ProjectName}_system"
    $HostNameCompose = "${ProjectName}-linux"
    $NetworkNameCompose = "${ProjectName}_environment_service_network"

    # Get context from template
    $dockerComposeContent = Get-Content -Path "docker-compose.creatio-linux-template.yml"

    # Updating context in template
    $dockerComposeContent = $dockerComposeContent -replace "<%= name %>", $SystemNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= container_name %>", $ContainerNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= hostname %>", $HostNameCompose
    $dockerComposeContent = $dockerComposeContent -replace "<%= network_name %>", $NetworkNameCompose

    # Create docker-compose for this project
    $dockerComposeContent | Set-Content -Path "$ApplicationDockerComposeOutputName"
    Write-Host "Docker-compose file (app) generated! $ApplicationDockerComposeOutputName" -ForegroundColor Cyan
    Write-Host " "
}
function RenameDbBackup {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Renaming db backup file" -ForegroundColor Magenta
    
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
            Exit -$CurrentStep
    } 
    else {
            Write-Host "There are more then 1 file  *.'$FileNameExtension' in pathToBackup." -ForegroundColor Red
            Exit -$CurrentStep    
    }
    #Write-Host "Done" -ForegroundColor Green
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -10
}
function CheckContainers() {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Checking the existence of containers" -ForegroundColor Magenta

    foreach ($name in $ContainerNames) {
        $checkContainerCmdOutput = docker ps -q -f name="$name"

        CheckLastErrorCode -ScriptExitCode -$CurrentStep

        if ($checkContainerCmdOutput) {
            Write-Host "Container $name exists. Please remove container $name and try again." -ForegroundColor Red
            Exit -$CurrentStep
        }
    }
    Write-Host "All OK. Done" -ForegroundColor Green
    Write-Host " "
}
function CreateNetwork {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Creating network for app and env. Name : $DockerNetwork " -ForegroundColor Magenta
    
    $networkInfo = docker network inspect $DockerNetwork -f '{{.Name}}'
    if ($networkInfo -eq $DockerNetwork) {
        Write-Host "Network $DockerNetwork already exists! " -ForegroundColor Red -NoNewline
        Write-Host "Skip creating network" -ForegroundColor Cyan
        CheckLastErrorCode -ScriptExitCode -$CurrentStep
    }
    else {
        Write-Host "Creating network ' $DockerNetwork ' for app and environment"
        docker network create --driver bridge --subnet $NetworkIP $DockerNetwork
        Write-Host "Network created!" -ForegroundColor Green
    }
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
    Write-Host " "
}
function CreateDbContainers {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Creating DB conatiners" -ForegroundColor Magenta
    docker compose -f $DbComposeFile up -d
    Write-Host "Done" -ForegroundColor Green
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}
function CreatePostgreSqlUser {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Creating PostgreSQL user $PostgreSqlUser" -ForegroundColor Magenta

    docker exec "${ProjectName}_postgres" /bin/sh -c "psql -U $PostgreSqlAdminUser -c \""`
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
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}
function CreatePostgreSqlDb {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Creating PostgreSQL DB $PostgreSqlDb" -ForegroundColor Magenta

    docker exec "${ProjectName}_postgres" /bin/sh -c "psql -U $PostgreSqlAdminUser -c \""`
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
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}
function RestorePostgreSqlDb {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Restoring PostgreSQL DB " -ForegroundColor Magenta -NoNewline
    Write-Host "'$PostgreSqlDb' " -ForegroundColor DarkCyan -NoNewline
    Write-Host "from backup " -ForegroundColor Magenta -NoNewline
    Write-Host "'$PostgreSqlDbBackup' " -ForegroundColor DarkCyan

    docker exec -i -e PGPASSWORD=$PostgreSqlAdminPassword $PostgreSqlContainer pg_restore --host $PostgreSqlHost --port $PostgreSqlPort --username=$PostgreSqlAdminUser --dbname=$PostgreSqlDb /$PostgreSqlDbBackup
    Write-Host "Done" -ForegroundColor Green
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}
function UpdateFile() {
    param (
        [string] $Path,
        [string] $SearchPattern,
        [string] $ReplacePattern
    )
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Updating file" -ForegroundColor Magenta -NoNewline
    Write-Host "'$Path'" -ForegroundColor DarkCyan

    $fileContent = Get-Content -Path $Path
    $selectString = ($fileContent | Select-String -Pattern "(.*)($SearchPattern)(.*)")

    if ($selectString.Matches.Count -gt 0) {
        $replaceString = $selectString.Matches[0].Groups[1].Value + $ReplacePattern + $selectString.Matches[0].Groups[3].Value
        $updatedFileContent = $fileContent -replace [Regex]::Escape($selectString.Line), $replaceString
        $updatedFileContent | Set-Content -Path $Path -Encoding UTF8
    }
    Write-Host "Done. Current value: " -ForegroundColor Green
    Write-Host "'$ReplacePattern'" -ForegroundColor DarkCyan
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}
function CreateAppContainer {
    $Global:CurrentStep++
    Write-Host "[$CurrentStep/$TotalSteps] " -NoNewline -ForegroundColor DarkYellow
    Write-Host "Creating Application conatiner" -ForegroundColor Magenta
    docker compose -f $CreatioComposeFile up -d
    Write-Host "Done" -ForegroundColor Green
    Write-Host " "
    CheckLastErrorCode -ScriptExitCode -$CurrentStep
}


# MAIN SCRIPT FLOW

ClearLastExitCode
GenerateEnvComposeFromTemplate
GenerateAppComposeFromTemplate
RenameDbBackup
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
CreateAppContainer
