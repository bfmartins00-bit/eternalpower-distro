# APLICAR_PATCH.ps1 — Corrige o distromanager.js diretamente
$launcherDir = Join-Path $PSScriptRoot "eternalpower-launcher"
$targetFile = Join-Path $launcherDir "app\assets\js\distromanager.js"

Write-Host ""
Write-Host "=== APLICANDO PATCH NO DISTROMANAGER.JS ==="
Write-Host ""

# Verificar se a pasta existe
if (-not (Test-Path $launcherDir)) {
    Write-Host "ERRO: Pasta eternalpower-launcher nao encontrada em $launcherDir"
    exit 1
}

# Fazer backup
$bakFile = $targetFile + ".bak"
if (Test-Path $targetFile) {
    Copy-Item $targetFile $bakFile -Force
    Write-Host "Backup salvo em: $bakFile"
}

# Escrever o novo conteudo diretamente
$newContent = @'
const { DistributionAPI, HeliosDistribution } = require('helios-core/common')
const ConfigManager = require('./configmanager')

exports.REMOTE_DISTRO_URL = 'https://raw.githubusercontent.com/bfmartins00-bit/eternalpower-distro/main/distribution.json'

const EMBEDDED_DISTRO = {
    "version": "1.0.0",
    "rss": "https://raw.githubusercontent.com/bfmartins00-bit/eternalpower-distro/main/",
    "discord": {
        "clientId": "f8cdef31-a31e-4b4a-93e4-5f571e91255a",
        "smallImageText": "EternalPower RPG",
        "smallImageKey": "logo_ep"
    },
    "servers": [
        {
            "id": "EternalPower.Main",
            "name": "EternalPower RPG",
            "description": "Servidor RPG Anime - Cobblemon, Bleach, Naruto, Demon Slayer e mais!",
            "icon": "https://raw.githubusercontent.com/bfmartins00-bit/eternalpower-distro/main/images/server-icon.png",
            "version": "1.0.0",
            "address": "enx-cirion-67.enx.host:10023",
            "minecraftVersion": "1.20.1",
            "discord": {
                "shortId": "EternalPower",
                "largeImageText": "EternalPower RPG Anime",
                "largeImageKey": "logo_ep"
            },
            "mainServer": true,
            "autoconnect": false,
            "javaOptions": {
                "supported": ">=17.x",
                "suggestedMajor": 21,
                "platformOptions": [
                    { "platform": "win32", "architecture": "x64", "distribution": "TEMURIN" }
                ]
            },
            "modules": []
        }
    ]
}

let api
try {
    api = new DistributionAPI(ConfigManager.getLauncherDirectory(), null, null, exports.REMOTE_DISTRO_URL, false)
} catch(e) {
    api = { rawDistribution: null, distribution: null }
}

const _api = api

api.getDistribution = async function() {
    if (_api.rawDistribution != null) return _api.distribution

    // Tentativa 1: remoto
    try {
        const got = require('got')
        const res = await got.get(exports.REMOTE_DISTRO_URL, { responseType: 'json', timeout: { request: 10000 } })
        _api.rawDistribution = res.body
        _api.distribution = new HeliosDistribution(res.body, ConfigManager.getCommonDirectory(), ConfigManager.getInstanceDirectory())
        try {
            const fs = require('fs-extra'), path = require('path')
            await fs.ensureDir(ConfigManager.getLauncherDirectory())
            await fs.writeJson(path.join(ConfigManager.getLauncherDirectory(), 'distribution.json'), res.body)
        } catch(e) {}
        return _api.distribution
    } catch(e) { console.warn('[Distro] Remoto falhou:', e.message) }

    // Tentativa 2: cache local
    try {
        const fs = require('fs-extra'), path = require('path')
        const p = path.join(ConfigManager.getLauncherDirectory(), 'distribution.json')
        if (await fs.pathExists(p)) {
            const raw = await fs.readJson(p)
            _api.rawDistribution = raw
            _api.distribution = new HeliosDistribution(raw, ConfigManager.getCommonDirectory(), ConfigManager.getInstanceDirectory())
            return _api.distribution
        }
    } catch(e) { console.warn('[Distro] Cache local falhou:', e.message) }

    // Tentativa 3: distribuicao embutida — sempre funciona
    console.info('[Distro] Usando distribuicao embutida.')
    _api.rawDistribution = EMBEDDED_DISTRO
    _api.distribution = new HeliosDistribution(
        EMBEDDED_DISTRO,
        ConfigManager.getCommonDirectory ? ConfigManager.getCommonDirectory() : null,
        ConfigManager.getInstanceDirectory ? ConfigManager.getInstanceDirectory() : null
    )
    return _api.distribution
}

api.refreshDistributionOrFallback = api.getDistribution
api.toggleDevMode = (dev) => { if (_api.toggleDevMode) _api.toggleDevMode(dev) }
api.isDevMode = () => _api.isDevMode ? _api.isDevMode() : false

exports.DistroAPI = api
'@

[System.IO.File]::WriteAllText($targetFile, $newContent, [System.Text.Encoding]::UTF8)

# Verificar
if (Test-Path $targetFile) {
    $size = (Get-Item $targetFile).Length
    Write-Host "PATCH APLICADO! Arquivo: $targetFile ($size bytes)"
} else {
    Write-Host "ERRO: Arquivo nao foi criado!"
    exit 1
}

Write-Host ""
Write-Host "Abrindo launcher..."
$electron = Join-Path $launcherDir "node_modules\electron\dist\electron.exe"
if (Test-Path $electron) {
    Set-Location $launcherDir
    Start-Process $electron -ArgumentList "." -NoNewWindow
} else {
    Write-Host "ERRO: electron.exe nao encontrado. Execute INSTALAR.bat primeiro."
}
