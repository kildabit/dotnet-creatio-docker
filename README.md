# Скрипт создания среды Creatio на базе .NET Core (linux) + Postgres #

Скрипт предназначен для автоматического создания и запуска образов и контейнеров, необходимых для функционирования

## Требования для работы скрипта ##

На целевом хосте Windows должны быть выполнены следующие требования:
1. Установлен Docker.
2. Настроена [политика](https://learn.microsoft.com/ru-ru/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.3) запуска внешних PowerShell скриптов без подписи.

### Общий вид алгоритма: ###

1. Проверка наличия запущенных контейнеров окружения BPMSoft Constructor. В случае их обнаружения, скрипт завершает работу с ошибкой. Необходимо остановить и удалить данные контейнеры для дальнейшей работы скрипта.
2. Создание контейнеров с бэкендом: PostgreSQL, PGAdmin, Redis.
3. Создание *роли* в PostgreSQL, создание *базы данных приложения*, её *восстановление из бекапа*. 
В случе уже имеющейся роли или базы данных, скрипт завершает работу с ошибкой. Это сделано для предотвращения случайного удаления данных при восстановлении базы данных. 
4. Обновление конфигурационных файлов Приложения.
5. Создание контейнера с Приложением.

## Перед началом ##
Скрипт опирается на два Docker Compose файла:

* **docker-compose.bpm-db.yml** - отввечает за развёртывание контейнеров для бекенда (psql, redis, pgadmin)
* **docker-compose.bpm-linux.yml** - отвечает за развёртывание контенейнера приложения

Сервисы разделены на два Docker-Compose файла для удобства дальнейшего обслуживания окружения. 


## Инструкция по запуску ##
1. Настроить политику запуска скриптов:
 ![Get-ExecutionPolicy -list](<Screenshot 2023-10-09 180916-1.png>)
2. Разархивировать исходное приложение. Далее - папка разархивированного приложения будет являться **корнем (/)**.
3. Перейти в **/db**, переименовать базу в соответствии с правилами: 
    * Название не должно содерать верхний регистр, точки. Использование иных символов, кроме латиницы и "_" нерекомендовано. Данное название используется в конфигурационном файле
4. Сконфигурировать файл build.ps1 (* отмечены обязательные): 
    * Настроить названия контейнеров
    * Указать названия docker-compose файлов
    * Настроить параметры для Postgres:
        * <span style="color:lightblue">$PostgreSqlUser</span> - указать роль, как у Owner восстанавливаемой БД <span style="color:red">**\***</span>
        * <span style="color:lightblue">$PostgreSqlDb</span> - установить название БД. Название не должно содерать верхний регистр, точки. Использование иных символов, кроме латиницы и "_" нерекомендовано. <span style="color:red">**\***</span>
        * <span style="color:lightblue">$PostgreSqlDbBackup </span> - указать путь до расположения бекапа в **/db** <span style="color:red">**\***</span>

    * Настроить параметры для Redis
5. Если планируется использование данного скрипта для разворачивания на https, то необходимо убрать один элемент основого процесса скрипта: 
    ```
    UpdateFile -Path "Terrasoft.WebHost.dll.config" -SearchPattern '<add key="CookiesSameSiteMode" value="None" />' -ReplacePattern '<add key="CookiesSameSiteMode" value="Lax" />'
    ```
## Запуск приложения, доступ к pgadmin4 ##
В результате работы скрипта будет созданы контейнеры
 ![docker-containers](<Screenshot 2023-10-09 193231-1.png>)
Для запуска приложения щелкнуть по порту контейнера с приложением 5000:5000

Для подключения к pgadmin необходимо перейти из docker к адресу pgadmin на порту 80
Стандартный логин и пароль описаны в docker-compose.bpm-db.yml 

* PGADMIN_DEFAULT_EMAIL: pgadmin4@pgadmin.org
* PGADMIN_DEFAULT_PASSWORD: admin

Для подключения к базе из pgadmin необходмо узнать IP для подключения к БД.
Это можно сделать, провалившись в контейнер базы данных и на вкладке Inspect 
![DBcontainer->Inspect->Networks](<Screenshot 2023-10-09 193534-1.png>)

В pgadmin зарегистирорвать сервер (если не были указаны иные настройки для администратора БД):
* hostname/Ip = Ip базы из контейнера БД
* port = 5432
* Username = postgres
* Password = postgres 

![ConnectionToPSQL](<Screenshot 2023-10-09 194251-1.png>)

### Описание переменных настроек ###

```powershell
$PostgreSqlContainer = "bpm_postgres"
```
Задаёт имя контейнера с PostgreSQL. Имя определено в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$ContainerNames = @($PostgreSqlContainer, "bpm_pgadmin", "bpm_redis", "bpm_linux")
```

Задаёт имена всех контейнеров в окружении. Имена определены в файлах [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml) и [docker-compose.bpm-linux.yml](docker-compose.bpm-linux.yml).

```powershell
$DbComposeFile = "docker-compose.bpm-db.yml"
```

Задаёт имя Docker Compose файла для контейнеров бэкенда.

```powershell
$BpmConstructorComposeFile = "docker-compose.bpm-constructor.yml"
```

Задаёт имя Docker Compose файла для контейнера Creatio.

```powershell
$PostgreSqlHost = "postgres-15-3"
```

Задаёт имя хоста PostgreSql. Имя определено в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$PostgreSqlPort = 5432
```

Задаёт номер порта PostgreSql. Номер определён в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$PostgreSqlAdminUser = "postgres"
```

Задаёт имя пользователя с правами администратора в PostgreSql. Имя по умолчанию определено в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$PostgreSqlAdminPassword = "postgres"
```

Задаёт пароль пользователя с правами администратора в PostgreSql. Пароль по умолчанию определён в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$PostgreSqlUser = "puser"
```

Задаёт имя пользователя, создаваемого в PostgreSql. Он будет являться владельцем базы данных BPMSoft Constructor.

```powershell
$PostgreSqlPassword = "Creatio+"
```

Задаёт пароль пользователя, создаваемого в PostgreSql.

```powershell
$PostgreSqlDb = "creatio_7185_sales_enterprise_linux.backup"
```

Задаёт имя базы данных Creatio, создаваемой в PostgreSql.  **Не использовать верхний регистр, не использовать точки и другие спецсимволы.**

```powershell
$PostgreSqlDbBackup = "db/creatio_7185_sales_enterprise_linux.backup"
```

Задаёт имя резервной копии базы данных Creatio, при помощи которой будет производиться восстановление базы данных в PostgreSql. 
Настоятельно не рекомендуется менять относительный путь файла (db/...), т.к. он соответствует расположению резервной копии базы данных, находящейся в папке с дистрибутивом.

```powershell
$RedisHost = "redis-7"
```

Задаёт имя хоста Redis. Имя определено в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$RedisPort = 6379
```

Задаёт номер порта Redis. Номер определён в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$RedisPassword = "redispwd"
```

Задаёт пароль в Redis. Пароль по умолчанию определён в файле [docker-compose.bpm-db.yml](docker-compose.bpm-db.yml).

```powershell
$RedisDb = 1
```

Задаёт номер базы данных Redis, используемой BPMSoft Constructor.
