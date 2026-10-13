[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [string]$Payload = '', [string]$Sha256 = '', [long]$Size = 0,
    [int]$WaitPid = 0, [string]$RestartArgsJson = '', [switch]$Recover
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$guardStream = $null
$locked = $false
$ownsDownload = $false
$swapAttempted = $false
$installed = $false
$tempFile = ''
$receiptTemp = ''
$downloadOwner = 0

function Assert-Path([string]$Path) {
    if (![IO.Path]::IsPathRooted($Path)) { throw 'Paths must be absolute.' }
    $native = $Path.Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
    $full = [IO.Path]::GetFullPath($native)
    if ($full -cne $native) { throw 'Non-canonical path refused.' }
    $part = $full
    while ($part) {
        $leaf = [IO.Path]::GetFileName($part)
        if ($leaf.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { throw 'Invalid path component.' }
        $item = Get-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Reparse point refused: $part"
        }
        $part = [IO.Path]::GetDirectoryName($part)
    }
    return $full
}
function Assert-Regular([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (!($item -is [IO.FileInfo]) -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Regular file required: $Path"
    }
}
function Assert-Stage {
    foreach ($path in @($Target, $fixedPayload, $backup, $oldReceipt, $currentReceipt, $newReceipt, $handoff, $pending, $lock, $guard, $ownerFile)) {
        $null = Assert-Path $path
    }
    if (![IO.Directory]::Exists($stage)) { throw 'Staging directory missing.' }
    foreach ($directory in @($previous, $download, $lock)) {
        if ((Test-Path -LiteralPath $directory) -and ![IO.Directory]::Exists($directory)) { throw 'Invalid staging directory.' }
    }
    foreach ($path in @($Target, $fixedPayload, $backup, $oldReceipt, $currentReceipt, $newReceipt, $handoff, $pending, $guard, $ownerFile)) {
        if (Test-Path -LiteralPath $path) { Assert-Regular $path }
    }
    # Fixed children and no reparse ancestors guarantee the same Windows volume.
}
function Test-Running([int]$ProcessId) {
    if ($ProcessId -le 0) { return $false }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }
    $process.Dispose()
    return $true
}
function Read-Owner([string]$Path) {
    Assert-Regular $Path
    $value = [IO.File]::ReadAllText($Path).Trim()
    if ($value -cnotmatch '\A[1-9][0-9]{0,9}\z') { throw 'Invalid lock owner.' }
    return [int]::Parse($value)
}
function Read-Hash([string]$Path) {
    if (![IO.File]::Exists($Path)) { return '' }
    Assert-Regular $Path
    $value = [IO.File]::ReadAllText($Path).Trim()
    if ($value -cnotmatch '\A[0-9a-f]{64}\z') { throw 'Invalid hash receipt.' }
    return $value
}
function Get-Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Flush-File([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
    try { $stream.Flush($true) } finally { $stream.Dispose() }
}
function Publish-File([string]$Source, [string]$Destination) {
    if ([IO.File]::Exists($Destination)) { [IO.File]::Replace($Source, $Destination, [NullString]::Value) }
    else { [IO.File]::Move($Source, $Destination) }
}
function Write-Receipt([string]$Path, [string]$Value) {
    $script:receiptTemp = [IO.Path]::Combine($stage, '.receipt-' + [guid]::NewGuid().ToString('N'))
    $bytes = [Text.Encoding]::ASCII.GetBytes($Value + "`n")
    $stream = [IO.File]::Open($receiptTemp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    Publish-File $receiptTemp $Path
    $script:receiptTemp = ''
}
function Test-DownloadOwned {
    $null = Assert-Path $ownerFile
    if (![IO.Directory]::Exists($download)) { return $false }
    $owner = Read-Owner $ownerFile
    if ($owner -ne $downloadOwner) { return $false }
    if (($WaitPid -gt 0 -and $owner -eq $WaitPid) -or ($WaitPid -eq 0 -and !(Test-Running $owner))) {
        return $true
    }
    return $false
}
function Release-Download {
    if (Test-DownloadOwned) {
        [IO.File]::Delete($ownerFile)
        [IO.Directory]::Delete($download)
    }
}
function Quote-NativeArgument([string]$Argument) {
    # PowerShell 5.1 lacks ArgumentList; follow Windows argv quoting, never a shell.
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}
function Assert-Payload {
    Assert-Stage
    Assert-Regular $Target
    Assert-Regular $Payload
    if ((Get-Item -LiteralPath $Payload -Force).Length -ne $Size) { throw 'Payload size mismatch.' }
    if ((Get-Hash $Payload) -cne $Sha256) { throw 'Payload SHA256 mismatch.' }
}

try {
    if ($WaitPid -lt 0) { throw 'Invalid PID.' }
    if ($Recover) { $WaitPid = 0 }
    elseif ($Sha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $Size -le 0) { throw 'Invalid SHA256 or size.' }
    $Target = Assert-Path $Target
    $targetDir = [IO.Path]::GetDirectoryName($Target)
    $stage = [IO.Path]::Combine($targetDir, '.hullwatch-update')
    $previous = [IO.Path]::Combine($stage, 'previous')
    $backup = [IO.Path]::Combine($previous, [IO.Path]::GetFileName($Target))
    $oldReceipt = $backup + '.sha256'
    $newReceipt = [IO.Path]::Combine($stage, 'expected-new.sha256')
    $currentReceipt = [IO.Path]::Combine($stage, 'expected-old.sha256')
    $handoff = [IO.Path]::Combine($stage, 'handoff')
    $pending = [IO.Path]::Combine($stage, 'pending')
    $lock = [IO.Path]::Combine($stage, 'apply.lock')
    $guard = [IO.Path]::Combine($stage, 'apply.guard')
    $download = [IO.Path]::Combine($stage, 'download.lock')
    $ownerFile = [IO.Path]::Combine($download, 'owner_pid')
    $fixedPayload = [IO.Path]::Combine($stage, 'payload')
    $null = Assert-Path $stage
    if ($Recover -and !(Test-Path -LiteralPath $stage)) { exit 0 }
    Assert-Stage
    # Kernel ownership ends on crash. It serializes stale apply.lock reclamation.
    $guardStream = [IO.File]::Open($guard, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::None)
    if ([IO.Directory]::Exists($lock)) {
        $applyOwner = Assert-Path ([IO.Path]::Combine($lock, 'owner_pid'))
        if ([IO.File]::Exists($applyOwner)) {
            if (Test-Running (Read-Owner $applyOwner)) { throw 'Another installer is active.' }
            [IO.File]::Delete($applyOwner)
        }
        [IO.Directory]::Delete($lock)
    }
    # CreateDirectory performs the native mkdir while the exclusive guard is held.
    $null = [IO.Directory]::CreateDirectory($lock)
    $locked = $true
    [IO.File]::WriteAllText([IO.Path]::Combine($lock, 'owner_pid'), [string]$PID)
    if ($Recover) {
        if (![IO.File]::Exists($handoff)) { exit 0 }
        if ([IO.Directory]::Exists($download)) {
            $downloadOwner = Read-Owner $ownerFile
            if (Test-Running $downloadOwner) { throw 'Handoff owner is still running.' }
        }
        $ownsDownload = $true
        $oldHash = Read-Hash $oldReceipt
        $currentOldHash = Read-Hash $currentReceipt
        $newHash = Read-Hash $newReceipt
        $validCurrent = $false
        if ([IO.File]::Exists($Target)) {
            $currentHash = Get-Hash $Target
            $validCurrent = $currentHash -ceq $oldHash -or $currentHash -ceq $currentOldHash -or $currentHash -ceq $newHash
        }
        if (!$validCurrent) {
            if ((!$oldHash -and !$currentOldHash) -or ![IO.File]::Exists($backup)) {
                throw 'No verified prior executable; recovery left untouched.'
            }
            $backupHash = Get-Hash $backup
            if ($backupHash -cne $oldHash -and $backupHash -cne $currentOldHash) { throw 'Prior executable hash mismatch; recovery left untouched.' }
            $oldHash = $backupHash
            $tempFile = [IO.Path]::Combine($previous, '.restore-' + [guid]::NewGuid().ToString('N'))
            [IO.File]::Copy($backup, $tempFile, $false)
            if ((Get-Hash $tempFile) -cne $oldHash) { throw 'Recovery copy hash mismatch.' }
            Flush-File $tempFile
            Publish-File $tempFile $Target
            $tempFile = ''
            $currentHash = $oldHash
        }
        [IO.File]::Delete($fixedPayload)
        [IO.File]::Delete($handoff)
        # Preserve a new build's pending marker until the parent acknowledges GUI boot.
        if ($currentHash -cne $newHash) { [IO.File]::Delete($pending) }
        exit 0
    }
    $Payload = Assert-Path $Payload
    if (![string]::Equals($Payload, $fixedPayload, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Payload must use the fixed staging path.'
    }
    if (![IO.File]::Exists($handoff) -or ![IO.Directory]::Exists($download)) { throw 'Missing download handoff/lock.' }
    $owner = Read-Owner $ownerFile
    $downloadOwner = $owner
    if (($WaitPid -gt 0 -and $owner -ne $WaitPid) -or ($WaitPid -eq 0 -and (Test-Running $owner))) {
        throw 'Unrelated or running download owner.'
    }
    $ownsDownload = $true
    [string[]]$restartArgs = @()
    if ($RestartArgsJson) {
        $RestartArgsJson = Assert-Path $RestartArgsJson
        Assert-Regular $RestartArgsJson
        $json = [IO.File]::ReadAllText($RestartArgsJson)
        $null = ConvertFrom-Json -InputObject $json
        $decoded = ConvertFrom-Json -InputObject ('{"arguments":' + $json + '}')
        if (!($decoded.arguments -is [Array])) { throw 'Restart arguments must be a JSON array.' }
        foreach ($argument in $decoded.arguments) {
            if (!($argument -is [string]) -or $argument.Contains([char]0)) { throw 'Restart arguments must be strings without NUL.' }
        }
        $restartArgs = $decoded.arguments
    }
    Assert-Payload
    if ($WaitPid -gt 0) {
        $game = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
        if ($null -ne $game) {
            try { if (!$game.WaitForExit(30000)) { throw 'Wait timeout; running game left untouched.' } }
            finally { $game.Dispose() }
        }
    }
    Assert-Payload
    $null = [IO.Directory]::CreateDirectory($previous)
    Assert-Stage
    $oldHash = Get-Hash $Target
    Write-Receipt $currentReceipt $oldHash
    $tempFile = [IO.Path]::Combine($previous, '.previous-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::Copy($Target, $tempFile, $false)
    if ((Get-Hash $tempFile) -cne $oldHash) { throw 'Rollback copy hash mismatch; target retained.' }
    Flush-File $tempFile
    Publish-File $tempFile $backup
    $tempFile = ''
    Write-Receipt $oldReceipt $oldHash
    Write-Receipt $newReceipt $Sha256
    Write-Receipt $pending $Sha256
    # No delete-then-copy fallback. The durable prior copy also survives interruption.
    # Same-user hostile races need native open-handle validation, beyond this helper.
    $swapAttempted = $true
    [IO.File]::Replace($Payload, $Target, $backup)
    $installed = $true
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Target
    $start.WorkingDirectory = $targetDir
    $start.UseShellExecute = $false
    if ($null -ne $start.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $restartArgs) { $start.ArgumentList.Add($argument) }
    } else { $start.Arguments = (($restartArgs | ForEach-Object { Quote-NativeArgument $_ }) -join ' ') }
    $started = [Diagnostics.Process]::Start($start)
    if ($null -eq $started) { throw 'Updated executable did not start.' }
    $installed = $false
    $started.Dispose()
    exit 0
} catch {
    $failure = $_.Exception.Message
    if ($installed -or ($swapAttempted -and ![IO.File]::Exists($Target))) {
        try {
            Assert-Stage
            $oldHash = Read-Hash $oldReceipt
            if ($oldHash -and (Get-Hash $backup) -ceq $oldHash -and
                (![IO.File]::Exists($Target) -or (Get-Hash $Target) -ceq $Sha256)) {
                $tempFile = [IO.Path]::Combine($previous, '.restore-' + [guid]::NewGuid().ToString('N'))
                [IO.File]::Copy($backup, $tempFile, $false)
                if ((Get-Hash $tempFile) -cne $oldHash) { throw 'Rollback copy hash mismatch.' }
                Flush-File $tempFile
                Publish-File $tempFile $Target
                $tempFile = ''
            }
        } catch { $failure += ' Rollback retained in previous: ' + $_.Exception.Message }
    }
    [Console]::Error.WriteLine('Hullwatch update: ' + $failure)
    exit 1
} finally {
    if ($tempFile -and [IO.File]::Exists($tempFile)) { [IO.File]::Delete($tempFile) }
    if ($receiptTemp -and [IO.File]::Exists($receiptTemp)) { [IO.File]::Delete($receiptTemp) }
    if ($ownsDownload) {
        if (!$Recover -and !$swapAttempted -and (Test-DownloadOwned)) { [IO.File]::Delete($handoff); [IO.File]::Delete($pending) }
        Release-Download
    }
    if ($locked) {
        [IO.File]::Delete([IO.Path]::Combine($lock, 'owner_pid'))
        [IO.Directory]::Delete($lock)
    }
    if ($null -ne $guardStream) { $guardStream.Dispose() }
}
