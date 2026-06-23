# Local Keycloak Setup for AMCOS OIDC Testing

This directory contains a Docker Compose configuration and realm definition for running Keycloak locally, so OpenID Connect authentication works without connecting to the production CAVE server.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose plugin)

## Quick Start

From the **repository root**, run:

```bash
docker compose up -d
```

Keycloak will be available at:  
`http://localhost:8080/auth`

The `cave` realm and its test users are imported automatically on first startup.

---

## Keycloak Admin Console

| URL | `http://localhost:8080/auth/admin` |
|-----|-------------------------------------|
| Username | `admin` |
| Password | `admin` |

---

## Test Users (cave realm)

| Username | Password | Role |
|---|---|---|
| `admin.user` | `Password1!` | `amcos-admin` |
| `test.user` | `Password1!` | `amcos-user` |

---

## Configuring the Application

Update your local `Web.config` (AMCOS.Web) or `appsettings.json` (AMCOS.Web.Core) with:

| Setting | Value |
|---|---|
| `KeyCloakAuthority` / `Authority` | `http://localhost:8080/auth/realms/cave` |
| `KeyCloakClientId` / `ClientId` | `amcos-local` |
| `KeyCloakClientSecret` / `ClientSecret` | `local-dev-secret` |
| `AmcosUrl` | `https://localhost:5001/signin-oidc` (or your local callback URL) |
| `CaveUrl` | `https://localhost:5001/` |
| `Environment` | `InternalTest` (to enable real OIDC flow) |

### Web.config snippet

```xml
<add key="Environment" value="InternalTest" />
<add key="KeyCloakClientId" value="amcos-local" />
<add key="KeyCloakAuthority" value="http://localhost:8080/auth/realms/cave" />
<add key="AmcosUrl" value="https://localhost:5001/amcos/oidc-callback" />
<add key="CaveUrl" value="https://localhost:5001/" />
```

Set `KeyCloakClientSecret` in `secureAppSettings`:

```xml
<add key="KeyCloakClientSecret" value="local-dev-secret" />
```

### appsettings.json snippet (AMCOS.Web.Core)

```json
{
  "OpenIdConnect": {
    "Authority": "http://localhost:8080/auth/realms/cave",
    "ClientId": "amcos-local",
    "ClientSecret": "local-dev-secret"
  },
  "AppSettings": {
    "Environment": "InternalTest"
  },
  "AmcosUrl": "https://localhost:5001/signin-oidc",
  "CaveUrl": "https://localhost:5001/"
}
```

> **Note:** If your local app runs on a different port, update the redirect URIs in the `amcos-local` client via the Keycloak admin console or edit `cave-realm.json` before starting Keycloak.

---

## Stopping Keycloak

```bash
docker compose down
```

To also remove the database volume (full reset):

```bash
docker compose down -v
```

## Realm Configuration

`cave-realm.json` defines:

- **Realm**: `cave`
- **Client**: `amcos-local` (confidential, authorization code flow)
- **Realm roles**: `amcos-admin`, `amcos-user`
- **Protocol mappers**: `roles`, `groups`, `department`, `accountType` claims — matching what `KeyCloakHelper.cs` expects
- **Test users**: `admin.user` (admin) and `test.user` (standard user)

To make changes, either edit the JSON before first startup or use the admin console and re-export the realm via:  
**Realm Settings → Action → Partial export**
