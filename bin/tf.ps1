<#
.SYNOPSIS
    Entrypoint for every Terraform operation in this repository.

.DESCRIPTION
    Resolves a layer name to its root directory, wires in that layer's committed backend
    configuration, and gates apply and destroy behind a typed confirmation.

    The gate is not there because Terraform is dangerous. It is there because a change to a
    FedRAMP boundary should be a deliberate act with a record, and typing the layer name is
    the cheapest possible form of that record.

.PARAMETER Layer
    Layer name without its numeric prefix: foundation, network, cluster, governance,
    identity, workload.

.PARAMETER Command
    Terraform subcommand: init, validate, plan, apply, destroy, output, fmt.

.EXAMPLE
    bin/tf.ps1 foundation plan
    bin/tf.ps1 network apply
    bin/tf.ps1 network output dns_zone_nameservers
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Layer,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateSet('init', 'validate', 'plan', 'apply', 'destroy', 'output', 'fmt')]
    [string]$Command,

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$Rest,

    [Parameter()]
    [string]$Environment = 'production'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

# Layer name to directory. Written down rather than globbed so a typo fails here with a
# usable message instead of somewhere deeper with a confusing one.
$layers = @{
    foundation = '0-foundation'
    network    = '1-network'
    cluster    = '2-cluster'
    governance = '3-governance'
    identity   = '4-identity'
    workload   = '5-workload'
}

if (-not $layers.ContainsKey($Layer)) {
    $known = ($layers.Keys | Sort-Object) -join ', '
    throw "Unknown layer '$Layer'. Known layers: $known"
}

$layerDir = Join-Path $repoRoot "layers/$($layers[$Layer])"
if (-not (Test-Path $layerDir)) {
    throw "Layer directory not found: $layerDir. It may not be built yet."
}

$backendConfig = Join-Path $layerDir "envs/$Environment/backend.hcl"

# Destructive operations get a typed confirmation naming the layer and environment. An
# answer of 'yes' is deliberately not accepted -- the point is to make the operator read
# what they are about to change.
if ($Command -in @('apply', 'destroy')) {
    $expected = "$Layer/$Environment"
    Write-Host ""
    Write-Host "About to $Command layer '$Layer' in environment '$Environment'." -ForegroundColor Yellow
    if ($Command -eq 'destroy') {
        Write-Host "This DESTROYS the resources in that layer." -ForegroundColor Red
    }
    $answer = Read-Host "Type '$expected' to continue"
    if ($answer -ne $expected) {
        Write-Host "Confirmation did not match. Nothing was run." -ForegroundColor Yellow
        exit 1
    }
}

if ($Command -eq 'init') {
    if (-not (Test-Path $backendConfig)) {
        throw "Backend config not found: $backendConfig"
    }
    # Backend configuration is passed from a committed file rather than derived. An
    # explicit key is auditable in a way a computed one is not.
    & terraform "-chdir=$layerDir" init "-backend-config=$backendConfig" @Rest
}
else {
    & terraform "-chdir=$layerDir" $Command @Rest
}

exit $LASTEXITCODE
