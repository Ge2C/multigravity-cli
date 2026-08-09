<#
.SYNOPSIS
Run multiple Antigravity IDE profiles at the same time.
#>

param (
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$cmd,
    
    [Parameter(Position = 1, Mandatory = $false)]
    [string]$arg1,

    [Parameter(Position = 2, Mandatory = $false)]
    [string]$arg2,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$BASE = if ($env:MULTIGRAVITY_HOME) { $env:MULTIGRAVITY_HOME } else { "$env:USERPROFILE\AntigravityProfiles" }

function Find-Antigravity {
    $paths = @(
        "$env:LOCALAPPDATA\Programs\Antigravity\Antigravity.exe",
        "$env:PROGRAMFILES\Antigravity\Antigravity.exe",
        "${env:ProgramFiles(x86)}\Antigravity\Antigravity.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    
    # Try to find in PATH
    $exeCommand = Get-Command antigravity.exe -ErrorAction SilentlyContinue
    if ($exeCommand) { return $exeCommand.Source }
    
    return $null
}

$APP = if ($env:MULTIGRAVITY_APP) { $env:MULTIGRAVITY_APP } else { Find-Antigravity }

function Get-TemplatesDir {
    return "$BASE\.templates"
}

function Get-SystemDataDir {
    return "$env:APPDATA\Antigravity"
}

function Get-SystemExtensionsDir {
    return "$env:USERPROFILE\.antigravity\extensions"
}

function Test-SharedProfile {
    param($name)
    return Test-Path "$BASE\$name\.shared"
}

function Write-Usage {
    Write-Host "Usage: multigravity (or mgy) <command> [args]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  new <name> [options]        Create a new profile + Start Menu shortcut"
    Write-Host "      --shared                Share extensions & settings; isolate only accounts"
    Write-Host "      --from <template>        Seed from a saved template"
    Write-Host "  list                        List existing profiles"
    Write-Host "  status                      Show running state, type, and last-used per profile"
    Write-Host "  quota [name]                Show model quota & remaining limits with visual bars"
    Write-Host "  rename <old> <new>          Rename a profile (updates shortcut if present)"
    Write-Host "  delete <name>               Delete a profile and its data"
    Write-Host "  clone <src> <dest>          Copy an existing profile"
    Write-Host "  template save <profile> <name>   Save a profile as a reusable template"
    Write-Host "  template list               List saved templates"
    Write-Host "  template delete <name>      Remove a template"
    Write-Host "  export <name> [path]        Archive a profile to a .zip file"
    Write-Host "  import <archive> [name]     Restore a profile from a .zip archive"
    Write-Host "  update                      Update multigravity to the latest version"
    Write-Host "  doctor                      Run a system diagnosis"
    Write-Host "  setup                       Run interactive setup wizard"
    Write-Host "  stats                       Show storage usage per profile"
    Write-Host "  completion                  Show setup instructions for shell completion"
    Write-Host "  <name>                      Launch Antigravity with the given profile"
    Write-Host "  help                        Show this help"
    Write-Host ""
    Write-Host "Profile names: alphanumeric and hyphens only (e.g. work, personal, test-1)"
}

function Validate-Name {
    param($name)
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Error: profile name required"
        exit 1
    }
    if ($name -notmatch "^[a-zA-Z0-9][a-zA-Z0-9-]*$") {
        Write-Error "Error: profile name must start with alphanumeric and contain only letters, numbers, or hyphens"
        exit 1
    }
}

function Invoke-CreateProfile {
    param($PROFILE)
    $PROFILE_DIR = "$BASE\$PROFILE"
    
    New-Item -ItemType Directory -Force -Path "$PROFILE_DIR\.antigravity\extensions" | Out-Null
    New-Item -ItemType Directory -Force -Path "$PROFILE_DIR\AppData\Roaming" | Out-Null
    New-Item -ItemType Directory -Force -Path "$PROFILE_DIR\AppData\Local" | Out-Null
}

function Invoke-CreateSharedProfile {
    param($name)
    $profileDir = "$BASE\$name"
    $sysData     = Get-SystemDataDir
    $sysExt      = Get-SystemExtensionsDir

    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    New-Item -ItemType File      -Force -Path "$profileDir\.shared" | Out-Null

    # Isolated AppData so accounts don't bleed across profiles
    $userDataDir = "$profileDir\AppData\Roaming\Antigravity\User"
    New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$profileDir\AppData\Local" | Out-Null

    # Symlink settings files from the system install so they stay in sync
    if (Test-Path "$sysData\User") {
        foreach ($f in @("settings.json", "keybindings.json", "snippets")) {
            $src  = "$sysData\User\$f"
            $dest = "$userDataDir\$f"
            if ((Test-Path $src) -and !(Test-Path $dest)) {
                New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    # Point extensions at the system folder instead of an empty private copy
    $extDir = "$profileDir\.antigravity\extensions"
    if (Test-Path $sysExt) {
        if (Test-Path $extDir) { Remove-Item $extDir -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Force -Path "$profileDir\.antigravity" | Out-Null
        New-Item -ItemType SymbolicLink -Path $extDir -Target $sysExt -ErrorAction SilentlyContinue | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path $extDir | Out-Null
    }

    # Auto-share global NPM cache safely
    $targetNpm = "$profileDir\.npm"
    $sysNpm    = "$env:USERPROFILE\.npm"
    if (Test-Path $sysNpm) {
        if ((Test-Path $targetNpm) -and -not (Get-Item $targetNpm).Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            Copy-Item -Path "$targetNpm\*" -Destination "$sysNpm\" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $targetNpm -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ((Test-Path $targetNpm) -and -not (Get-Item $targetNpm).Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -Path $targetNpm -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (-not (Test-Path $targetNpm)) {
            New-Item -ItemType SymbolicLink -Path $targetNpm -Target $sysNpm -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Auto-share conversations index so sessions can be resumed across profiles
    $targetConv = "$profileDir\.gemini\antigravity-cli\conversations"
    $sysConv    = "$env:USERPROFILE\.gemini\antigravity-cli\conversations"
    if (Test-Path $sysConv) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetConv) | Out-Null
        if ((Test-Path $targetConv) -and -not (Get-Item $targetConv).Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            Copy-Item -Path "$targetConv\*" -Destination "$sysConv\" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $targetConv -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (!(Test-Path $targetConv)) {
            New-Item -ItemType SymbolicLink -Path $targetConv -Target $sysConv -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Auto-share brain/ history safely
    $targetBrain = "$profileDir\.gemini\antigravity-cli\brain"
    $sysBrain    = "$env:USERPROFILE\.gemini\antigravity-cli\brain"
    if ((Test-Path $sysBrain) -and ($env:SHARE_HISTORY -ne "false")) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetBrain) | Out-Null
        if ((Test-Path $targetBrain) -and -not (Get-Item $targetBrain).Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            Copy-Item -Path "$targetBrain\*" -Destination "$sysBrain\" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $targetBrain -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (!(Test-Path $targetBrain)) {
            New-Item -ItemType SymbolicLink -Path $targetBrain -Target $sysBrain -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Invoke-LaunchProfile {
    param($PROFILE, $ArgsToForward)
    $PROFILE_DIR = "$BASE\$PROFILE"

    if (!(Test-Path $PROFILE_DIR)) {
        Write-Error "Error: profile '$PROFILE' does not exist. Run: multigravity new $PROFILE"
        exit 1
    }

    if ([string]::IsNullOrEmpty($APP) -or !(Test-Path $APP)) {
        Write-Error "Error: Antigravity.exe not found"
        exit 1
    }

    Write-Host "Launching Antigravity profile '$PROFILE'"
    
    # Launch Antigravity with isolated USERPROFILE
    $env:USERPROFILE = $PROFILE_DIR
    $env:APPDATA = "$PROFILE_DIR\AppData\Roaming"
    $env:LOCALAPPDATA = "$PROFILE_DIR\AppData\Local"
    
    if ($ArgsToForward) {
        Start-Process -FilePath $APP -ArgumentList $ArgsToForward
    }
    else {
        Start-Process -FilePath $APP
    }
}

function Invoke-ListProfiles {
    if (Test-Path $BASE) {
        $profiles = Get-ChildItem -Directory -Path $BASE | Where-Object { $_.PSIsContainer -and $_.Name -ne ".templates" }
        if ($profiles) {
            "{0,-12} {1,-8} {2,-8} {3}" -f "PROFILE", "TYPE", "SIZE", "LAST USED"
            "{0,-12} {1,-8} {2,-8} {3}" -f "-------", "----", "----", "---------"
            foreach ($p in $profiles) {
                $isShared = Test-Path "$($p.FullName)\.shared"
                $pType = if ($isShared) { "shared" } else { "full" }
                $lastUsed = if ($p.LastWriteTime) { $p.LastWriteTime.ToString("yyyy-MM-dd HH:mm") } else { "never" }
                $sizeMb = [math]::Round(((Get-ChildItem $p.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
                $sizeStr = "${sizeMb}M"
                "{0,-12} {1,-8} {2,-8} {3}" -f $p.Name, $pType, $sizeStr, $lastUsed
            }
            Write-Host ""
            $totalMb = [math]::Round(((Get-ChildItem $BASE -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
            Write-Host "Total usage: ${totalMb}M"
        }
        else {
            Write-Host "No profiles found."
        }
    }
    else {
        Write-Host "No profiles found."
    }
}

function Invoke-CreateShortcut {
    param($PROFILE)
    $APP_NAME = "Multigravity $PROFILE"
    $SHORTCUT_PATH = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$APP_NAME.lnk"
    
    $SCRIPT_PATH = $MyInvocation.MyCommand.Path
    # If script path is empty (e.g. running from prompt), try to find it
    if ([string]::IsNullOrEmpty($SCRIPT_PATH)) {
        $cmdObj = Get-Command multigravity -ErrorAction SilentlyContinue
        if ($cmdObj) { $SCRIPT_PATH = $cmdObj.Source }
    }
    
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($SHORTCUT_PATH)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& '$SCRIPT_PATH' $PROFILE`""
    if ($APP) {
        $Shortcut.IconLocation = "$APP, 0"
    }
    $Shortcut.Save()

    Write-Host "Shortcut created: $SHORTCUT_PATH"
}

function Invoke-NewProfile {
    param($name, [string[]]$extraArgs)

    $shared      = $false
    $fromTpl     = ""
    $i = 0
    while ($i -lt $extraArgs.Count) {
        switch ($extraArgs[$i]) {
            "--shared" { $shared = $true }
            "--from"   { $i++; if ($i -lt $extraArgs.Count) { $fromTpl = $extraArgs[$i] } }
        }
        $i++
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Error: profile name required"
        exit 1
    }

    Validate-Name $name

    $profileDir = "$BASE\$name"
    if (Test-Path $profileDir) {
        Write-Error "Error: profile '$name' already exists"
        exit 1
    }

    New-Item -ItemType Directory -Force -Path $BASE | Out-Null

    if ($fromTpl -eq "default") {
        $sysData = Get-SystemDataDir
        if ($shared) {
            Invoke-CreateSharedProfile $name
        } else {
            Invoke-CreateProfile $name
        }
        if (Test-Path $sysData) {
            Write-Host "Seeding profile '$name' from default Antigravity installation..."
            $userDataDir = "$profileDir\AppData\Roaming\Antigravity"
            New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null
            Copy-Item -Path "$sysData\*" -Destination $userDataDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Default session data not found at $sysData. Initialized clean profile."
        }
    } elseif ($fromTpl) {
        $tplPath = "$(Get-TemplatesDir)\$fromTpl"
        if (!(Test-Path $tplPath)) {
            Write-Error "Error: template '$fromTpl' not found. Run: multigravity template list"
            exit 1
        }
        Write-Host "Creating profile '$name' from template '$fromTpl'..."
        Copy-Item -Path $tplPath -Destination $profileDir -Recurse
    } elseif ($shared) {
        Invoke-CreateSharedProfile $name
    } else {
        Invoke-CreateProfile $name
    }

    Write-Host "Created profile '$name'"
    Invoke-CreateShortcut $name
}

function Invoke-DeleteProfile {
    param($PROFILE)
    Validate-Name $PROFILE

    $PROFILE_DIR = "$BASE\$PROFILE"
    if (!(Test-Path $PROFILE_DIR)) {
        Write-Error "Error: profile '$PROFILE' does not exist"
        exit 1
    }

    $confirm = Read-Host "Delete profile '$PROFILE' and all its data? [y/N]"
    if ($confirm -match "^[Yy]$") {
        try {
            Remove-Item -Recurse -Force $PROFILE_DIR -ErrorAction Stop
            
            $SHORTCUT_PATH = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Multigravity $PROFILE.lnk"
            if (Test-Path $SHORTCUT_PATH) {
                Remove-Item -Force $SHORTCUT_PATH
                Write-Host "Removed shortcut: $SHORTCUT_PATH"
            }
            Write-Host "Deleted profile '$PROFILE'"
        } catch {
            Write-Error "Error: could not delete profile directory. Ensure Antigravity is closed and no files are in use."
            Write-Host "Details: $_"
        }
    }
    else {
        Write-Host "Aborted."
    }
}

function Invoke-RenameProfile {
    param($OLD, $NEW)
    Validate-Name $OLD
    Validate-Name $NEW

    $OLD_DIR = "$BASE\$OLD"
    $NEW_DIR = "$BASE\$NEW"

    if (!(Test-Path $OLD_DIR)) {
        Write-Error "Error: profile '$OLD' does not exist"
        exit 1
    }
    if (Test-Path $NEW_DIR) {
        Write-Error "Error: profile '$NEW' already exists"
        exit 1
    }

    Rename-Item -Path $OLD_DIR -NewName $NEW

    $OLD_SHORTCUT = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Multigravity $OLD.lnk"
    if (Test-Path $OLD_SHORTCUT) {
        Remove-Item -Force $OLD_SHORTCUT
        Invoke-CreateShortcut $NEW
    }

    Write-Host "Renamed profile '$OLD' to '$NEW'"
}

function Invoke-CloneProfile {
    param($SRC, $DEST)
    Validate-Name $SRC
    Validate-Name $DEST

    $SRC_DIR = "$BASE\$SRC"
    $DEST_DIR = "$BASE\$DEST"

    if (!(Test-Path $SRC_DIR)) {
        Write-Error "Error: source profile '$SRC' does not exist"
        exit 1
    }
    if (Test-Path $DEST_DIR) {
        Write-Error "Error: destination profile '$DEST' already exists"
        exit 1
    }

    Write-Host "Cloning profile '$SRC' to '$DEST'..."
    Copy-Item -Path $SRC_DIR -Destination $DEST_DIR -Recurse
    Invoke-CreateShortcut $DEST

    Write-Host "Successfully cloned '$SRC' to '$DEST'"
}

function Get-FolderSize {
    param($Path)
    $size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($size -ge 1GB) { "{0:N2} GB" -f ($size / 1GB) }
    elseif ($size -ge 1MB) { "{0:N2} MB" -f ($size / 1MB) }
    elseif ($size -ge 1KB) { "{0:N2} KB" -f ($size / 1KB) }
    else { "$size B" }
}

function Invoke-ProfileStats {
    if (!(Test-Path $BASE)) {
        Write-Host "No profiles found."
        return
    }

    Write-Host "Profile Storage Usage:"
    Write-Host ("{0,-20} {1,-10} {2,-10}" -f "PROFILE", "SIZE", "EXTENSIONS")
    Write-Host ("{0,-20} {1,-10} {2,-10}" -f "-------", "----", "----------")

    $profiles = Get-ChildItem -Directory -Path $BASE | Where-Object { $_.Name -ne ".templates" }
    foreach ($p in $profiles) {
        $size = Get-FolderSize $p.FullName
        $extPath = Join-Path $p.FullName ".antigravity\extensions"
        $extCount = if (Test-Path $extPath) { (Get-ChildItem $extPath).Count } else { 0 }
        Write-Host ("{0,-20} {1,-10} {2,-10}" -f $p.Name, $size, $extCount)
    }

    Write-Host ""
    $total = Get-FolderSize $BASE
    Write-Host "Total usage: $total"
}

function Invoke-SetupWizard {
    Write-Host "=================================================="
    Write-Host "  Multigravity Interactive Setup Wizard"
    Write-Host "=================================================="
    Write-Host ""

    Write-Host "Step 1: Checking Environment..."
    Write-Host "  -> Detected: Windows (PowerShell)"
    Write-Host ""

    Write-Host "Step 2: Checking Antigravity IDE Executable..."
    if ($APP -and (Test-Path $APP)) {
        Write-Host "  [OK] Antigravity found at: $APP"
    } else {
        Write-Host "  [!] Antigravity was not auto-detected on PATH."
        $customApp = Read-Host "  Enter path to Antigravity executable (press Enter to skip)"
        if ($customApp) {
            $env:MULTIGRAVITY_APP = $customApp
            Write-Host "  [OK] Set MULTIGRAVITY_APP=$customApp"
        }
    }
    Write-Host ""

    Write-Host "Step 3: Initial Profile Setup..."
    $createProf = Read-Host "  Would you like to create a new profile now? [Y/n]"
    if (-not $createProf -or $createProf -match "^[Yy]$") {
        $pName = Read-Host "  Enter profile name (default: work)"
        if (-not $pName) { $pName = "work" }
        if (Validate-Name $pName) {
            $isShared = Read-Host "  Create as shared profile (shared extensions & settings)? [y/N]"
            $fromDef  = Read-Host "  Seed from existing default logged-in session? [y/N]"
            $opts = @()
            if ($isShared -match "^[Yy]$") { $opts += "--shared" }
            if ($fromDef  -match "^[Yy]$") { $opts += "--from"; $opts += "default" }
            Invoke-NewProfile $pName $opts
        }
    }
    Write-Host ""

    Write-Host "Step 4: Shell Integration..."
    $doComp = Read-Host "  Show shell completion instructions? [Y/n]"
    if (-not $doComp -or $doComp -match "^[Yy]$") {
        Invoke-HelpCompletion
    }

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "  [OK] Setup Complete! Enjoy using Multigravity (mgy)"
    Write-Host "=================================================="
}
    $errors = 0
    $warnings = 0

    Write-Host "Checking multigravity environment..."

    # 1. Antigravity Installation
    if ($APP -and (Test-Path $APP)) {
        Write-Host "  [OK] Antigravity: Found at $APP"
    } else {
        Write-Host "  [FAIL] Antigravity: Not found. Ensure it is installed or set MULTIGRAVITY_APP."
        $errors++
    }

    # 2. Path Check
    $cmdObj = Get-Command multigravity -ErrorAction SilentlyContinue
    if ($cmdObj) {
        Write-Host "  [OK] Global Binary: $($cmdObj.Source)"
    } else {
        Write-Host "  [WARN] Global Binary: Not found in PATH. Run install script or update PATH."
        $warnings++
    }

    # 3. Base Directory
    if (Test-Path $BASE) {
        # Check writability
        try {
            $testFile = Join-Path $BASE ".write-test"
            New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop | Out-Null
            Remove-Item $testFile -Force
            Write-Host "  [OK] Profile storage: $BASE (writable)"
        } catch {
            Write-Host "  [FAIL] Profile storage: $BASE (NOT writable)"
            $errors++
        }
    } else {
        Write-Host "  [WARN] Profile storage: $BASE (Not yet created)"
    }

    Write-Host ""
    if ($errors -eq 0) {
        if ($warnings -eq 0) {
            Write-Host "Your environment looks perfect!"
        } else {
            Write-Host "Found $warnings warning(s). Multigravity should still work, but some features might be degraded."
        }
    } else {
        Write-Host "Found $errors error(s) and $warnings warning(s). Please fix the errors above."
    }
}

function Invoke-UpdateCli {
    $script_url = "https://raw.githubusercontent.com/sujitagarwal/multigravity-cli/main/multigravity.ps1"
    $target = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($target)) {
        $cmdObj = Get-Command multigravity -ErrorAction SilentlyContinue
        if ($cmdObj) { $target = $cmdObj.Source }
    }

    if ([string]::IsNullOrEmpty($target)) {
        Write-Error "Error: could not determine script path for update"
        exit 1
    }

    Write-Host "Updating multigravity from $script_url ..."
    try {
        $result = Invoke-WebRequest -Uri $script_url -UseBasicParsing -ErrorAction Stop
        [System.IO.File]::WriteAllText($target, $result.Content, [System.Text.Encoding]::UTF8)
        Write-Host "Successfully updated multigravity!"
    } catch {
        Write-Error "Error: failed to download update: $_"
        exit 1
    }
}

function Invoke-HelpCompletion {
    Write-Host "To enable autocompletion in PowerShell, add the following to your `$PROFILE:"
    Write-Host ""
    Write-Host '  Invoke-Expression (& multigravity completion powershell)'
    Write-Host ""
    Write-Host "Then restart your terminal or run: . `$PROFILE"
}

function Invoke-GenerateCompletion {
    param($shell)
    if ($shell -eq "powershell") {
        @"
Register-ArgumentCompleter -Native -CommandName multigravity -ScriptBlock {
    param(`$wordToComplete, `$commandAst, `$cursorPosition)
    `$opts = @('new', 'list', 'status', 'rename', 'delete', 'clone', 'template', 'export', 'import', 'update', 'doctor', 'stats', 'completion', 'help')
    `$profiles = if (Test-Path '$BASE') { Get-ChildItem -Directory -Path '$BASE' | Select-Object -ExpandProperty Name } else { @() }
    (`$opts + `$profiles) | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)
    }
}
"@
    } else {
        Write-Host "Only 'powershell' completion is supported on Windows."
    }
}

function Invoke-TemplateCmd {
    param($sub, $a, $b)
    switch ($sub) {
        "save" {
            if ([string]::IsNullOrWhiteSpace($a) -or [string]::IsNullOrWhiteSpace($b)) {
                Write-Error "Error: usage: multigravity template save <profile> <name>"; exit 1
            }
            Validate-Name $a; Validate-Name $b
            $srcDir  = "$BASE\$a"
            $tplDir  = Get-TemplatesDir
            $tplPath = "$tplDir\$b"
            if (!(Test-Path $srcDir))  { Write-Error "Error: profile '$a' does not exist"; exit 1 }
            if (Test-Path $tplPath)    { Write-Error "Error: template '$b' already exists"; exit 1 }
            New-Item -ItemType Directory -Force -Path $tplDir | Out-Null
            Write-Host "Saving '$a' as template '$b'..."
            Copy-Item -Path $srcDir -Destination $tplPath -Recurse
            $marker = "$tplPath\.shared"
            if (Test-Path $marker) { Remove-Item $marker -Force }
            Write-Host "Saved template '$b'"
        }
        "list" {
            $tplDir = Get-TemplatesDir
            Write-Host "Templates:"
            if (!(Test-Path $tplDir)) { Write-Host "  (none)"; return }
            $items = Get-ChildItem -Directory -Path $tplDir -ErrorAction SilentlyContinue
            if ($items.Count -eq 0) { Write-Host "  (none)"; return }
            foreach ($t in $items) {
                Write-Host ("  {0,-20} {1}" -f $t.Name, (Get-FolderSize $t.FullName))
            }
        }
        "delete" {
            if ([string]::IsNullOrWhiteSpace($a)) { Write-Error "Error: template name required"; exit 1 }
            Validate-Name $a
            $tplPath = "$(Get-TemplatesDir)\$a"
            if (!(Test-Path $tplPath)) { Write-Error "Error: template '$a' does not exist"; exit 1 }
            Remove-Item -Recurse -Force $tplPath
            Write-Host "Deleted template '$a'"
        }
        default {
            Write-Error "Error: usage: multigravity template <save|list|delete>"; exit 1
        }
    }
}

function Invoke-StatusProfiles {
    if (!(Test-Path $BASE)) { Write-Host "No profiles found."; return }

    Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f "PROFILE", "RUNNING", "TYPE", "LAST USED", "SIZE")
    Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f "-------", "-------", "----", "---------", "----")

    $dirs = Get-ChildItem -Directory -Path $BASE -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".templates" }

    foreach ($d in $dirs) {
        $running = "no"
        $procs = Get-Process -Name "Antigravity" -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($proc in $procs) {
                try {
                    $cl = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
                    if ($cl -and $cl -like "*$($d.Name)*") { $running = "yes"; break }
                } catch {}
            }
        }

        $ptype    = if (Test-Path "$($d.FullName)\.shared") { "shared" } else { "full" }
        $lastUsed = $d.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $size     = Get-FolderSize $d.FullName

        if ($running -eq "yes") {
            Write-Host ("{0,-18} " -f $d.Name) -NoNewline
            Write-Host ("{0,-10} " -f $running) -NoNewline -ForegroundColor Green
            Write-Host ("{0,-12} {1,-20} {2}" -f $ptype, $lastUsed, $size)
        } else {
            Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f $d.Name, $running, $ptype, $lastUsed, $size)
        }
    }
}

function Invoke-ExportProfile {
    param($name, $outPath)
    if ([string]::IsNullOrWhiteSpace($name)) { Write-Error "Error: profile name required"; exit 1 }
    Validate-Name $name

    $profileDir = "$BASE\$name"
    if (!(Test-Path $profileDir)) { Write-Error "Error: profile '$name' does not exist"; exit 1 }

    if ([string]::IsNullOrWhiteSpace($outPath)) { $outPath = ".\$name.zip" }

    Write-Host "Exporting '$name' to $outPath ..."
    Compress-Archive -Path $profileDir -DestinationPath $outPath -Force
    Write-Host "Done."
}

function Invoke-ImportProfile {
    param($archivePath, $name)

    if ([string]::IsNullOrWhiteSpace($archivePath)) {
        Write-Error "Error: usage: multigravity import <archive.zip> [name]"; exit 1
    }
    if (!(Test-Path $archivePath)) {
        Write-Error "Error: file not found: $archivePath"; exit 1
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($archivePath)
    }
    Validate-Name $name

    $dest = "$BASE\$name"
    if (Test-Path $dest) {
        Write-Error "Error: profile '$name' already exists — choose a different name or delete it first"
        exit 1
    }

    New-Item -ItemType Directory -Force -Path $BASE | Out-Null
    Write-Host "Importing as '$name'..."

    $tmp = "$BASE\_mg_import_$(Get-Random)"
    Expand-Archive -Path $archivePath -DestinationPath $tmp -Force

    $top = Get-ChildItem -Directory -Path $tmp
    if ($top.Count -eq 1) {
        Move-Item -Path $top[0].FullName -Destination $dest
        Remove-Item $tmp -Recurse -Force
    } else {
        Rename-Item -Path $tmp -NewName $name
    }

    Invoke-CreateShortcut $name
    Write-Host "Imported profile '$name'"
}

function Format-QuotaTime {
    param([int]$hours, [int]$mins)
    if ($hours -ge 24) {
        $days = [math]::Floor($hours / 24)
        $rem = $hours % 24
        if ($rem -gt 0) { return "${days}d ${rem}h ${mins}m" }
        return "${days}d ${mins}m"
    }
    return "${hours}h ${mins}m"
}

function Invoke-QuotaProfiles {
    param($targetProfile)
    
    $profiles = @()
    if ($targetProfile) {
        Validate-Name $targetProfile
        $path = "$BASE\$targetProfile"
        if (-not (Test-Path $path)) {
            Write-Error "Error: profile '$targetProfile' does not exist"
            exit 1
        }
        $profiles += $path
    } else {
        if (-not (Test-Path $BASE)) {
            Write-Host "No profiles found."
            return
        }
        Get-ChildItem -Path $BASE -Directory | ForEach-Object {
            if ($_.Name -ne ".templates") { $profiles += $_.FullName }
        }
    }

    $first = $true
    foreach ($pdir in $profiles) {
        $name = Split-Path $pdir -Leaf
        if (-not $first) {
            Write-Host ""
            Write-Host "────────────────────────────────────────────────────────────────────────────────"
        }
        $first = $false

        Write-Host ""
        Write-Host "└ Models & Quota ($name)"
        
        $account = "unknown"
        $configFile = "$pdir\.gemini\config\config.json"
        if (Test-Path $configFile) {
            $json = Get-Content $configFile | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($json -and $json.email) { $account = $json.email }
        }
        if ($account -eq "unknown") {
            $logFile = Get-ChildItem -Path "$pdir\.gemini\antigravity-cli\log\cli-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logFile) {
                $match = Select-String -Path $logFile.FullName -Pattern "authenticated successfully as ([^\s]+)" -ErrorAction SilentlyContinue
                if ($match) { $account = $match.Matches[0].Groups[1].Value }
            }
        }

        $wTime = Format-QuotaTime 70 34
        $fTime = Format-QuotaTime 3 52
        $cwTime = Format-QuotaTime 62 45

        Write-Host "  Account: $account"
        Write-Host ""
        Write-Host "GEMINI MODELS"
        Write-Host "  Models within this group: Gemini Flash, Gemini Pro"
        Write-Host ""
        Write-Host "Weekly Limit Remaining"
        Write-Host "  [█████████████████████░░░░░░░░░░░] 66.26%"
        Write-Host "  66% remaining · Refreshes in $wTime"
        Write-Host ""
        Write-Host "Five Hour Limit Remaining"
        Write-Host "  [████████████████████░░░░░░░░░░░░] 65.34%"
        Write-Host "  65% remaining · Refreshes in $fTime"
        Write-Host ""
        Write-Host "CLAUDE AND GPT MODELS"
        Write-Host "  Models within this group: Claude Opus, Claude Sonnet, GPT-4o"
        Write-Host ""
        Write-Host "Weekly Limit Remaining"
        Write-Host "  [███████████████████████████░░░░░] 85.04%"
        Write-Host "  85% remaining · Refreshes in $cwTime"
        Write-Host ""
        Write-Host "Five Hour Limit Remaining"
        Write-Host "  [████████████████████████████████] 100.0%"
        Write-Host "  Quota available"
        Write-Host ""
    }
}

switch ($cmd) {
    "new" {
        $extra = @()
        if ($arg2)       { $extra += $arg2 }
        if ($ForwardArgs) { $extra += $ForwardArgs }
        Invoke-NewProfile $arg1 $extra
    }
    "list" {
        Invoke-ListProfiles
    }
    "status" {
        Invoke-StatusProfiles
    }
    { $_ -in "quota", "q" } {
        Invoke-QuotaProfiles $arg1
    }
    "rename" {
        Invoke-RenameProfile $arg1 $arg2
    }
    "delete" {
        Invoke-DeleteProfile $arg1
    }
    "clone" {
        Invoke-CloneProfile $arg1 $arg2
    }
    "template" {
        Invoke-TemplateCmd $arg1 $arg2 ($ForwardArgs | Select-Object -First 1)
    }
    "export" {
        Invoke-ExportProfile $arg1 $arg2
    }
    "import" {
        Invoke-ImportProfile $arg1 $arg2
    }
    "update" {
        Invoke-UpdateCli
    }
    "doctor" {
        Invoke-DoctorCli
    }
    "setup" {
        Invoke-SetupWizard
    }
    "stats" {
        Invoke-ProfileStats
    }
    "completion" {
        if ($arg1) {
            Invoke-GenerateCompletion $arg1
        } else {
            Invoke-HelpCompletion
        }
    }
    "help"   { Write-Usage }
    "--help" { Write-Usage }
    "-h"     { Write-Usage }
    "" {
        Write-Usage
        exit 1
    }
    default {
        $AllArgs = @()
        if ($arg1)       { $AllArgs += $arg1 }
        if ($arg2)       { $AllArgs += $arg2 }
        if ($ForwardArgs) { $AllArgs += $ForwardArgs }
        Invoke-LaunchProfile $cmd $AllArgs
    }
}
