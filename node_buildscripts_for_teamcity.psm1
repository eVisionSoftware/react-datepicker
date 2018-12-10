function Log($text)
{
  Write-Host "$text"
}

function WriteHeader($text)
{
    Log "--------------------------------------------"
    Log "$text"
    Log "--------------------------------------------"
}


function RunNpmScript($command, $failOnError)
{
    Log "RunNpmScript: npm $command"
    $start_time = Get-Date

    $output = &npm $command.Split(" ") | out-string
    Log $output

    if ($LASTEXITCODE -gt 0 -and $failOnError -eq $true) {
        $script:overallStatus = $LASTEXITCODE;
        Log "Last exit code: $LASTEXITCODE, failing build..."
    }

    Log "RunNpmScript done: [npm $command]. Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    return $output;
}


function createDir
{
    param([string]$folder)

    if (Test-Path $folder) {
        Log "createDir: [$folder] already exits "
    } else {
        Log "createDir: Creating [$folder]"
        New-Item -ItemType directory -Path $folder
        Log "createDir: Created"
    }
}


function downloadFile
{
    param([string]$url, [string]$outFile)

    if (Test-Path $outFile) {
        Log "downloadFile: [$outFile] already exits"
    } else {
        Log "downloadFile: Downloading [$url] to [$outFile]"
        $start_time = Get-Date
        Import-Module BitsTransfer
        Start-BitsTransfer -Source $url -Destination $outFile
        Log "downloadFile: Downloaded. Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    }
}


Add-Type -AssemblyName System.IO.Compression.FileSystem
function unzip
{
    param([string]$zipFile, [string]$outDir)

        if (Test-Path $outDir) {
            Log "unzip: [$outDir] already exits"
        } else {
            Log "unzip: Unzip [$zipFile] to [$outDir]"
            $start_time = Get-Date
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $outDir)
            Log "unzip: Unzipped. Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
        }
}


function FindPath {
    param([string] $name, [string]$fromDir)

        $result = Get-ChildItem $fromDir -Filter $name -Recurse -Force | Select-Object -First 1
    return $result.Directory
}


function InjectNpmAuthToken {
    param([string]$npmAuthToken)

    if ($npmAuthToken -ne "") {
        Log "Injecting npm auth token"
        Add-Content .npmrc "`n//evision.myget.org/F/main/npm/:_authToken=$npmAuthToken"
    }
}

function replaceInFile {
    param($file, $search, $replace)

    if (Test-Path $file) {
        (Get-Content $file) | % { $_.Replace($search, $replace) } | Set-Content $file
    }
}

function Get-NpmPackage-Name {
    $package_json = ((Get-Content "package.json" ) -Join " ") | ConvertFrom-Json
    return $package_json.name;
}

function Get-NpmPackage-Version {
    $package_json = ((Get-Content "package.json" ) -Join " ") | ConvertFrom-Json
    return $package_json.version;
}

function DownloadNode
{
    param([string]$version)

    $url = "https://nodejs.org/download/release/$version/node-$version-win-x64.zip"

    $rootDir = Resolve-Path .\
    $bin     = "$rootDir\.bin"
    $nodeDir = "$bin\node"
    $zipFile = "$bin\node.zip"
    $bin_node = "node.exe"
    $bin_npm = "npm.cmd"

    createDir $bin

    downloadFile $url $zipFile
    unzip $zipFile $nodeDir

    $NODE_PATH = FindPath $bin_node $nodeDir
    Log "nodejs path: [$NODE_PATH]"
    $env:Path += ";$NODE_PATH"
    Log "Added to PATH"

    if (Test-Path "$NODE_PATH\$bin_node") {
      Log "[$NODE_PATH\$bin_node] found - OK"
      node --version |% {
          Log $_
      }
    } else {
      Log "[$NODE_PATH\$bin_node] FAILED"
    }


    if (Test-Path "$NODE_PATH\$bin_npm") {
      Log "[$NODE_PATH\$bin_npm] found - OK"
      npm --version |% {
          Log $_
      }
    } else {
      Log "[$NODE_PATH\$bin_npm] FAILED"
    }
}
