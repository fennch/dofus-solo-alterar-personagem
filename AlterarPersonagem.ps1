# Alterar Personagem - Dofus Solo
# https://github.com/fennch/dofus-solo-alterar-personagem
#
# Altera os personagens do Dofus Solo (offline) com o jogo fechado:
#  - Resetar: mesma regra do reinicio do proprio servidor do jogo (CharacterReset, ResetKeepScrolls=1).
#      Caracteristicas voltam ao que veio de pergaminho; capital livre = (nivel - 1) x 5.
#      Feiticos acima do nivel 1 voltam ao 1 e devolvem N x (N - 1) / 2 pontos. Nenhum feitico e esquecido.
#  - Pergaminhos: define quanto de pergaminho cada caracteristica tem (0 a 101), sem mexer nos
#      pontos naturais. Fica anotado em characters_scroll_stats, que o reset preserva.
# Acha a pasta do jogo sozinha (lugar padrao, atalhos, programas instalados, discos) ou pede para escolher.
# Antes de cada alteracao, guarda uma copia do save em data\saves_backup.
# O jogo precisa estar fechado (o servidor guarda os personagens na memoria e gravaria por cima).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Titulo = 'Alterar Personagem'
$PastaConfig = Join-Path $env:APPDATA 'AlterarPersonagemDofusSolo'
$ArquivoConfig = Join-Path $PastaConfig 'pasta_do_jogo.txt'

# ---------- onde está o jogo ----------
# Uma pasta só vale se tiver o banco, o servidor e os scripts do Dofus Solo.
function Test-Raiz([string]$p) {
    if (-not $p) { return $false }
    try {
        foreach ($f in @('tools\mysql\bin\mysql.exe', 'tools\mysql\bin\mysqld.exe', 'tools\mysql\my.ini',
                         'scripts\Dofus23.ps1', 'server\dofussolo\Database.xml', 'data\mysql')) {
            if (-not (Test-Path -LiteralPath (Join-Path $p $f))) { return $false }
        }
        return $true
    } catch { return $false }
}

# Sobe a partir de uma pasta até achar a raiz do jogo (um atalho pode apontar para uma subpasta)
function Subir-Ate-Raiz([string]$p) {
    for ($i = 0; $p -and $i -lt 5; $i++) {
        if (Test-Raiz $p) { return $p }
        $p = Split-Path -Parent $p
    }
    return $null
}

function Candidatos-Atalhos {
    $pastas = @(
        [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('StartMenu'), [Environment]::GetFolderPath('CommonStartMenu')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $sh = New-Object -ComObject WScript.Shell
    foreach ($pasta in $pastas) {
        Get-ChildItem -LiteralPath $pasta -Filter '*.lnk' -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -like '*Dofus*Solo*' } |
            ForEach-Object {
                try {
                    $a = $sh.CreateShortcut($_.FullName)
                    if ($a.WorkingDirectory) { $a.WorkingDirectory }
                    if ($a.TargetPath) { Split-Path -Parent $a.TargetPath }
                    # atalhos que chamam powershell/cmd com o script do jogo nos argumentos
                    foreach ($m in [regex]::Matches([string]$a.Arguments, '"([^"]+)"|(\S+\.(ps1|exe|cmd))')) {
                        $v = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
                        if ($v -match '[\\/]') { Split-Path -Parent $v }
                    }
                } catch { }
            }
    }
}

function Candidatos-Registro {
    $chaves = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    foreach ($k in $chaves) {
        Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Dofus*Solo*' } | ForEach-Object {
            if ($_.InstallLocation) { $_.InstallLocation }
            if ($_.DisplayIcon) { Split-Path -Parent (($_.DisplayIcon -split ',')[0].Trim('"')) }
            if ($_.UninstallString) { $u = ($_.UninstallString -replace '^"([^"]+)".*$', '$1'); Split-Path -Parent $u }
        }
    }
}

function Candidatos-Discos {
    $nomes = @('Dofus Solo', 'DofusSolo', 'Dofus-Solo')
    $bases = @()
    foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        $bases += $d.Root
        foreach ($sub in @('Program Files', 'Program Files (x86)', 'Games', 'Jogos', 'Programas')) { $bases += (Join-Path $d.Root $sub) }
    }
    $bases += (Join-Path $env:LOCALAPPDATA 'Programs')
    $bases += [Environment]::GetFolderPath('Desktop')
    $bases += [Environment]::GetFolderPath('MyDocuments')
    $bases += (Join-Path $env:USERPROFILE 'Downloads')
    foreach ($b in $bases) {
        foreach ($n in $nomes) { Join-Path $b $n }
        # pastas com "Dofus" no nome, um nível abaixo (ex.: D:\Jogos\Dofus Solo 1.0.2)
        Get-ChildItem -LiteralPath $b -Directory -Filter '*Dofus*' -ErrorAction SilentlyContinue | ForEach-Object {
            $_.FullName
            Get-ChildItem -LiteralPath $_.FullName -Directory -Filter '*Dofus*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }
    }
}

