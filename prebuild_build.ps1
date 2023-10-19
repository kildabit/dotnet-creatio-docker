# GLOBAL VARIABLES
$NewProjectName = "SFA"
$ProjectNameString = '$ProjectName = "$NewProjectName"'


function UpdateFile() {
    param (
        [string] $Path,
        [string] $SearchPattern,
        [string] $ReplacePattern
    )

    Write-Host "Updating file $Path" -ForegroundColor Magenta

    $fileContent = Get-Content -Path $Path
    $selectString = ($fileContent | Select-String -Pattern "(.*)($SearchPattern)(.*)")

    if ($selectString.Matches.Count -gt 0) {
        $replaceString = $selectString.Matches[0].Groups[1].Value + $ReplacePattern + $selectString.Matches[0].Groups[3].Value
        $updatedFileContent = $fileContent -replace [Regex]::Escape($selectString.Line), $replaceString
        $updatedFileContent | Set-Content -Path $Path -Encoding UTF8
    }
    Write-Host "Done. Current value: $ReplacePattern" -ForegroundColor Green
    CheckLastErrorCode -ScriptExitCode -9
}

# Main script flow


UpdateFile -Path "build.ps1" -SearchPattern '$ProjectName = "creatio"' -ReplacePattern $ProjectNameString


