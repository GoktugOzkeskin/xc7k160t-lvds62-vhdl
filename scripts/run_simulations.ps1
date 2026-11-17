param([string]$VivadoBin=$env:VIVADO_BIN)
$ErrorActionPreference='Stop'
$taskBin=$VivadoBin
if(-not $taskBin){
 $taskTool=Get-Command xvhdl.bat -ErrorAction SilentlyContinue
 if(-not $taskTool){throw 'Pass -VivadoBin or set VIVADO_BIN to the Vivado 2024.1 bin directory.'}
 $taskBin=Split-Path $taskTool.Source -Parent
}
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskRun=Join-Path $taskRoot 'build/sim'
New-Item -ItemType Directory -Path $taskRun -Force | Out-Null
Push-Location $taskRun
try {
 $taskRtl=@('lvds_pkg.vhd','lvds_rx_align.vhd','lvds_compare.vhd','lvds_test_bank.vhd','lvds_bidir_phy.vhd','lvds_clocking.vhd','lvds_result_summary.vhd') | ForEach-Object {Join-Path $taskRoot ('rtl\'+$_)}
 & (Join-Path $taskBin 'xvhdl.bat') @taskRtl
 if($LASTEXITCODE -ne 0){throw 'VHDL RTL compilation failed'}
 $taskTests=Get-ChildItem -LiteralPath (Join-Path $taskRoot 'sim') -Filter '*.vhd' | ForEach-Object {$_.FullName}
 & (Join-Path $taskBin 'xvhdl.bat') --2008 @taskTests
 if($LASTEXITCODE -ne 0){throw 'VHDL testbench compilation failed'}
 foreach($taskCase in @('compare','align','bank','ready','result','phy','system')) {
  & (Join-Path $taskBin 'xelab.bat') ('tb_'+$taskCase) -L unisim -s ($taskCase+'_vhdl')
  if($LASTEXITCODE -ne 0){throw ('Elaboration failed '+$taskCase)}
  & (Join-Path $taskBin 'xsim.bat') ($taskCase+'_vhdl') -runall -log ($taskCase+'_vhdl.log')
  if($LASTEXITCODE -ne 0){throw ('Simulator failed '+$taskCase)}
  $taskLog=Get-Content -LiteralPath ($taskCase+'_vhdl.log') -Raw
  if($taskLog -notmatch 'PASS:' -or $taskLog -match 'Failure:|Fatal:'){throw ('Simulation failed '+$taskCase)}
 }
 'ALL SEVEN VHDL SIMULATIONS PASSED'
} finally {Pop-Location}