function Achar-Jogo {
    # 1) pasta já confirmada antes
    if (Test-Path -LiteralPath $ArquivoConfig) {
        $salva = (Get-Content -LiteralPath $ArquivoConfig -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($salva) { $salva = $salva.Trim() }
        if (Test-Raiz $salva) { return $salva }
    }
    # 2) lugar padrão, 3) atalhos, 4) programas instalados, 5) pastas comuns nos discos
    $grupos = @(
        { @((Join-Path $env:LOCALAPPDATA 'Programs\Dofus Solo'), (Join-Path $env:ProgramFiles 'Dofus Solo')) },
        { Candidatos-Atalhos },
        { Candidatos-Registro },
        { Candidatos-Discos }
    )
    $vistos = @{}
    foreach ($g in $grupos) {
        foreach ($c in @(& $g)) {
            if (-not $c) { continue }
            $c = [string]$c
            if ($vistos.ContainsKey($c)) { continue }
            $vistos[$c] = $true
            $r = Subir-Ate-Raiz $c
            if ($r) { return $r }
        }
    }
    return $null
}

function Salvar-Pasta([string]$p) {
    New-Item -ItemType Directory -Force -Path $PastaConfig | Out-Null
    Set-Content -LiteralPath $ArquivoConfig -Value $p -Encoding UTF8
}

# Pede para a pessoa escolher a pasta, explicando como achar. Devolve o caminho ou $null.
function Escolher-Pasta([string]$motivo) {
    $explica = "$motivo`n`n" +
        "Como achar a pasta do jogo:`n" +
        "1. Clique com o botão direito no atalho do Dofus Solo (na área de trabalho ou no Menu Iniciar).`n" +
        "2. Escolha ""Abrir local do arquivo"". Se abrir uma pasta com o nome ""scripts"" ou ""jogo"", volte uma pasta.`n" +
        "3. A pasta certa tem dentro as pastas data, jogo, scripts, server e tools.`n`n" +
        "Se não tiver atalho, o lugar padrão é:`n$env:LOCALAPPDATA\Programs\Dofus Solo`n" +
        "(para chegar lá, cole %LOCALAPPDATA%\Programs na barra de endereço do Explorador de Arquivos)`n`n" +
        "Clique em OK para escolher a pasta."
    while ($true) {
        $r = [System.Windows.Forms.MessageBox]::Show($explica, $Titulo, 'OKCancel', 'Information')
        if ($r -ne 'OK') { return $null }
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Escolha a pasta do Dofus Solo (a que tem data, jogo, scripts, server e tools dentro)'
        $dlg.ShowNewFolderButton = $false
        $padrao = Join-Path $env:LOCALAPPDATA 'Programs'
        if (Test-Path -LiteralPath $padrao) { $dlg.SelectedPath = $padrao }
        if ($dlg.ShowDialog() -ne 'OK') { return $null }
        $escolhida = Subir-Ate-Raiz $dlg.SelectedPath
        if (-not $escolhida) {
            # talvez a pessoa tenha escolhido a pasta de cima: procura um nível abaixo
            $escolhida = Get-ChildItem -LiteralPath $dlg.SelectedPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Raiz $_.FullName } | Select-Object -First 1 -ExpandProperty FullName
        }
        if ($escolhida) { Salvar-Pasta $escolhida; return $escolhida }
        $explica = "A pasta ""$($dlg.SelectedPath)"" não é a do Dofus Solo (não encontrei as pastas data, scripts, server e tools com os arquivos do jogo).`n`n" +
                   "Tente de novo: a pasta certa tem dentro as pastas data, jogo, scripts, server e tools.`n`nClique em OK para escolher outra pasta."
    }
}

$Root = Achar-Jogo
if ($Root) { Salvar-Pasta $Root }
else {
    $Root = Escolher-Pasta 'Não encontrei o Dofus Solo neste computador automaticamente.'
    if (-not $Root) { exit 1 }
}

# ---------- configuração do jogo (lida dos arquivos dele) ----------
function Ler-Chave([string]$arquivo, [string]$chave, $padrao) {
    try {
        foreach ($l in (Get-Content -LiteralPath $arquivo -ErrorAction Stop)) {
            if ($l -match "^\s*$([regex]::Escape($chave))\s*=\s*(.*?)\s*$") { return $Matches[1] }
        }
    } catch { }
    return $padrao
}
$DbXml   = Join-Path $Root 'server\dofussolo\Database.xml'
$CfgXml  = Join-Path $Root 'server\dofussolo\Config.xml'
$Banco   = Ler-Chave $DbXml 'Database' 'dofussolo'
$DbUser  = Ler-Chave $DbXml 'Username' 'root'
$DbSenha = Ler-Chave $DbXml 'Password' ''
$MysqlPort = [int](Ler-Chave $DbXml 'Port' (Ler-Chave (Join-Path $Root 'tools\mysql\my.ini') 'port' '3308'))
$WorldPort = [int](Ler-Chave $CfgXml 'WorldPort' '5566')
$Scripts   = Join-Path $Root 'scripts'
$Tools     = Join-Path $Root 'tools'
$MysqlBin  = Join-Path $Tools 'mysql\bin'
$MyIni     = Join-Path $Tools 'mysql\my.ini'
$MysqlDir  = Join-Path $Tools 'mysql'
$MysqlData = Join-Path $Root 'data\mysql'
$JogoDir   = Join-Path $Root 'jogo'
$Juncao    = Join-Path ([System.IO.Path]::GetPathRoot($JogoDir)) 'Dofus23'
$LogFile   = Join-Path $PSScriptRoot 'alteracoes.log'
$utf8      = New-Object System.Text.UTF8Encoding($false)

$Classes = @{ 1 = 'Feca'; 2 = 'Osamodas'; 3 = 'Enutrof'; 4 = 'Sram'; 5 = 'Xelor'; 6 = 'Ecaflip'; 7 = 'Eniripsa'; 8 = 'Iop'
              9 = 'Cra'; 10 = 'Sadida'; 11 = 'Sacrier'; 12 = 'Pandawa'; 13 = 'Ladino'; 14 = 'Zobal'; 15 = 'Steamer' }
# Colunas de characters_stats / characters_scroll_stats e o nome no jogo
$Stats = @(
    @{ Col = 'Vitality';     Nome = 'Vitalidade' },
    @{ Col = 'Wisdom';       Nome = 'Sabedoria' },
    @{ Col = 'Strength';     Nome = 'Força' },
    @{ Col = 'Intelligence'; Nome = 'Inteligência' },
    @{ Col = 'Chance';       Nome = 'Sorte' },
    @{ Col = 'Agility';      Nome = 'Agilidade' }
)

