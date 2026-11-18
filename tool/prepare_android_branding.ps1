# Convert only the outlined, translated SVG paths exported by FigCraft.
# Re-run after exporting approved source SVGs; never approximate the mark.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $repo 'design/branding/exports'
$outputDir = Join-Path $repo 'android/app/src/main/res/drawable'
$androidNs = 'http://schemas.android.com/apk/res/android'
$specs = @(
    @{Source='routina-adaptive-foreground.svg'; Target='routina_icon_foreground.xml'; Dp=108},
    @{Source='routina-adaptive-monochrome.svg'; Target='routina_icon_monochrome.xml'; Dp=108},
    @{Source='routina-splash-icon-android12.svg'; Target='routina_splash.xml'; Dp=288}
)
foreach ($spec in $specs) {
    [xml]$svg = Get-Content -Raw -LiteralPath (Join-Path $sourceDir $spec.Source)
    $namespaces = [Xml.XmlNamespaceManager]::new($svg.NameTable)
    $namespaces.AddNamespace('s', 'http://www.w3.org/2000/svg')
    if ($svg.SelectNodes('//s:image|//s:text|//s:use', $namespaces).Count) {
        throw 'Only editable outlined paths are supported.'
    }
    foreach ($group in $svg.SelectNodes('//s:g', $namespaces)) {
        if ($group.HasAttribute('transform')) { throw 'Group transforms require explicit review.' }
    }
    $viewBox = $svg.svg.viewBox -split ' '
    if ($viewBox.Count -ne 4 -or $viewBox[0] -ne '0' -or $viewBox[1] -ne '0') {
        throw 'Expected a zero-origin FigCraft frame.'
    }
    $paths = $svg.SelectNodes('/s:svg/s:g//s:path', $namespaces)
    if ($paths.Count -eq 0) { throw 'No exported artwork paths found.' }
    $output = [Xml.XmlDocument]::new()
    [void]$output.AppendChild($output.CreateXmlDeclaration('1.0', 'utf-8', $null))
    [void]$output.AppendChild($output.CreateComment(" FigCraft source: $($spec.Source); regenerate with tool/prepare_android_branding.ps1. "))
    $vector = $output.CreateElement('vector')
    $vector.SetAttribute('xmlns:android', $androidNs)
    [void]$vector.SetAttribute('width', $androidNs, "$($spec.Dp)dp")
    [void]$vector.SetAttribute('height', $androidNs, "$($spec.Dp)dp")
    [void]$vector.SetAttribute('viewportWidth', $androidNs, $viewBox[2])
    [void]$vector.SetAttribute('viewportHeight', $androidNs, $viewBox[3])
    [void]$output.AppendChild($vector)
    foreach ($path in $paths) {
        if ($path.HasAttribute('stroke') -or $path.fill -notmatch '^#[0-9A-Fa-f]{6}$') {
            throw 'Expected FigCraft to outline strokes and use solid brand fills.'
        }
        $matrix = [regex]::Match($path.transform, '^matrix\(1 0 0 1 (-?[\d.]+) (-?[\d.]+)\)$')
        if (-not $matrix.Success) { throw 'Only exported translation matrices are supported.' }
        $group = $output.CreateElement('group')
        [void]$group.SetAttribute('translateX', $androidNs, $matrix.Groups[1].Value)
        [void]$group.SetAttribute('translateY', $androidNs, $matrix.Groups[2].Value)
        $shape = $output.CreateElement('path')
        [void]$shape.SetAttribute('fillColor', $androidNs, $path.fill)
        [void]$shape.SetAttribute('fillType', $androidNs, 'nonZero')
        [void]$shape.SetAttribute('pathData', $androidNs, $path.d)
        [void]$group.AppendChild($shape)
        [void]$vector.AppendChild($group)
    }
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $writer = [Xml.XmlWriter]::Create((Join-Path $outputDir $spec.Target), $settings)
    try { $output.Save($writer) } finally { $writer.Dispose() }
    Write-Output "Generated $($spec.Target) from $($paths.Count) FigCraft paths."
}
