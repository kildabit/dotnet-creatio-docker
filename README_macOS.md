# MacOS версия #
Принцип работы соответствует [Windows-версии](dotnet-creatio-docker/README.md)

Требуется доработка. Но в целом работает.

### Issues: ###
1.  Не реализованы проверки "на дурака" в SQL-запросах
2.  Не реализовано автоконфигурирование **Terrasoft.WebHost.dll.config** и **ConnectionStrings.config**

При использовании требуется донастроить вручную:
*  **Terrasoft.WebHost.dll.config** 
```shell
<fileDesignMode enabled="true" />
<add key="UseStaticFileContent" value="false" />
<add key="CookiesSameSiteMode" value="Lax" />
```
* db и redis в **ConnectionStrings.config** в соответствии с <span style="color:lightgreen"># DB connection strings</span> из скрипта

## Протестировано ##
- Docker Desktop 4.24.0 (122432)
- MacOS 13.6 (22G120)
- 7_18_5_1501_SalesEnterprise_Linux_Softkey_PostgreSQL_ENU_NetCore