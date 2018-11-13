---
title: ProdCom
layout: document
parent: ['Documentation', '../documentation.html']
toc: true
---

## Sources
https://github.com/Statoil/ProdCom

_Old source_
http://svn.statoil.no/other/pdm/

## Contacts
  - Vivek Kumar Rai
  - Kristoffer Steen
  - Morten Pedersen (MORTEPE)

## Notes
The following from Startup.cs
```cs
services.Configure<MvcOptions>(options =>
{
    options.Filters.Add(new RequireHttpsAttribute());
});
```

seems to not work with Traefik ingress controller - it results in a 302 redirect even if you access using HTTPS (internal traffic is HTTP)

Appsettings containing dots will not allow us to override settings using config maps or secrets since dots arent allowed in *nix environment variables.

```cs
  "ConnectionStrings": {
    "pdm.database": ""
  }
```

Suggest using _ instead or just name it better ;)

Otherwise, we could mount appsettings.json as a ConfigMap and override the entire thing (dot names work in code, just not when overridden from environment variables).
If it contains connectionstrings (which ProdCom does) it needs to be a Secret rather than ConfigMap.
Renaming the properties will allow us to extract specific settings as secrets instead of the whole thing.

## Build & deployment experience

### One way that works for our CI/CD pipeline
  * Create a secret in k8s that stores the connection string used in ''prodcom.api/appsettings.json''.
  * Add a user in ''allowedUsers'' list inside ''prodcom.api/Startup.cs'' file.
  * Remove the following code from ''prodcom.api/Startup.cs'':
    ```cs
      services.Configure<MvcOptions>(options =>
      {
          options.Filters.Add(new RequireHttpsAttribute());
      });
    ```
  * Add a ''Jenkinsfile'' that mounts the k8s secret file and modify ''pdm.database'' value inside the ''prodcom.api/appsettings.json'' file with the connection string value from the mounted secret file, e.g.:
    ```
      def connectionString = readFile '/etc/secrets/connection_strings.txt'
      connectionString = "\"" + connectionString + "\""
      sh "{ sed -i \'s/\"\"/${connectionString}/g\' prodcom.api/appsettings.json; } 2> /dev/null"
    ```