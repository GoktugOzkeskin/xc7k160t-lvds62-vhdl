param([ValidateSet('create','implement','resume','sim','audit','archive','bitstream')][string]$Step='implement',[string]$VivadoBin=$env:VIVADO_BIN)
$ErrorActionPreference='Stop'
if(-not $VivadoBin){$VivadoBin=Split-Path (Get-Command vivado.bat -ErrorAction Stop).Source -Parent}
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskBuild=Join-Path $taskRoot 'build/board52'
New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
# Process API only: no GUI and no desktop input. Descendants inherit affinity.
$taskSelf=[Diagnostics.Process]::GetCurrentProcess()
$taskSelf.PriorityClass='BelowNormal'
$taskCpuCount=[Environment]::ProcessorCount
if($taskCpuCount -ge 8){$taskMask=([int64]15 -shl ($taskCpuCount-4));$taskSelf.ProcessorAffinity=[IntPtr]$taskMask}
$taskWork=$taskBuild
if($Step -ne 'sim'){
 # Vivado debug-hub insertion has a 146-character temporary-path limit on Windows.
 $taskWork=Join-Path ([IO.Path]::GetTempPath()) 'lvds52_batch'
 New-Item -ItemType Directory -Path $taskWork -Force | Out-Null
}
Push-Location $taskWork
try {
 if($Step -eq 'sim'){
  New-Item -ItemType Directory -Path sim -Force | Out-Null
  Push-Location sim
  try {
   $taskFiles=@('lvds_pkg.vhd','lvds_rx_align.vhd','lvds_compare.vhd','lvds_test_bank.vhd','lvds_bidir_phy.vhd','lvds_clocking.vhd') | ForEach-Object {Join-Path $taskRoot ('rtl/'+$_)}
   & (Join-Path $VivadoBin 'xvhdl.bat') @taskFiles (Join-Path $PSScriptRoot 'lvds52_core.vhd')
   if($LASTEXITCODE -ne 0){throw 'Board52 VHDL compilation failed'}
   & (Join-Path $VivadoBin 'xvhdl.bat') --2008 (Join-Path $PSScriptRoot 'tb_board52.vhd')
   if($LASTEXITCODE -ne 0){throw 'Board52 testbench compilation failed'}
   & (Join-Path $VivadoBin 'xelab.bat') tb_board52 -L unisim -s board52 -mt 2
   if($LASTEXITCODE -ne 0){throw 'Board52 elaboration failed'}
   & (Join-Path $VivadoBin 'xsim.bat') board52 -runall -log board52_sim.log
   if($LASTEXITCODE -ne 0){throw 'Board52 simulator failed'}
   $taskLog=Get-Content board52_sim.log -Raw
   if($taskLog -notmatch 'PASS: BOARD52 runtime' -or $taskLog -match 'Failure:|Fatal:'){throw 'Board52 functional test failed'}
  }finally{Pop-Location}
 }else{
  $taskScript=if($Step -eq 'create'){'create_board52.tcl'}elseif($Step -eq 'archive'){'package_board52.tcl'}elseif($Step -eq 'audit'){'audit_board52.tcl'}elseif($Step -eq 'bitstream'){'write_bitstream.tcl'}else{'implement_board52.tcl'}
  $taskExtra=@()
  if($Step -eq 'resume'){$taskExtra=@('-tclargs','resume')}
  & (Join-Path $VivadoBin 'vivado.bat') -mode batch -source (Join-Path $PSScriptRoot $taskScript) -log (Join-Path $taskBuild ($Step+'.log')) -journal (Join-Path $taskBuild ($Step+'.jou')) @taskExtra
  if($LASTEXITCODE -ne 0){throw ('Board52 '+$Step+' failed')}
 }
}finally{Pop-Location}
