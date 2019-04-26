param($task = "default")

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath

get-module psake | remove-module

import-module (Get-ChildItem "\\rchinas301\projects\IT Development\DevShared\3rdParty\Applications\psake\latest\psake.psm1" | Select-Object -First 1)

exec { invoke-psake "$scriptDir\default.ps1" $task }
