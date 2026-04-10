# Run once per environment after Bicep deploys PostgreSQL + the Container App user-assigned MI.
# Prerequisites: Azure CLI, rdbms-connect extension (`az extension add --name rdbms-connect --upgrade`),
# signed in with an account that can create AAD principals on PostgreSQL.
#
# IMPORTANT: Running from your laptop requires your public IPv4 on the PostgreSQL firewall.
# Either use -AllowMyIp (see below) or run from Azure Cloud Shell, or add a rule in the Portal.
#
# Usage (PowerShell):
#   cd <repo-root>
#   $env:PG_SERVER = "pg-restrev-dev-...."
#   $env:PG_DATABASE = "restaurants_reviews"
#   $env:MI_NAME = "id-restrev-dev"
#   $env:PG_RESOURCE_GROUP = "rg-restrev-dev"   # required when using -AllowMyIp
#   .\scripts\grant-postgres-aad-user.ps1 -AllowMyIp

[CmdletBinding()]
param(
    [switch] $AllowMyIp
)

$ErrorActionPreference = "Stop"

function Invoke-AzPostgresExecute {
    param([string[]] $CliArgs)
    & az @CliArgs
    if ($LASTEXITCODE -ne 0) {
        throw "az postgres flexible-server execute failed (exit $LASTEXITCODE). If connection timed out, use -AllowMyIp or add your public IP to the server firewall."
    }
}

if ($AllowMyIp) {
    if ([string]::IsNullOrWhiteSpace($env:PG_RESOURCE_GROUP)) {
        throw "When using -AllowMyIp, set `$env:PG_RESOURCE_GROUP to the resource group that contains the PostgreSQL server (e.g. rg-restrev-dev)."
    }
    if ([string]::IsNullOrWhiteSpace($env:PG_SERVER)) {
        throw "Set `$env:PG_SERVER before using -AllowMyIp."
    }
    $pub = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 15).ip
    if (-not $pub) { throw "Could not resolve public IP (api.ipify.org)." }
    Write-Host "Adding temporary firewall rule AllowGrantClient for your IP: $pub"
    $fwArgs = @(
        "postgres", "flexible-server", "firewall-rule", "create",
        "--resource-group", $env:PG_RESOURCE_GROUP,
        "--name", $env:PG_SERVER,
        "--rule-name", "AllowGrantClient",
        "--start-ip-address", $pub,
        "--end-ip-address", $pub
    )
    & az @fwArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Create failed (rule may already exist). Trying update..."
        $updArgs = @(
            "postgres", "flexible-server", "firewall-rule", "update",
            "--resource-group", $env:PG_RESOURCE_GROUP,
            "--name", $env:PG_SERVER,
            "--rule-name", "AllowGrantClient",
            "--start-ip-address", $pub,
            "--end-ip-address", $pub
        )
        & az @updArgs
        if ($LASTEXITCODE -ne 0) { throw "Could not create or update firewall rule AllowGrantClient." }
    }
    Start-Sleep -Seconds 5
}

$missing = @()
if ([string]::IsNullOrWhiteSpace($env:PG_SERVER)) { $missing += 'PG_SERVER' }
if ([string]::IsNullOrWhiteSpace($env:PG_DATABASE)) { $missing += 'PG_DATABASE' }
if ([string]::IsNullOrWhiteSpace($env:MI_NAME)) { $missing += 'MI_NAME' }
if ($missing.Count -gt 0) {
    throw @"
Missing environment variables: $($missing -join ', ')

Run these first in the same PowerShell session (edit server/MI names if yours differ):

  `$env:PG_SERVER = 'pg-restrev-dev-7n6mfe54ky7eq'
  `$env:PG_DATABASE = 'restaurants_reviews'
  `$env:MI_NAME = 'id-restrev-dev'

Then (from your PC, open firewall for your IP first):

  .\scripts\grant-postgres-aad-user.ps1 -AllowMyIp

Requires `$env:PG_RESOURCE_GROUP` when using -AllowMyIp.
"@
}

$adminUser = az ad signed-in-user show --query mail -o tsv
if (-not $adminUser) { throw "Could not get signed-in user mail from az ad signed-in-user show" }

$token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
if (-not $token) { throw "Could not get oss-rdbms token" }

Write-Host "Creating AAD principal for managed identity $($env:MI_NAME) on $($env:PG_SERVER)..."
$q1 = "select * from pgaadauth_create_principal('$($env:MI_NAME)', false, false);"
Invoke-AzPostgresExecute @(
    "postgres", "flexible-server", "execute",
    "--name", $env:PG_SERVER,
    "--admin-user", $adminUser,
    "--admin-password", $token,
    "--database-name", "postgres",
    "--querytext", $q1
)

Write-Host "Granting privileges on $($env:PG_DATABASE)..."
$db = $env:PG_DATABASE
$mi = $env:MI_NAME
$q2 = "GRANT CONNECT ON DATABASE ""$db"" TO ""$mi""; GRANT USAGE ON SCHEMA public TO ""$mi""; GRANT CREATE ON SCHEMA public TO ""$mi""; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ""$mi""; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ""$mi""; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ""$mi"";"
Invoke-AzPostgresExecute @(
    "postgres", "flexible-server", "execute",
    "--name", $env:PG_SERVER,
    "--admin-user", $adminUser,
    "--admin-password", $token,
    "--database-name", $env:PG_DATABASE,
    "--querytext", $q2
)

Write-Host "Done."