function Log([string]$m) {
    try { Add-Content -Path $LogFile -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $m) -Encoding UTF8 } catch { }
}
function Test-Porta([int]$p) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $c.Connect('127.0.0.1', $p); return $true } catch { return $false } finally { $c.Close() }
}
function Get-DotnetProc([string]$dll) {
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$dll*" }
}
function Jogo-Aberto {
    [bool](Get-Process UpLauncher, adl, Dofus, Reg -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Juncao\*" -or $_.Path -like "$JogoDir\*" })
}
function Servidor-Ligado { [bool](Test-Porta $WorldPort) -or [bool](Get-DotnetProc 'DofusSolo.dll') }

# Espera um processo sem travar a janela
function Esperar([System.Diagnostics.Process]$p, [int]$ms) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $p.WaitForExit(150)) {
        [System.Windows.Forms.Application]::DoEvents()
        if ($sw.ElapsedMilliseconds -gt $ms) { try { $p.Kill() } catch { }; return $false }
    }
    $p.WaitForExit()
    return $true
}
function Rodar-PS([string]$arquivo, [string]$argumentos, [int]$ms) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command powershell.exe).Source
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$arquivo`" $argumentos"
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not (Esperar $p $ms)) { throw "$(Split-Path -Leaf $arquivo) demorou demais." }
    return $p.ExitCode
}

# Roda SQL no banco do jogo (pela entrada do mysql.exe) e devolve as linhas (separadas por tab)
function Sql([string]$comando) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $MysqlBin 'mysql.exe'
    $psi.Arguments = "--user=$DbUser --host=127.0.0.1 --port=$MysqlPort --default-character-set=utf8mb4 -N -B $Banco"
    if ($DbSenha) { $psi.EnvironmentVariables['MYSQL_PWD'] = $DbSenha }
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8; $psi.StandardErrorEncoding = $utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $saida = $p.StandardOutput.ReadToEndAsync()
    $erro = $p.StandardError.ReadToEndAsync()
    $w = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, $utf8)
    $w.Write($comando); $w.Flush(); $w.Close()
    if (-not (Esperar $p 120000)) { throw 'O banco de dados não respondeu.' }
    if ($p.ExitCode -ne 0) { throw ("Erro do banco: " + $erro.Result.Trim()) }
    return @($saida.Result -split "`r?`n" | Where-Object { $_ -ne '' })
}

$script:BancoLigadoPorMim = $false
function Ligar-Banco {
    if (Test-Porta $MysqlPort) { return }
    Start-Process -FilePath (Join-Path $MysqlBin 'mysqld.exe') -WindowStyle Hidden -ArgumentList `
        "`"--defaults-file=$MyIni`" `"--basedir=$MysqlDir`" `"--datadir=$MysqlData`" `"--log-error=$(Join-Path $MysqlData 'mysql-error.log')`""
    $script:BancoLigadoPorMim = $true
    for ($i = 0; $i -lt 900 -and -not (Test-Porta $MysqlPort); $i++) { Start-Sleep -Milliseconds 200; [System.Windows.Forms.Application]::DoEvents() }
    if (-not (Test-Porta $MysqlPort)) { throw 'O banco de dados não ligou em 3 minutos.' }
}
function Desligar-Banco {
    if (-not $script:BancoLigadoPorMim) { return }
    if (Servidor-Ligado) { return }   # alguém abriu o jogo enquanto isso: deixa o banco ligado
    try { if (-not (Test-Path (Join-Path $Scripts 'registrar_desligamento.ps1'))) { throw 'sem registro' }; . (Join-Path $Scripts 'registrar_desligamento.ps1'); Registrar-Desligamento 'AlterarPersonagem.ps1' 'desliga o banco que ele mesmo ligou para alterar personagens' 'banco' } catch { }
    if ($DbSenha) { $env:MYSQL_PWD = $DbSenha }
    & (Join-Path $MysqlBin 'mysqladmin.exe') "--user=$DbUser" --host=127.0.0.1 "--port=$MysqlPort" shutdown 2>$null
    $script:BancoLigadoPorMim = $false
}

# ---------- leitura dos personagens ----------
$DDLPergaminhos = @"
CREATE TABLE IF NOT EXISTS ``characters_scroll_stats`` (
  ``OwnerId`` int NOT NULL,
  ``Vitality`` int NOT NULL DEFAULT '0',
  ``Wisdom`` int NOT NULL DEFAULT '0',
  ``Strength`` int NOT NULL DEFAULT '0',
  ``Intelligence`` int NOT NULL DEFAULT '0',
  ``Chance`` int NOT NULL DEFAULT '0',
  ``Agility`` int NOT NULL DEFAULT '0',
  PRIMARY KEY (``OwnerId``)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
"@

function Ler-Personagens {
    $colsBase = ($Stats | ForEach-Object { "IFNULL(s.$($_.Col),0)" }) -join ', '
    $colsPerg = ($Stats | ForEach-Object { "IFNULL(sc.$($_.Col),0)" }) -join ', '
    $q = $DDLPergaminhos + @"
SELECT c.Id, REPLACE(c.Name, '\t', ' '), c.Breed, c.Level, c.StatsPoints, c.SpellsPoints,
       $colsBase, $colsPerg,
       IF(sc.OwnerId IS NULL, 0, 1),
       IFNULL((SELECT COUNT(*) FROM characters_spells sp WHERE sp.OwnerId = c.Id AND sp.Level > 1), 0),
       IFNULL((SELECT SUM(sp.Level * (sp.Level - 1) DIV 2) FROM characters_spells sp WHERE sp.OwnerId = c.Id AND sp.Level > 1), 0),
       IF(s.OwnerId IS NULL, 0, 1)
FROM characters c
LEFT JOIN characters_stats s ON s.OwnerId = c.Id
LEFT JOIN characters_scroll_stats sc ON sc.OwnerId = c.Id
ORDER BY c.Id;
"@
    $lista = @()
    foreach ($linha in (Sql $q)) {
        $v = $linha -split "`t"
        if ($v.Count -lt 22) { continue }
        $n = [int[]]($v[2..21] | ForEach-Object { [int]$_ })
        $pc = [pscustomobject]@{
            Id = [int]$v[0]; Nome = $v[1]; Breed = $n[0]; Level = $n[1]; StatsPoints = $n[2]; SpellsPoints = $n[3]
            Base = @{}; Perg = @{}; TemLinhaPerg = ($n[16] -eq 1)
            FeiticosAcima = $n[17]; PontosFeitico = $n[18]; TemStats = ($n[19] -eq 1)
        }
        for ($i = 0; $i -lt 6; $i++) {
            $pc.Base[$Stats[$i].Col] = $n[4 + $i]
            $pc.Perg[$Stats[$i].Col] = $n[10 + $i]
        }
        $lista += $pc
    }
    return $lista
}

