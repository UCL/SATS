$here = Split-Path $script:MyInvocation.MyCommand.Path -Parent
Function Import-AssemblyFile($file)
{
    $fileStream = ([System.IO.FileInfo] (Get-Item $file)).OpenRead();
    $assemblyBytes = new-object byte[] $fileStream.Length
    $fileStream.Read($assemblyBytes, 0, $fileStream.Length) | Out-Null;
    $fileStream.Close();
    $assemblyLoaded = [System.Reflection.Assembly]::Load($assemblyBytes) ;
}

Function Import-LibAssembly($file)
{
    $path = join-path $here "\lib\" 
    $path = join-path $path $file
    Import-AssemblyFile $path
}

Import-LibAssembly "NLog.dll"
Import-LibAssembly "NLog.Targets.Redis.dll"
Import-LibAssembly "ServiceStack.Common.dll"
Import-LibAssembly "ServiceStack.Redis.dll"
Import-LibAssembly "ServiceStack.Text.dll"

Function Get-Logger([String]$Name)
{
	return [NLog.LogManager]::GetLogger($Name)
}


$nLogConfigPath = Join-Path $here "nlog.config"
[NLog.LogManager]::Configuration = New-Object "NLog.Config.XmlLoggingConfiguration" $nLogConfigPath, $true

