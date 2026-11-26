<#
    NordLichtTools - helper functions shared by the onboarding / offboarding / help desk scripts.
    Pure functions only (no AD calls), so they can be unit-tested with Pester on any OS.
#>

function ConvertTo-NLUsername {
    <#
    .SYNOPSIS
        Builds a "firstname.lastname" logon name that is safe for AD (sAMAccountName max 20 chars).
    .DESCRIPTION
        German umlauts are transliterated (ae, oe, ue, ss), other accents are removed
        (e-acute -> e, c-cedilla -> c), spaces are dropped, and only a-z 0-9 . - remain.
    .EXAMPLE
        ConvertTo-NLUsername -FirstName 'Anna' -LastName 'Schmidt-Berg'   # anna.schmidt-berg
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$FirstName,
        [Parameter(Mandatory)][string]$LastName,
        [ValidateRange(5, 20)][int]$MaxLength = 20
    )

    # German transliteration. Char codes keep the file ASCII-only (safe in Windows PowerShell 5.1)
    $map = [ordered]@{
        ([string][char]0x00E4) = 'ae'   # a-umlaut
        ([string][char]0x00F6) = 'oe'   # o-umlaut
        ([string][char]0x00FC) = 'ue'   # u-umlaut
        ([string][char]0x00DF) = 'ss'   # sharp s
        ([string][char]0x0131) = 'i'    # Turkish dotless i (Yilmaz)
    }

    $clean = foreach ($part in @($FirstName, $LastName)) {
        $text = $part.Trim().ToLowerInvariant()
        foreach ($k in $map.Keys) { $text = $text.Replace($k, $map[$k]) }

        # Remove remaining accents: decompose (accented letter -> letter + mark) and drop the combining marks
        $decomposed = $text.Normalize([Text.NormalizationForm]::FormD)
        $sb = [Text.StringBuilder]::new()
        foreach ($ch in $decomposed.ToCharArray()) {
            if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
                [void]$sb.Append($ch)
            }
        }
        ($sb.ToString().ToLowerInvariant() -replace '[^a-z0-9-]', '')
    }

    if (-not $clean[0] -or -not $clean[1]) { throw "Cannot build a username from '$FirstName' '$LastName'." }

    $name = "$($clean[0]).$($clean[1])"
    if ($name.Length -gt $MaxLength) { $name = $name.Substring(0, $MaxLength).TrimEnd('.', '-') }
    return $name
}

function New-NLRandomPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically random password with upper, lower, digit and symbol.
        Ambiguous characters (0/O, 1/l/I) are left out so it can be read out on the phone.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([ValidateRange(12, 64)][int]$Length = 16)

    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!$%&*+-=?@#')
    $all  = -join $sets
    $rng  = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    # Unbiased random index in [0, max) using rejection sampling on single bytes
    $getIndex = {
        param([int]$max)
        $limit = 256 - (256 % $max)
        $buffer = [byte[]]::new(1)
        do { $rng.GetBytes($buffer) } while ($buffer[0] -ge $limit)
        return [int]($buffer[0] % $max)
    }

    try {
        $chars = [System.Collections.Generic.List[char]]::new()
        foreach ($set in $sets) { $chars.Add($set[(& $getIndex $set.Length)]) }      # one of each class
        while ($chars.Count -lt $Length) { $chars.Add($all[(& $getIndex $all.Length)]) }

        # Fisher-Yates shuffle so the guaranteed characters aren't always at the start
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $j = & $getIndex ($i + 1)
            $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
        }
        return -join $chars
    } finally {
        $rng.Dispose()
    }
}

function ConvertTo-NLSecureString {
    <# Converts a generated password to a SecureString for the AD cmdlets. #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param([Parameter(Mandatory)][string]$Text)
    $secure = [securestring]::new()
    foreach ($c in $Text.ToCharArray()) { $secure.AppendChar($c) }
    $secure.MakeReadOnly()
    return $secure
}

function Write-NLLog {
    <#
    .SYNOPSIS
        Writes a timestamped line to the console and to a daily log file (audit trail).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO',
        [string]$LogDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'logs')
    )
    if (-not (Test-Path $LogDirectory)) { New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null }
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] [{2}] {3}' -f (Get-Date), $Level, [Environment]::UserName, $Message
    Add-Content -Path (Join-Path $LogDirectory ('{0:yyyy-MM-dd}.log' -f (Get-Date))) -Value $line -Encoding UTF8

    $color = @{ INFO = 'Gray'; WARN = 'Yellow'; ERROR = 'Red'; OK = 'Green' }[$Level]
    Write-Host $line -ForegroundColor $color
}

Export-ModuleMember -Function ConvertTo-NLUsername, New-NLRandomPassword, ConvertTo-NLSecureString, Write-NLLog