# O que o reset faria (mesma conta do servidor)
function Calcular($pc) {
    $novo = @{}; $mudaCarac = $false; $pergMantidos = 0
    foreach ($s in $Stats) {
        $base = [Math]::Max(0, $pc.Base[$s.Col])
        $fica = [Math]::Min([Math]::Max(0, $pc.Perg[$s.Col]), $base)
        $novo[$s.Col] = $fica
        $pergMantidos += $fica
        if ($fica -ne $base) { $mudaCarac = $true }
    }
    $capital = [Math]::Max([Math]::Max(0, ($pc.Level - 1) * 5), $pc.StatsPoints)
    if ($capital -ne $pc.StatsPoints) { $mudaCarac = $true }
    [pscustomobject]@{
        Novo = $novo; Capital = $capital; MudaCarac = ($mudaCarac -and $pc.TemStats); PergMantidos = $pergMantidos
        MudaFeit = ($pc.FeiticosAcima -gt 0); FeitDepois = $pc.SpellsPoints + $pc.PontosFeitico
    }
}

function Aplicar($pc, [bool]$carac, [bool]$feit) {
    $r = Calcular $pc
    $sql = New-Object System.Text.StringBuilder
    [void]$sql.AppendLine('SET autocommit = 0;')
    [void]$sql.AppendLine('START TRANSACTION;')
    if ($carac -and $r.MudaCarac) {
        $sets = ($Stats | ForEach-Object { "$($_.Col) = $([int]$r.Novo[$_.Col])" }) -join ', '
        [void]$sql.AppendLine("UPDATE characters_stats SET $sets WHERE OwnerId = $($pc.Id);")
        if ($pc.TemLinhaPerg) {
            $vals = ($Stats | ForEach-Object { [int]$r.Novo[$_.Col] }) -join ', '
            [void]$sql.AppendLine("REPLACE INTO characters_scroll_stats (OwnerId, Vitality, Wisdom, Strength, Intelligence, Chance, Agility) VALUES ($($pc.Id), $vals);")
        }
        [void]$sql.AppendLine("UPDATE characters SET StatsPoints = $([int]$r.Capital) WHERE Id = $($pc.Id);")
    }
    if ($feit -and $r.MudaFeit) {
        [void]$sql.AppendLine("UPDATE characters SET SpellsPoints = SpellsPoints + (SELECT IFNULL(SUM(Level * (Level - 1) DIV 2), 0) FROM characters_spells WHERE OwnerId = $($pc.Id) AND Level > 1) WHERE Id = $($pc.Id);")
        [void]$sql.AppendLine("UPDATE characters_spells SET Level = 1 WHERE OwnerId = $($pc.Id) AND Level > 1;")
    }
    [void]$sql.AppendLine('COMMIT;')
    Sql $sql.ToString() | Out-Null
    Log ("{0} (id {1}): caracteristicas={2} feiticos={3} | capital {4} -> {5}, feitico {6} -> {7}, pergaminho mantido {8}" -f `
        $pc.Nome, $pc.Id, $carac, $feit, $pc.StatsPoints, $(if ($carac) { $r.Capital } else { $pc.StatsPoints }), $pc.SpellsPoints, $(if ($feit) { $r.FeitDepois } else { $pc.SpellsPoints }), $r.PergMantidos)
}

function Fazer-Backup {
    $script = Join-Path $Scripts 'backup_save.ps1'
    if (Test-Path -LiteralPath $script) {
        $codigo = Rodar-PS $script '-Tipo manual' 600000
        if ($codigo -ne 0) { throw "A cópia de segurança do save falhou (código $codigo). Nada foi alterado. Veja data\saves_backup\backup.log." }
        return
    }
    # versão do jogo sem o script de backup: faz uma cópia do banco direto
    $pasta = Join-Path $Root 'data\saves_backup'
    New-Item -ItemType Directory -Force -Path $pasta | Out-Null
    $arq = Join-Path $pasta ("Alterar Personagem - {0:dd-MM-yyyy HH}h{0:mm}.sql" -f (Get-Date))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $MysqlBin 'mysqldump.exe'
    $psi.Arguments = "--user=$DbUser --host=127.0.0.1 --port=$MysqlPort --default-character-set=utf8mb4 --single-transaction --result-file=`"$arq`" $Banco"
    if ($DbSenha) { $psi.EnvironmentVariables['MYSQL_PWD'] = $DbSenha }
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not (Esperar $p 600000) -or $p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $arq)) {
        throw 'A cópia de segurança do save falhou. Nada foi alterado.'
    }
}

