param(
 [Parameter(Mandatory=$true)]
 [ValidateSet('create','synth','route','audit','open','archive')]
 [string]$Step,
 [string]$VivadoBin=$env:VIVADO_BIN
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
if($VivadoBin){$taskVivado=Join-Path $VivadoBin 'vivado.bat'}
else {
 $taskCommand=Get-Command vivado.bat -ErrorAction SilentlyContinue
 if(-not $taskCommand){throw 'Pass -VivadoBin or set VIVADO_BIN to the Vivado 2024.1 bin directory.'}
 $taskVivado=$taskCommand.Source
}
if(-not (Test-Path -LiteralPath $taskVivado)){throw "Vivado launcher missing: $taskVivado"}
$taskScripts=@{create='create_project.tcl';synth='verify_implementation.tcl';route='route_candidate.tcl';audit='audit_routed.tcl';open='open_design.tcl';archive='package_project.tcl'}
$taskMode='batch'
if($Step -eq 'open'){$taskMode='gui'}
$taskBuild=Join-Path $taskRoot 'build'
New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
Push-Location $taskBuild
try {
 & $taskVivado -mode $taskMode -source (Join-Path $PSScriptRoot $taskScripts[$Step]) -log ($Step+'.log') -journal ($Step+'.jou')
 if($LASTEXITCODE -ne 0){throw "Vivado step failed: $Step"}
} finally {Pop-Location}
