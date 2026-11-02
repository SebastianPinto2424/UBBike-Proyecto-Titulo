param(
    [Parameter(Mandatory = $true)]
    [string]$Url
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$url = $Url.Trim().TrimEnd('/')

if ($url -notmatch '^https://[^/\s]+$') {
    throw "La URL debe ser el dominio con HTTPS y sin ruta, por ejemplo https://ubbike.midominio.cl"
}

if (-not (Test-Path (Join-Path $raiz 'mobile\android\app\google-services.json'))) {
    throw "Falta mobile\android\app\google-services.json. Se descarga en Firebase, Configuracion del proyecto, app Android cl.ubiobio.ubbike."
}

if (-not (Test-Path (Join-Path $raiz 'mobile\android\key.properties'))) {
    Write-Warning "No existe mobile\android\key.properties: la APK se firma con la llave de depuracion de este equipo."
}

try {
    $salud = Invoke-RestMethod -Uri "$url/health" -TimeoutSec 15
    Write-Host "Backend en linea: $url ($($salud.status))"
} catch {
    Write-Warning "$url/health no respondio. La APK se compila igual."
}

Push-Location (Join-Path $raiz 'mobile')
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get fallo" }
    flutter build apk --release "--dart-define=API_BASE_URL=$url"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk fallo" }
} finally {
    Pop-Location
}

$destino = Join-Path $raiz 'apks'
New-Item -ItemType Directory -Force $destino | Out-Null
$nombre = "ubbike-$(([Uri]$url).Host)-$(Get-Date -Format 'yyyyMMdd-HHmm').apk"
Copy-Item (Join-Path $raiz 'mobile\build\app\outputs\flutter-apk\app-release.apk') (Join-Path $destino $nombre)
Write-Host "APK lista: apks\$nombre"