# Confere se o save tem as tabelas e colunas que esta aplicação usa (versões novas do jogo podem mudar)
$script:BancoConferido = $false
function Conferir-Banco {
    if ($script:BancoConferido) { return }
    $precisa = @{
        'characters'       = @('Id', 'Name', 'Breed', 'Level', 'StatsPoints', 'SpellsPoints')
        'characters_stats' = @('OwnerId', 'Vitality', 'Wisdom', 'Strength', 'Intelligence', 'Chance', 'Agility')
        'characters_spells'= @('OwnerId', 'Level')
    }
    $linhas = Sql ("SELECT LOWER(TABLE_NAME), LOWER(COLUMN_NAME) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '$Banco';")
    $tem = @{}
    foreach ($l in $linhas) { $tem[$l.ToLower()] = $true }
    $faltam = @()
    foreach ($t in $precisa.Keys) {
        foreach ($c in $precisa[$t]) { if (-not $tem.ContainsKey(("{0}`t{1}" -f $t, $c).ToLower())) { $faltam += "$t.$c" } }
    }
    if ($faltam.Count -gt 0) {
        throw ("Esta versão do Dofus Solo guarda os personagens de um jeito diferente do esperado (faltam: " + ($faltam -join ', ') + "). Por segurança, nada foi alterado.")
    }
    $script:BancoConferido = $true
}


# ---------- pergaminhos ----------
# Cada característica = pontos naturais + pontos de pergaminho (o pergaminho fica anotado em characters_scroll_stats,
# que é o que o reset do jogo e desta aplicação preserva). Aqui o pergaminho de cada característica vai para o valor
# escolhido (0 a 101) e os pontos naturais não mudam.
$MaxPergaminho = 101

function Naturais($pc, [string]$col) {
    $base = [Math]::Max(0, $pc.Base[$col])
    return $base - [Math]::Min([Math]::Max(0, $pc.Perg[$col]), $base)
}

function Aplicar-Pergaminhos($pc, [hashtable]$novoPerg) {
    $sets = @(); $vals = @(); $resumo = @()
    foreach ($s in $Stats) {
        $c = $s.Col
        $atual = [Math]::Min([Math]::Max(0, $pc.Perg[$c]), [Math]::Max(0, $pc.Base[$c]))
        $novo = if ($novoPerg.ContainsKey($c)) { [int]$novoPerg[$c] } else { $atual }
        $novo = [Math]::Max(0, [Math]::Min($MaxPergaminho, $novo))
        $sets += "$c = $((Naturais $pc $c) + $novo)"
        $vals += $novo
        if ($novo -ne $atual) { $resumo += "$($s.Nome) $atual->$novo" }
    }
    if ($resumo.Count -eq 0) { return $false }
    $sql = "SET autocommit = 0;`nSTART TRANSACTION;`n" +
           "UPDATE characters_stats SET $($sets -join ', ') WHERE OwnerId = $($pc.Id);`n" +
           "REPLACE INTO characters_scroll_stats (OwnerId, Vitality, Wisdom, Strength, Intelligence, Chance, Agility) VALUES ($($pc.Id), $($vals -join ', '));`n" +
           "COMMIT;`n"
    Sql $sql | Out-Null
    Log ("{0} (id {1}): pergaminhos {2}" -f $pc.Nome, $pc.Id, ($resumo -join ', '))
    return $true
}

# ---------- janela ----------
$fonte = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Alterar Personagem - Dofus Solo'
$form.Size = New-Object System.Drawing.Size(860, 590)
$form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = $fonte

$lista = New-Object System.Windows.Forms.ListView
$lista.View = 'Details'; $lista.FullRowSelect = $true; $lista.MultiSelect = $false; $lista.HideSelection = $false
$lista.Location = New-Object System.Drawing.Point(12, 12)
$lista.Size = New-Object System.Drawing.Size(330, 450)
[void]$lista.Columns.Add('Personagem', 150)
[void]$lista.Columns.Add('Classe', 95)
[void]$lista.Columns.Add('Nível', 55)
$form.Controls.Add($lista)

$btnAtualizar = New-Object System.Windows.Forms.Button
$btnAtualizar.Text = 'Atualizar lista'
$btnAtualizar.Size = New-Object System.Drawing.Size(120, 30)
$btnAtualizar.Location = New-Object System.Drawing.Point(12, 470)
$form.Controls.Add($btnAtualizar)

$btnPasta = New-Object System.Windows.Forms.Button
$btnPasta.Text = 'Pasta do jogo...'
$btnPasta.Size = New-Object System.Drawing.Size(120, 30)
$btnPasta.Location = New-Object System.Drawing.Point(12, 506)
$form.Controls.Add($btnPasta)

$lblPasta = New-Object System.Windows.Forms.Label
$lblPasta.AutoSize = $false
$lblPasta.Location = New-Object System.Drawing.Point(140, 512)
$lblPasta.Size = New-Object System.Drawing.Size(692, 22)
$lblPasta.ForeColor = [System.Drawing.Color]::Gray
$lblPasta.Text = "Jogo em: $Root"
$form.Controls.Add($lblPasta)

$abas = New-Object System.Windows.Forms.TabControl
$abas.Location = New-Object System.Drawing.Point(354, 12)
$abas.Size = New-Object System.Drawing.Size(478, 450)
$form.Controls.Add($abas)

# --- aba Resetar ---
$abaReset = New-Object System.Windows.Forms.TabPage
$abaReset.Text = 'Resetar'
$abaReset.UseVisualStyleBackColor = $true
[void]$abas.TabPages.Add($abaReset)

$detalhe = New-Object System.Windows.Forms.TextBox
$detalhe.Multiline = $true; $detalhe.ReadOnly = $true; $detalhe.ScrollBars = 'Vertical'
$detalhe.Font = New-Object System.Drawing.Font('Consolas', 10)
$detalhe.BackColor = [System.Drawing.Color]::White
$detalhe.Location = New-Object System.Drawing.Point(8, 8)
$detalhe.Size = New-Object System.Drawing.Size(454, 290)
$abaReset.Controls.Add($detalhe)

