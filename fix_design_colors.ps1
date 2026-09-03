# Fix hardcoded neon colors → ODAT brand palette
# Run from: D:\odat123\Flowa

$files = Get-ChildItem -Path ".\lib" -Filter "*.dart" -Recurse

$replacements = @(
    # 5BC8FA (bright cyan) → 4AADDC (ODAT sky cyan)
    @{ From = '0xFF5BC8FA'; To = '0xFF4AADDC' },
    @{ From = '0xAA5BC8FA'; To = '0xAA4AADDC' },
    @{ From = '0x885BC8FA'; To = '0x884AADDC' },
    @{ From = '0x665BC8FA'; To = '0x664AADDC' },
    @{ From = '0x445BC8FA'; To = '0x444AADDC' },
    @{ From = '0x335BC8FA'; To = '0x334AADDC' },
    @{ From = '0x225BC8FA'; To = '0x224AADDC' },
    @{ From = '0x1A5BC8FA'; To = '0x1A4AADDC' },
    @{ From = '0x0D5BC8FA'; To = '0x0D4AADDC' },
    
    # 3B9BFF (neon blue) → 3A7FCC (ODAT ocean blue)
    @{ From = '0xFF3B9BFF'; To = '0xFF3A7FCC' },
    @{ From = '0xAA3B9BFF'; To = '0xAA3A7FCC' },
    @{ From = '0x883B9BFF'; To = '0x883A7FCC' },
    @{ From = '0x443B9BFF'; To = '0x443A7FCC' },
    @{ From = '0x333B9BFF'; To = '0x333A7FCC' },

    # 7B2FFF → 6B25CC (ODAT deep violet)
    @{ From = '0xFF7B2FFF'; To = '0xFF6B25CC' },
    @{ From = '0x447B2FFF'; To = '0x446B25CC' },
    @{ From = '0x227B2FFF'; To = '0x226B25CC' },

    # 00FF88 (toxic green) → 4AADDC (ODAT cyan — calm)
    @{ From = '0xFF00FF88'; To = '0xFF4AADDC' },
    @{ From = '0xAA00FF88'; To = '0xAA4AADDC' },
    @{ From = '0x6600FF88'; To = '0x664AADDC' },
    @{ From = '0x4400FF88'; To = '0x444AADDC' },
    @{ From = '0x2200FF88'; To = '0x224AADDC' },
    @{ From = '0x1100FF88'; To = '0x114AADDC' },

    # 39FF14 (neon lime/green) → 4AADDC (ODAT cyan)
    @{ From = '0xFF39FF14'; To = '0xFF4AADDC' },
    @{ From = '0x6639FF14'; To = '0x664AADDC' },
    @{ From = '0x4439FF14'; To = '0x444AADDC' },
    @{ From = '0x2239FF14'; To = '0x224AADDC' },

    # FF0055 (neon red/pink) → keep as error/danger color - no change needed
    # FFB703 (gold) → keep as reward color - no change needed

    # 080B14 / 070B13 / 0D1220 / 04050D backgrounds → unify to 04050D
    @{ From = "Color(0xFF080B14)"; To = "Color(0xFF04050D)" },
    @{ From = "Color(0xFF070B13)"; To = "Color(0xFF04050D)" },
    @{ From = "Color(0xFF0D1220)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF0C101A)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF0C1628)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF0F1523)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF080B14)"; To = "Color(0xFF04050D)" },
    @{ From = "Color(0xFF101726)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF141C2D)"; To = "Color(0xFF0E1020)" },
    @{ From = "Color(0xFF131929)"; To = "Color(0xFF090B18)" },
    @{ From = "Color(0xFF151F33)"; To = "Color(0xFF0E1020)" }
)

$count = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $changed = $false
    
    foreach ($r in $replacements) {
        if ($content -match [regex]::Escape($r.From)) {
            $content = $content -replace [regex]::Escape($r.From), $r.To
            $changed = $true
        }
    }
    
    if ($changed) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        $count++
        Write-Host "Fixed: $($file.Name)"
    }
}

Write-Host "`nDone! Fixed $count files."
