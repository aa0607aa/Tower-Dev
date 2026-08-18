<#
.SYNOPSIS
    「탑」 실행 · 테스트 헬퍼.

.DESCRIPTION
    Godot 실행 파일을 자동으로 찾아 프로젝트를 실행하거나 테스트를 돌린다.

    이 스크립트가 있는 이유: 개발 PC에서 winget이 관리자 권한 없이 설치돼
    `godot` PATH 별칭이 만들어지지 않았다. 매번 긴 경로를 치지 않으려고 둔다.
    PATH에 godot이 있는 환경에서는 그것을 먼저 쓴다.

.PARAMETER Mode
    play    (기본) 창을 띄워 실제로 플레이한다. ESC로 종료
    editor  Godot 에디터로 프로젝트를 연다
    test    단위 + 통합 자동 테스트를 돌린다. 실패 시 non-zero 종료
    import  에셋 임포트만 한다 (다른 PC에서 처음 클론했을 때 필요)

.PARAMETER Angle
    렌더링을 ANGLE(D3D11 변환)로 강제한다.
    현재 개발 PC는 네이티브 OpenGL 종료 시 크래시하므로 play/editor에서 기본으로 켠다.
    다른 PC에서는 -Angle:$false 로 끄고 먼저 시도해 볼 것. (docs/BACKLOG.md B-003)

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/run.ps1
    powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Mode test
    powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Mode editor
#>
[CmdletBinding()]
param(
    [ValidateSet('play', 'editor', 'test', 'import')]
    [string]$Mode = 'play',
    [bool]$Angle = $true
)

$ErrorActionPreference = 'Stop'

# 프로젝트 루트 = 이 스크립트의 부모 폴더
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $projectRoot 'project.godot'))) {
    throw "project.godot을 찾지 못했다: $projectRoot"
}

function Find-Godot {
    # 1) PATH
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 2) winget 패키지 폴더 (_console.exe가 stdout/stderr를 보여준다)
    $wingetDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path $wingetDir) {
        $hit = Get-ChildItem $wingetDir -Recurse -Filter 'Godot_v*_console.exe' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
        $hit = Get-ChildItem $wingetDir -Recurse -Filter 'Godot_v*.exe' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    throw @"
Godot 실행 파일을 찾지 못했다.
설치: winget install --id GodotEngine.GodotEngine -e --version 4.7.1
설치했는데도 안 잡히면 -Verbose 로 경로를 확인하거나 PATH에 추가할 것.
"@
}

## 프로젝트가 요구하는 Godot 버전. project.godot의 config/features와 맞춘다.
$RequiredVersion = '4.7.1'

$godot = Find-Godot
Write-Host "Godot: $godot"
Write-Host "프로젝트: $projectRoot"

# P1-TOOL-001: 여러 Godot 버전이 설치돼 있으면 Find-Godot이 엉뚱한 것을 고를 수 있다.
# 다른 버전으로 테스트가 돌면 "통과했는데 실제로는 다른 엔진" 상황이 되므로 경고한다.
# 막지는 않는다 — 의도적으로 다른 버전을 시험해 볼 수도 있다.
$versionLine = (& $godot --version 2>&1 | Select-Object -First 1) -as [string]
if ($versionLine) {
    Write-Host "버전: $versionLine"
    if ($versionLine -notmatch [regex]::Escape($RequiredVersion)) {
        Write-Host ""
        Write-Host "!! 경고: 프로젝트 요구 버전은 $RequiredVersion 인데 실행 파일은 '$versionLine' 이다." -ForegroundColor Yellow
        Write-Host "   테스트 결과의 재현성을 보장할 수 없다. 설치:" -ForegroundColor Yellow
        Write-Host "   winget install --id GodotEngine.GodotEngine -e --version $RequiredVersion" -ForegroundColor Yellow
    }
} else {
    Write-Host "!! 경고: Godot 버전을 확인하지 못했다." -ForegroundColor Yellow
}
Write-Host ""

$renderArgs = @()
if ($Angle -and $Mode -in @('play', 'editor')) {
    $renderArgs = @('--rendering-driver', 'opengl3_angle')
}

switch ($Mode) {
    'import' {
        & $godot --headless --path $projectRoot --import
        exit $LASTEXITCODE
    }
    'editor' {
        & $godot --path $projectRoot --editor @renderArgs
        exit $LASTEXITCODE
    }
    'test' {
        # 새 class_name 스크립트는 임포트/스캔을 거쳐야 전역 등록된다.
        # 이걸 빼면 방금 추가한 타입이 "not declared in the current scope"로 터진다.
        Write-Host "=== 임포트 ===" -ForegroundColor Cyan
        & $godot --headless --path $projectRoot --import | Out-Null
        Write-Host ""
        Write-Host "=== 단위 테스트 ===" -ForegroundColor Cyan
        & $godot --headless --path $projectRoot --script res://tests/runner.gd
        $unit = $LASTEXITCODE
        Write-Host ""
        Write-Host "=== 통합 테스트 ===" -ForegroundColor Cyan
        & $godot --headless --path $projectRoot --script res://tests/integration_runner.gd
        $integration = $LASTEXITCODE
        Write-Host ""
        if ($unit -eq 0 -and $integration -eq 0) {
            Write-Host "전부 통과" -ForegroundColor Green
            exit 0
        }
        Write-Host "실패 — 단위 $unit / 통합 $integration" -ForegroundColor Red
        exit 1
    }
    'play' {
        Write-Host "WASD 또는 방향키로 이동, ESC로 종료." -ForegroundColor Yellow
        & $godot --path $projectRoot @renderArgs
        exit $LASTEXITCODE
    }
}