$chkCarac = New-Object System.Windows.Forms.CheckBox
$chkCarac.Text = 'Resetar características (mantém os pontos de pergaminho)'
$chkCarac.Checked = $true; $chkCarac.AutoSize = $true
$chkCarac.Location = New-Object System.Drawing.Point(8, 308)
$abaReset.Controls.Add($chkCarac)

$chkFeit = New-Object System.Windows.Forms.CheckBox
$chkFeit.Text = 'Resetar feitiços (todos voltam ao nível 1, pontos devolvidos)'
$chkFeit.Checked = $true; $chkFeit.AutoSize = $true
$chkFeit.Location = New-Object System.Drawing.Point(8, 332)
$abaReset.Controls.Add($chkFeit)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = 'Resetar'
$btnReset.Size = New-Object System.Drawing.Size(120, 32)
$btnReset.Location = New-Object System.Drawing.Point(342, 372)
$btnReset.Enabled = $false
$abaReset.Controls.Add($btnReset)

# --- aba Pergaminhos ---
$abaPerg = New-Object System.Windows.Forms.TabPage
$abaPerg.Text = 'Pergaminhos'
$abaPerg.UseVisualStyleBackColor = $true
[void]$abas.TabPages.Add($abaPerg)

$lblPergTopo = New-Object System.Windows.Forms.Label
$lblPergTopo.AutoSize = $false
$lblPergTopo.Location = New-Object System.Drawing.Point(8, 8)
$lblPergTopo.Size = New-Object System.Drawing.Size(454, 40)
$lblPergTopo.Text = "Escolha quanto de pergaminho cada característica deve ter (0 a $MaxPergaminho). Os pontos naturais não mudam."
$abaPerg.Controls.Add($lblPergTopo)

$cab = @(@{ T = 'Característica'; X = 8 }, @{ T = 'Naturais'; X = 150 }, @{ T = 'Pergaminho'; X = 230 }, @{ T = 'Novo pergaminho'; X = 318 })
foreach ($c in $cab) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $c.T; $l.AutoSize = $true
    $l.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $l.Location = New-Object System.Drawing.Point($c.X, 56)
    $abaPerg.Controls.Add($l)
}

$script:LinhasPerg = @{}
$y = 84
foreach ($s in $Stats) {
    $lNome = New-Object System.Windows.Forms.Label
    $lNome.Text = $s.Nome; $lNome.AutoSize = $true
    $lNome.Location = New-Object System.Drawing.Point(8, ($y + 3))
    $abaPerg.Controls.Add($lNome)

    $lNat = New-Object System.Windows.Forms.Label
    $lNat.AutoSize = $true; $lNat.Location = New-Object System.Drawing.Point(150, ($y + 3))
    $abaPerg.Controls.Add($lNat)

    $lPerg = New-Object System.Windows.Forms.Label
    $lPerg.AutoSize = $true; $lPerg.Location = New-Object System.Drawing.Point(230, ($y + 3))
    $abaPerg.Controls.Add($lPerg)

    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Minimum = 0; $num.Maximum = $MaxPergaminho
    $num.Size = New-Object System.Drawing.Size(70, 26)
    $num.Location = New-Object System.Drawing.Point(318, $y)
    $abaPerg.Controls.Add($num)

    $b101 = New-Object System.Windows.Forms.Button
    $b101.Text = "$MaxPergaminho"
    $b101.Size = New-Object System.Drawing.Size(50, 26)
    $b101.Location = New-Object System.Drawing.Point(396, ($y - 1))
    $b101.Tag = $num
    $b101.Add_Click({ $this.Tag.Value = $MaxPergaminho })
    $abaPerg.Controls.Add($b101)

    $script:LinhasPerg[$s.Col] = @{ Nat = $lNat; Perg = $lPerg; Num = $num }
    $y += 34
}

$btnTodos101 = New-Object System.Windows.Forms.Button
$btnTodos101.Text = "$MaxPergaminho em todos"
$btnTodos101.Size = New-Object System.Drawing.Size(130, 30)
$btnTodos101.Location = New-Object System.Drawing.Point(8, ($y + 8))
$abaPerg.Controls.Add($btnTodos101)

$btnDesfazerPerg = New-Object System.Windows.Forms.Button
$btnDesfazerPerg.Text = 'Voltar ao atual'
$btnDesfazerPerg.Size = New-Object System.Drawing.Size(120, 30)
$btnDesfazerPerg.Location = New-Object System.Drawing.Point(146, ($y + 8))
$abaPerg.Controls.Add($btnDesfazerPerg)

$btnPerg = New-Object System.Windows.Forms.Button
$btnPerg.Text = 'Aplicar pergaminhos'
$btnPerg.Size = New-Object System.Drawing.Size(150, 32)
$btnPerg.Location = New-Object System.Drawing.Point(312, ($y + 7))
$btnPerg.Enabled = $false
$abaPerg.Controls.Add($btnPerg)

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point(140, 476)
$status.Size = New-Object System.Drawing.Size(692, 28)
$form.Controls.Add($status)

$script:Personagens = @()
function Status([string]$m, $cor = [System.Drawing.Color]::DimGray) {
    $status.Text = $m; $status.ForeColor = $cor
    [System.Windows.Forms.Application]::DoEvents()
}
function Ocupado([bool]$sim) {
    $form.UseWaitCursor = $sim
    $lista.Enabled = -not $sim; $btnAtualizar.Enabled = -not $sim; $abas.Enabled = -not $sim
    $tem = ($lista.SelectedItems.Count -gt 0)
    $btnReset.Enabled = (-not $sim) -and $tem
    $btnPerg.Enabled = (-not $sim) -and $tem
    [System.Windows.Forms.Application]::DoEvents()
}
function Selecionado {
    if ($lista.SelectedItems.Count -eq 0) { return $null }
    $id = [int]$lista.SelectedItems[0].Tag
    return $script:Personagens | Where-Object { $_.Id -eq $id } | Select-Object -First 1
}

