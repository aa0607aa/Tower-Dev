<#
.SYNOPSIS
    설정서 docx → 마크다운 참고 사본 생성기.

.DESCRIPTION
    docs/SETTING_BIBLE_v1.1.docx 를 읽어 docs/SETTING_BIBLE_v1.1.md 를 만든다.

    이 스크립트가 존재하는 이유:
    canon 문구를 사람이 손으로 옮기면 반드시 조금씩 바뀐다. 그러면 원본과 사본이라는
    두 개의 진실이 생기고, 어느 쪽이 맞는지 아무도 모르게 된다. 그래서 변환은 항상
    기계적으로만 하고, 원본이 개정되면 이 스크립트를 다시 돌린다.

    출력물은 canon이 아니라 참고 사본이다. 원본과 다르면 언제나 원본(docx)이 이긴다.

.NOTES
    Word 스타일 매핑:
      Heading1   -> ##
      Heading2   -> ###
      ListBullet -> -
      ListNumber -> 1.
      CodeLike   -> ``` 코드 블록
      SmallNote  -> > 인용
      1열 표      -> > 인용 (Word에서 콜아웃 상자로 쓰인 것)
      2열+ 표     -> 마크다운 표

.EXAMPLE
    pwsh -File tools/docx_to_md.ps1
    pwsh -File tools/docx_to_md.ps1 -DocxPath docs/SETTING_BIBLE_v1.2.docx
#>
[CmdletBinding()]
param(
    [string]$DocxPath = "docs/SETTING_BIBLE_v1.1.docx",
    [string]$OutPath = ""
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DocxPath)) { throw "원본을 찾을 수 없다: $DocxPath" }
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = [System.IO.Path]::ChangeExtension($DocxPath, '.md')
}

# --- docx 압축 해제 (docx는 zip이다) ---
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("towerdocx_" + [guid]::NewGuid().ToString('N'))
[System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $DocxPath), $tmp)

try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load((Join-Path $tmp 'word\document.xml'))

    $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

    # --- 문단 하나의 텍스트를 뽑는다 (탭/줄바꿈 포함, 문서 순서 유지) ---
    function Get-ParaText([System.Xml.XmlNode]$p) {
        $sb = New-Object System.Text.StringBuilder
        foreach ($n in $p.SelectNodes('.//w:t | .//w:tab | .//w:br', $ns)) {
            switch ($n.LocalName) {
                't'   { [void]$sb.Append($n.InnerText) }
                'tab' { [void]$sb.Append(' ') }
                'br'  { [void]$sb.Append(' ') }
            }
        }
        # 마크다운 표를 깨뜨리는 파이프만 이스케이프한다
        return ($sb.ToString() -replace '\|', '\|').Trim()
    }

    function Get-ParaStyle([System.Xml.XmlNode]$p) {
        $s = $p.SelectSingleNode('w:pPr/w:pStyle', $ns)
        if ($null -eq $s) { return '' }
        return $s.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    }

    $out = New-Object System.Collections.Generic.List[string]
    $body = $doc.SelectSingleNode('//w:body', $ns)
    $inCode = $false
    # 목록 바로 뒤에 일반 문단이 오면 빈 줄이 없어 목록 항목으로 붙어버린다. 그래서 추적한다.
    $lastWasList = $false

    foreach ($node in $body.ChildNodes) {

        # ---------- 문단 ----------
        if ($node.LocalName -eq 'p') {
            $style = Get-ParaStyle $node
            $text = Get-ParaText $node

            # 코드 블록 열고 닫기
            if ($style -eq 'CodeLike' -and -not $inCode) { $out.Add(''); $out.Add('```'); $inCode = $true }
            elseif ($style -ne 'CodeLike' -and $inCode) { $out.Add('```'); $inCode = $false }

            if ([string]::IsNullOrWhiteSpace($text)) {
                if (-not $inCode) { $out.Add(''); $lastWasList = $false }
                continue
            }

            $isList = ($style -eq 'ListBullet' -or $style -eq 'ListNumber')
            if ($lastWasList -and -not $isList) { $out.Add('') }
            $lastWasList = $isList

            switch ($style) {
                'Heading1'   { $out.Add(''); $out.Add("## $text");  $out.Add('') }
                'Heading2'   { $out.Add(''); $out.Add("### $text"); $out.Add('') }
                'Heading3'   { $out.Add(''); $out.Add("#### $text"); $out.Add('') }
                'Title'      { $out.Add("# $text"); $out.Add('') }
                'Subtitle'   { $out.Add("_${text}_"); $out.Add('') }
                'ListBullet' { $out.Add("- $text") }
                'ListNumber' { $out.Add("1. $text") }
                'CodeLike'   { $out.Add($text) }
                'SmallNote'  { $out.Add("> $text") }
                default      { $out.Add($text); $out.Add('') }
            }
            continue
        }

        # ---------- 표 ----------
        if ($node.LocalName -eq 'tbl') {
            if ($inCode) { $out.Add('```'); $inCode = $false }
            $lastWasList = $false

            $rows = @()
            foreach ($tr in $node.SelectNodes('w:tr', $ns)) {
                $cells = @()
                foreach ($tc in $tr.SelectNodes('w:tc', $ns)) {
                    $parts = @()
                    foreach ($p in $tc.SelectNodes('w:p', $ns)) {
                        $t = Get-ParaText $p
                        if (-not [string]::IsNullOrWhiteSpace($t)) { $parts += $t }
                    }
                    $cells += ($parts -join '<br>')
                }
                if ($cells.Count -gt 0) { $rows += , $cells }
            }
            if ($rows.Count -eq 0) { continue }

            $maxCols = ($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum

            $out.Add('')
            if ($maxCols -eq 1) {
                # Word에서 콜아웃 상자로 쓰인 1열 표 -> 인용문.
                # 셀 하나에 제목+본문이 함께 들어 있으므로 첫 줄(제목)만 굵게 하고
                # 나머지는 보통 글로 둔다. 전부 굵게 하면 읽기 어렵다.
                $first = $true
                for ($i = 0; $i -lt $rows.Count; $i++) {
                    foreach ($seg in ($rows[$i][0] -split '<br>')) {
                        if ([string]::IsNullOrWhiteSpace($seg)) { continue }
                        if ($first) { $out.Add("> **$seg**"); $first = $false }
                        else { $out.Add('>'); $out.Add("> $seg") }
                    }
                }
            }
            else {
                for ($i = 0; $i -lt $rows.Count; $i++) {
                    $c = @($rows[$i])
                    while ($c.Count -lt $maxCols) { $c += '' }
                    $out.Add('| ' + ($c -join ' | ') + ' |')
                    if ($i -eq 0) {
                        $out.Add('|' + (' --- |' * $maxCols))
                    }
                }
            }
            $out.Add('')
        }
    }
    if ($inCode) { $out.Add('```') }

    # --- 머리말: 이게 canon이 아니라는 것을 파일 자체가 말하게 한다 ---
    $srcName = Split-Path $DocxPath -Leaf
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $header = @(
        '<!-- 자동 생성 파일. 직접 편집하지 마라. tools/docx_to_md.ps1 로 재생성한다. -->'
        '# 설정서 v1.1 — 마크다운 참고 사본'
        ''
        '> **이 파일은 canon이 아니다. 참고 사본이다.**'
        '>'
        ('> canon 원본은 `docs/' + $srcName + '` 이며, 이 사본과 원본이 다르면 **언제나 원본이 이긴다.**')
        '> 여기를 고쳐서 설정을 바꿀 수 없다. 설정을 바꾸려면 원본 docx를 고치고 이 스크립트를 다시 돌린다.'
        '>'
        '> 존재 이유: 저장소에서 컨텍스트를 복원하는 AI 에이전트(GitHub 브라우징 등)가 docx 바이너리를'
        '> 읽지 못하기 때문이다. `docs/SETTING_BIBLE_v1.1_README.md` 의 "오너 승인 하에 마크다운'
        '> 변환본을 함께 둘 수 있다" 조항에 따라 2026-08-17 오너 승인으로 추가했다.'
        '>'
        '> 구조화된 색인이 필요하면 [docs/canon/INDEX.md](canon/INDEX.md) 를 봐라.'
        '> 이 파일은 원문 그대로이고, 그쪽은 ID가 붙은 검색용 색인이다.'
        ''
        ('`원본: ' + $srcName + ' · 생성: ' + $stamp + ' · tools/docx_to_md.ps1`')
        ''
        '---'
        ''
    )

    # 빈 줄 3개 이상은 2개로 접는다
    $text = ($header + $out) -join "`n"
    $text = [regex]::Replace($text, "(\r?\n){3,}", "`n`n")

    Set-Content -Path $OutPath -Value $text -Encoding utf8 -NoNewline
    Add-Content -Path $OutPath -Value "`n" -Encoding utf8

    Write-Host "생성 완료: $OutPath"
    Write-Host ("  문단/표 노드 " + $body.ChildNodes.Count + " 개 처리")

    # ------------------------------------------------------------------
    # 자기 검증 — 원본의 모든 문단이 출력물에 남아 있는지 확인한다.
    #
    # 이건 선택 사항이 아니다. 이 파일은 canon 사본이고, 조용히 한 문단이 빠지면
    # 그걸 읽는 에이전트는 "그런 규칙은 없다"고 판단해버린다. 변환기가 스스로
    # 증명하지 못하면 사본을 신뢰할 근거가 없다.
    # ------------------------------------------------------------------
    $srcParas = @()
    foreach ($p in $doc.SelectNodes('//w:p', $ns)) {
        $t = (($p.SelectNodes('.//w:t', $ns) | ForEach-Object { $_.InnerText }) -join '').Trim()
        if ($t.Length -gt 0) { $srcParas += $t }
    }
    # 비교 전에 표 이스케이프와 줄바꿈 표기를 되돌리고 공백을 전부 지운다
    $norm = (($text -replace '\\\|', '|') -replace '<br>', '') -replace '\s+', ''
    $missing = @()
    foreach ($s in $srcParas) {
        if (-not $norm.Contains(($s -replace '\s+', ''))) { $missing += $s }
    }

    Write-Host ("  검증: 원본 문단 " + $srcParas.Count + " 개 중 누락 " + $missing.Count + " 개")
    if ($missing.Count -gt 0) {
        Write-Host "  !! 누락된 문단 (출력물을 신뢰하지 마라):" -ForegroundColor Red
        $missing | Select-Object -First 20 | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        throw "변환 검증 실패: 문단 $($missing.Count) 개가 출력물에 없다."
    }
    Write-Host "  검증 통과 — 원본 텍스트가 모두 보존됐다." -ForegroundColor Green
}
finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
}
