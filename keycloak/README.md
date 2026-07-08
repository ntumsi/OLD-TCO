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
`http://localhost:8180/auth`

The `cave` realm and its test users are (re)imported automatically on **every**
`docker compose up` by the one-shot `keycloak-config` service, which runs
`kc.sh import --override=true` before Keycloak starts. Editing `cave-realm.json`
and re-running `docker compose up -d` is enough to apply the change — no volume
reset needed. (Because the import overrides, any users/clients you create by hand
in the admin console are wiped on the next `up`; put anything you want to keep in
`cave-realm.json`.)

---

## Keycloak Admin Console

| URL | `http://localhost:8180/auth/admin` |
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
| `KeyCloakAuthority` / `Authority` | `http://localhost:8180/auth/realms/cave` |
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
    "Authority": "http://localhost:8180/auth/realms/cave",
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

> **Note:** If your local app runs on a different port, add its redirect URI to the `amcos-local` client in `cave-realm.json` and re-run `docker compose up -d` — the `keycloak-config` importer re-applies the realm with `--override=true`, so the change takes effect without a volume reset.

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

To make changes, edit `cave-realm.json` and run `docker compose up -d` — the
`keycloak-config` importer re-applies the realm with `--override=true` on every
startup, so edits take effect immediately (no volume reset). To capture changes
made in the admin console back into the file, re-export via
**Realm Settings → Action → Partial export** (note: un-exported console changes
are overwritten on the next `up`).