function Mostrar-Pergaminhos {
    $pc = Selecionado
    foreach ($s in $Stats) {
        $l = $script:LinhasPerg[$s.Col]
        if (-not $pc) { $l.Nat.Text = '-'; $l.Perg.Text = '-'; $l.Num.Value = 0; continue }
        $atual = [Math]::Min([Math]::Max(0, $pc.Perg[$s.Col]), [Math]::Max(0, $pc.Base[$s.Col]))
        $l.Nat.Text = [string](Naturais $pc $s.Col)
        $l.Perg.Text = [string]$atual
        $l.Num.Value = [Math]::Min($MaxPergaminho, $atual)
    }
    $btnPerg.Enabled = [bool]$pc
}

function Mostrar-Detalhe {
    Mostrar-Pergaminhos
    $pc = Selecionado
    if (-not $pc) { $detalhe.Text = 'Escolha um personagem na lista.'; $btnReset.Enabled = $false; return }
    $r = Calcular $pc
    $t = New-Object System.Text.StringBuilder
    $classe = if ($Classes.ContainsKey($pc.Breed)) { $Classes[$pc.Breed] } else { "classe $($pc.Breed)" }
    [void]$t.AppendLine("$($pc.Nome)  ($classe, nível $($pc.Level))")
    [void]$t.AppendLine('')
    [void]$t.AppendLine('CARACTERÍSTICAS          agora  pergam.  depois')
    foreach ($s in $Stats) {
        [void]$t.AppendLine(('  {0,-20} {1,7} {2,8} {3,7}' -f $s.Nome, $pc.Base[$s.Col], $pc.Perg[$s.Col], $r.Novo[$s.Col]))
    }
    [void]$t.AppendLine(('  {0,-20} {1,7} {2,8} {3,7}' -f 'Capital livre', $pc.StatsPoints, '', $r.Capital))
    if (-not $r.MudaCarac) { [void]$t.AppendLine('  (nada para resetar nas características)') }
    [void]$t.AppendLine('')
    [void]$t.AppendLine('FEITIÇOS')
    if ($r.MudaFeit) {
        [void]$t.AppendLine("  $($pc.FeiticosAcima) feitiço(s) acima do nível 1 voltam ao nível 1")
        [void]$t.AppendLine("  Pontos de feitiço: $($pc.SpellsPoints) -> $($r.FeitDepois)  (+$($pc.PontosFeitico))")
    } else {
        [void]$t.AppendLine('  Todos já estão no nível 1 (nada para resetar)')
        [void]$t.AppendLine("  Pontos de feitiço livres: $($pc.SpellsPoints)")
    }
    $detalhe.Text = $t.ToString()
    $btnReset.Enabled = $true
}

function Carregar-Lista {
    Ocupado $true
    try {
        Status 'Lendo os personagens...'
        $sel = if ($lista.SelectedItems.Count -gt 0) { [int]$lista.SelectedItems[0].Tag } else { -1 }
        $script:Personagens = @(Ler-Personagens)
        $lista.BeginUpdate(); $lista.Items.Clear()
        foreach ($pc in $script:Personagens) {
            $classe = if ($Classes.ContainsKey($pc.Breed)) { $Classes[$pc.Breed] } else { "$($pc.Breed)" }
            $it = New-Object System.Windows.Forms.ListViewItem($pc.Nome)
            [void]$it.SubItems.Add($classe); [void]$it.SubItems.Add([string]$pc.Level)
            $it.Tag = $pc.Id
            [void]$lista.Items.Add($it)
            if ($pc.Id -eq $sel) { $it.Selected = $true }
        }
        $lista.EndUpdate()
        if ($lista.SelectedItems.Count -eq 0 -and $lista.Items.Count -gt 0) { $lista.Items[0].Selected = $true }
        Status ("{0} personagem(ns). Escolha um personagem e o que quer alterar." -f $script:Personagens.Count)
    }
    catch { Status ("Erro ao ler os personagens: " + $_.Exception.Message) ([System.Drawing.Color]::Firebrick) }
    finally { Ocupado $false; Mostrar-Detalhe }
}

# Garante jogo fechado, servidor desligado e banco ligado. Devolve $true se pode mexer.
function Preparar {
    if (Jogo-Aberto) {
        [System.Windows.Forms.MessageBox]::Show("O jogo está aberto. Feche todas as janelas do Dofus e tente de novo.", 'Alterar Personagem', 'OK', 'Warning') | Out-Null
        return $false
    }
    if (Servidor-Ligado) {
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "O servidor do jogo ainda está ligado. Ele guarda os personagens na memória e gravaria por cima da alteração.`n`n" +
            "Posso desligá-lo agora do jeito normal do jogo (ele salva e faz backup antes)?",
            'Alterar Personagem', 'YesNo', 'Question')
        if ($resp -ne 'Yes') { return $false }
        Status 'Desligando o servidor do jogo (salvando e fazendo backup)... pode levar um minuto.'
        Rodar-PS (Join-Path $Scripts 'Dofus23.ps1') 'parar' 600000 | Out-Null
        for ($i = 0; $i -lt 100 -and (Servidor-Ligado); $i++) { Start-Sleep -Milliseconds 200; [System.Windows.Forms.Application]::DoEvents() }
        if (Servidor-Ligado) { throw 'O servidor não desligou. Feche o launcher do jogo e tente de novo.' }
    }
    if (-not (Test-Porta $MysqlPort)) { Status 'Ligando o banco de dados do jogo...'; Ligar-Banco }
    Conferir-Banco
    return $true
}

