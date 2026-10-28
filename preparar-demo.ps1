param(
    [switch]$SinApk,
    [int]$BackendPort = 0
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot

function Obtener-IpLan {
    $preferida = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
        Select-Object -First 1

    if ($preferida) {
        return $preferida.IPAddress
    }

    $rutas = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric, InterfaceMetric

    foreach ($ruta in $rutas) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $ruta.InterfaceIndex -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
            Select-Object -First 1

        if ($ip) {
            return $ip.IPAddress
        }
    }

    return $null
}

function Leer-Env {
    param(
        [string]$Contenido,
        [string]$Clave,
        [string]$ValorPorDefecto
    )

    $coincidencia = [regex]::Match($Contenido, "(?m)^$([regex]::Escape($Clave))=(.*)$")
    if ($coincidencia.Success -and $coincidencia.Groups[1].Value.Trim()) {
        return $coincidencia.Groups[1].Value.Trim()
    }

    return $ValorPorDefecto
}

function Set-Env {
    param(
        [string]$Contenido,
        [string]$Clave,
        [string]$Valor
    )

    $linea = "$Clave=$Valor"
    if ($Contenido -match "(?m)^$([regex]::Escape($Clave))=") {
        return [regex]::Replace(
            $Contenido,
            "(?m)^$([regex]::Escape($Clave))=.*$",
            [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $linea }
        )
    }

    $separador = if ($Contenido.EndsWith("`n")) { '' } else { "`r`n" }
    return "$Contenido$separador$linea`r`n"
}

function Probar-Admin {
    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identidad)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Asegurar-ReglaFirewall {
    param([int]$Puerto)

    $nombre = "UBBike demo backend TCP $Puerto"
    if (-not (Probar-Admin)) {
        Write-Host "Aviso: PowerShell no esta como administrador; no pude crear regla de firewall para TCP $Puerto." -ForegroundColor Yellow
        Write-Host "Si el celular no abre la URL de salud, ejecuta este script una vez como administrador o habilita ese puerto en Firewall de Windows." -ForegroundColor Yellow
        return
    }

    $existente = Get-NetFirewallRule -DisplayName $nombre -ErrorAction SilentlyContinue
    if ($existente) {
        return
    }

    New-NetFirewallRule `
        -DisplayName $nombre `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Puerto `
        -Profile Private,Domain `
        | Out-Null

    Write-Host "Regla de firewall creada para TCP $Puerto." -ForegroundColor Green
}

function Esperar-SaludBackend {
    param([string]$Url)

    for ($intento = 1; $intento -le 30; $intento++) {
        try {
            $respuesta = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($respuesta.StatusCode -eq 200) {
                return $true
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }

    return $false
}

$ip = Obtener-IpLan
if (-not $ip) {
    Write-Host 'No se encontro una IP LAN activa. Conectate a la red primero.' -ForegroundColor Red
    exit 1
}

$rutaEnv = Join-Path $raiz '.env'
if (-not (Test-Path $rutaEnv)) {
    Write-Host 'No existe .env en la raiz del proyecto.' -ForegroundColor Red
    exit 1
}

$contenido = Get-Content $rutaEnv -Raw
if ($BackendPort -le 0) {
    $BackendPort = [int](Leer-Env -Contenido $contenido -Clave 'BACKEND_PORT' -ValorPorDefecto '3000')
}

$apiBaseUrl = "http://${ip}:${BackendPort}"

Write-Host "IP LAN detectada: $ip" -ForegroundColor Cyan
Write-Host "Backend demo: $apiBaseUrl" -ForegroundColor Cyan

$contenido = Set-Env -Contenido $contenido -Clave 'BACKEND_PORT' -Valor $BackendPort
$contenido = Set-Env -Contenido $contenido -Clave 'BACKEND_BIND_ADDRESS' -Valor '0.0.0.0'
$contenido = Set-Env -Contenido $contenido -Clave 'PUBLIC_API_BASE_URL' -Valor $apiBaseUrl
Set-Content -Path $rutaEnv -Value $contenido -Encoding utf8 -NoNewline
Write-Host '.env actualizado para la red local.' -ForegroundColor Green

Asegurar-ReglaFirewall -Puerto $BackendPort

Write-Host 'Levantando stack de Docker...' -ForegroundColor Cyan
Set-Location $raiz
docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Fallo docker compose. Revisa que Docker Desktop este corriendo.' -ForegroundColor Red
    exit 1
}

$healthUrl = "$apiBaseUrl/salud"
Write-Host "Esperando backend en $healthUrl..." -ForegroundColor Cyan
if (Esperar-SaludBackend -Url $healthUrl) {
    Write-Host "Backend responde OK en $healthUrl" -ForegroundColor Green
} else {
    Write-Host "El backend no respondio en $healthUrl." -ForegroundColor Red
    Write-Host 'Abre esa URL desde el navegador del celular; si no carga, revisa Firewall de Windows o que ambos equipos esten en la misma red.' -ForegroundColor Yellow
    exit 1
}

if ($SinApk) {
    Write-Host 'Listo (sin recompilar APK).' -ForegroundColor Cyan
    exit 0
}

Write-Host "Compilando APK release con API_BASE_URL=$apiBaseUrl ..." -ForegroundColor Cyan
Set-Location (Join-Path $raiz 'mobile')
$dartDefine = "API_BASE_URL=$apiBaseUrl"
flutter build apk --release --dart-define=$dartDefine
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Fallo la compilacion del APK.' -ForegroundColor Red
    exit 1
}

$apk = Join-Path $raiz 'mobile\build\app\outputs\flutter-apk\app-release.apk'
$directorioApks = Join-Path ([Environment]::GetFolderPath('Desktop')) 'apks-pruebas'
New-Item -ItemType Directory -Path $directorioApks -Force | Out-Null
$destino = Join-Path $directorioApks 'ubbike-taller.apk'
Copy-Item $apk $destino -Force
Write-Host "APK listo en: $destino" -ForegroundColor Green
Write-Host "La APK apunta a: $apiBaseUrl" -ForegroundColor Green
Write-Host "Antes de instalar, prueba desde el celular: $healthUrl" -ForegroundColor Cyan
