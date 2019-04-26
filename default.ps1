Include "\\rchinas301\projects\IT Development\DevShared\Production\Build\Current\RJO.Build.Functions.ps1"

properties {
  $global:configuration = "Release"
  $majorWithReleaseVersion = "1.0.0"
  $publishNuget = $false
  $nugetPrereleaseTag = "alpha"

  $nowarn = "1607,1573,1591" # ignore missing / bad documentation
  $constants = ""
  $treatWarningsAsErrors = $false
    
  $nugetVersion = GetNugetVersion $majorWithReleaseVersion $nugetPrereleaseTag
  $assemblyVersion = GetAssemblyVersion $majorWithReleaseVersion $nugetPrereleaseTag

  $baseDir = Resolve-Path ..
  # $buildDir = "$baseDir"
  $sourceDir = "$baseDir\PushSharp"
  $toolsDir = "$baseDir\tools"
  $workingDir = "$baseDir\build"
  $workingSourceDir = "$workingDir"
  $packageDir = "$workingDir\package"
  
  $nugetExe = Resolve-RjoNuGet
}

framework '4.6'

task default -depends Package

task Clean {
  Emit-Step "Cleaning working directories"
  
  if (Test-Path -Path $workingDir)
  {
    Emit-SubStep "Deleting existing working directory $workingDir"
    Execute-Command -Command { Remove-Item $workingDir -Recurse -Force }
  }

  Emit-SubStep "Creating working directory where build activity will occur: $workingDir"
  New-Item -Path $workingDir -ItemType Directory | Out-Null
}

task Build {
  Emit-Step "Building the application and running tests"
  
  Emit-SubStep "Copying source to working source directory $workingSourceDir"
  robocopy $sourceDir $workingSourceDir /MIR /NP /XD bin obj tools *.ps1 build .vs artifacts .svn /XF *.suo *.user *.lock.json | Out-Null

  Emit-SubStep "Updating assembly version"
  Update-AssemblyInfoFiles $workingSourceDir $assemblyVersion $nugetVersion

  Emit-Step "Restoring NuGet packages"
  # restore
  exec { & "$nugetExe" restore "$workingDir\PushSharp.sln" }
  Emit-Step "Building PushSharp.sln"

  exec { msbuild "/t:Clean;Rebuild" "/p:NoWarn=`"$nowarn`"" "/p:Configuration=$global:configuration" "/p:Platform=Any CPU" "/p:PlatformTarget=AnyCPU" "/p:TreatWarningsAsErrors=$treatWarningsAsErrors" "/p:VisualStudioVersion=14.0" /p:DefineConstants=`"$constants`" "$workingDir\PushSharp.sln" | Out-Default } "Error building PushSharp solution"
}

task Test -depends Build {
  Emit-Step "Executing tests in tests assemblies"

  $testsDLL = $workingDir + "\PushSharp.Tests\bin\" + $global:configuration + "\PushSharp.Tests.dll"
  Emit-Step "Running NUnit tests PushSharp.Tests"
  Emit-Step "$testsDLL"
  # don't run these PushSharp integration tests that require internet connection to providers 
  exec { & "$toolsDir\nunit\nunit-console.exe" "$testsDLL" /exclude:Disabled,Real /xml:$workingDir\TestResults.xml | Out-Default } "Error running PushSharp.Tests tests"
}

task Package -depends Test {
  Emit-Step "Packaging and possibly publishing NuGet packages"
  
  Emit-Step "Prepping Rjo.PushSharp NuGet package"
  
  New-Item -Path "$packageDir\Rjo.PushSharp" -ItemType Directory | Out-Null
  New-Item -Path "$packageDir\Rjo.PushSharp\lib\net46" -ItemType Directory | Out-Null
  Copy-Item -Path "$workingDir\Rjo.PushSharp.nuspec" -Destination "$packageDir\Rjo.PushSharp\Rjo.PushSharp.nuspec"
  Edit-NuspecValues "$packageDir\Rjo.PushSharp\Rjo.PushSharp.nuspec" "Rjo.PushSharp" $nugetVersion

  # Gather DLLs
  $conf = $global:configuration
  $dest = "$packageDir\Rjo.PushSharp\lib\net46"

  # (files as listed in original PushSharp.nuspec)
  Copy-Item -Path "$workingDir\PushSharp.Core\bin\$conf\PushSharp.Core.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Amazon\bin\$conf\PushSharp.Amazon.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Apple\bin\$conf\PushSharp.Apple.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Firefox\bin\$conf\PushSharp.Firefox.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Windows\bin\$conf\PushSharp.Windows.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Google\bin\$conf\PushSharp.Google.dll" -Destination $dest
  Copy-Item -Path "$workingDir\PushSharp.Blackberry\bin\$conf\PushSharp.Blackberry.dll" -Destination $dest

  # ------------------------------------------------------------------
  
  Emit-SubStep "Building Rjo.PushSharp NuGet package with version $nugetVersion"
  Package-RjoNuGet -nuspecPath "$packageDir\Rjo.PushSharp\Rjo.PushSharp.nuspec" -outputdirectory $workingDir
  
  if ($publishNuget)
  {
    Publish-RjoNuGet "$workingDir\Rjo.PushSharp.$nugetVersion.nupkg"
  }
  else
  {
    Emit-SubStep "Skipping publish to NuGet"
  }
  
  Write-Host
}