# Relê o personagem do banco (pode ter mudado desde que a lista foi aberta)
function Reler($id) {
    $script:Personagens = @(Ler-Personagens)
    $pc = $script:Personagens | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $pc) { throw 'Personagem não encontrado no banco.' }
    return $pc
}

function Mostrar-Erro($e) {
    Log ("ERRO: " + $e.Exception.Message)
    Status ("Erro: " + $e.Exception.Message) ([System.Drawing.Color]::Firebrick)
    [System.Windows.Forms.MessageBox]::Show("Não deu certo: $($e.Exception.Message)`n`nA alteração é feita numa transação: se falhou, nada foi gravado.", 'Alterar Personagem', 'OK', 'Error') | Out-Null
}

$lista.Add_SelectedIndexChanged({ Mostrar-Detalhe })
$btnPasta.Add_Click({
    $nova = Escolher-Pasta "A pasta do jogo usada agora é:`n$Root`n`nPara trocar, escolha a pasta do Dofus Solo."
    if ($nova -and $nova -ne $Root) {
        try { Desligar-Banco } catch { }
        Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $form.Close()
    }
})
$btnAtualizar.Add_Click({
    try { if (Preparar) { Carregar-Lista } } catch { Status ("Erro: " + $_.Exception.Message) ([System.Drawing.Color]::Firebrick) }
})

$btnReset.Add_Click({
    $pc = Selecionado
    if (-not $pc) { return }
    $carac = $chkCarac.Checked; $feit = $chkFeit.Checked
    if (-not $carac -and -not $feit) { Status 'Marque características, feitiços ou os dois.' ([System.Drawing.Color]::DarkOrange); return }
    $r = Calcular $pc
    if ((-not ($carac -and $r.MudaCarac)) -and (-not ($feit -and $r.MudaFeit))) { Status "$($pc.Nome): não há nada para resetar no que foi marcado." ([System.Drawing.Color]::DarkOrange); return }
    $o = @()
    if ($carac -and $r.MudaCarac) { $o += "características (capital livre: $($pc.StatsPoints) -> $($r.Capital); pergaminhos mantidos)" }
    if ($feit -and $r.MudaFeit) { $o += "feitiços (pontos de feitiço: $($pc.SpellsPoints) -> $($r.FeitDepois))" }
    $resp = [System.Windows.Forms.MessageBox]::Show("Resetar $($pc.Nome)?`n`n- " + ($o -join "`n- ") + "`n`nAntes, uma cópia do save será guardada em data\saves_backup.", 'Confirmar', 'YesNo', 'Question')
    if ($resp -ne 'Yes') { return }
    Ocupado $true
    try {
        if (-not (Preparar)) { return }
        $pc = Reler $pc.Id
        Status 'Guardando uma cópia de segurança do save...'
        Fazer-Backup
        Status "Resetando $($pc.Nome)..."
        Aplicar $pc $carac $feit
        Carregar-Lista
        Status "$($pc.Nome) resetado. Pode abrir o jogo." ([System.Drawing.Color]::ForestGreen)
    }
    catch { Mostrar-Erro $_ }
    finally { Ocupado $false; Mostrar-Detalhe }
})

$btnTodos101.Add_Click({ foreach ($l in $script:LinhasPerg.Values) { $l.Num.Value = $MaxPergaminho } })
$btnDesfazerPerg.Add_Click({ Mostrar-Pergaminhos })

$btnPerg.Add_Click({
    $pc = Selecionado
    if (-not $pc) { return }
    $novo = @{}; $o = @()
    foreach ($s in $Stats) {
        $v = [int]$script:LinhasPerg[$s.Col].Num.Value
        $atual = [Math]::Min([Math]::Max(0, $pc.Perg[$s.Col]), [Math]::Max(0, $pc.Base[$s.Col]))
        $novo[$s.Col] = $v
        if ($v -ne $atual) {
            $nat = Naturais $pc $s.Col
            $o += "$($s.Nome): pergaminho $atual -> $v (total $($nat + $atual) -> $($nat + $v))"
        }
    }
    if ($o.Count -eq 0) { Status "$($pc.Nome): nenhum pergaminho mudou." ([System.Drawing.Color]::DarkOrange); return }
    $resp = [System.Windows.Forms.MessageBox]::Show("Aplicar pergaminhos em $($pc.Nome)?`n`n- " + ($o -join "`n- ") + "`n`nAntes, uma cópia do save será guardada em data\saves_backup.", 'Confirmar', 'YesNo', 'Question')
    if ($resp -ne 'Yes') { return }
    Ocupado $true
    try {
        if (-not (Preparar)) { return }
        $pc = Reler $pc.Id
        Status 'Guardando uma cópia de segurança do save...'
        Fazer-Backup
        Status "Aplicando pergaminhos em $($pc.Nome)..."
        [void](Aplicar-Pergaminhos $pc $novo)
        Carregar-Lista
        Status "Pergaminhos aplicados em $($pc.Nome). Pode abrir o jogo." ([System.Drawing.Color]::ForestGreen)
    }
    catch { Mostrar-Erro $_ }
    finally { Ocupado $false; Mostrar-Detalhe }
})

$form.Add_Shown({
    $detalhe.Text = 'Escolha um personagem na lista.'
    try {
        if (Preparar) { Carregar-Lista }
        else { Status 'Feche o jogo e clique em "Atualizar lista".' ([System.Drawing.Color]::DarkOrange) }
    }
    catch { Status ("Erro: " + $_.Exception.Message) ([System.Drawing.Color]::Firebrick) }
})
$form.Add_FormClosed({ try { Desligar-Banco } catch { } })

[void]$form.ShowDialog()
