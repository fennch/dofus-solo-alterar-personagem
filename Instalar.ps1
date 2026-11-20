# Instalador do Alterar Personagem (Dofus Solo)
# Copia a aplicação para uma pasta "Alterar Personagem" na área de trabalho e libera os arquivos baixados.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
$Titulo = 'Instalar Alterar Personagem'

try {
    $origem = $PSScriptRoot
    $arquivos = @('AlterarPersonagem.ps1', 'Alterar Personagem.cmd', 'LEIA-ME.md')
    foreach ($a in $arquivos) {
        if (-not (Test-Path -LiteralPath (Join-Path $origem $a))) {
            throw "Não achei o arquivo ""$a"" junto do instalador. Extraia o ZIP inteiro (botão direito no ZIP > Extrair Tudo) e rode o Instalar de dentro da pasta extraída."
        }
    }
    # Área de trabalho de verdade (funciona também quando ela fica no OneDrive)
    $desktop = [Environment]::GetFolderPath('Desktop')
    $destino = Join-Path $desktop 'Alterar Personagem'
    if ([System.IO.Path]::GetFullPath($origem).TrimEnd('\') -ieq [System.IO.Path]::GetFullPath($destino).TrimEnd('\')) {
        throw "O instalador já está na pasta da área de trabalho. Abra o ""Alterar Personagem.cmd"" daí mesmo."
    }
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    foreach ($a in $arquivos) {
        $alvo = Join-Path $destino $a
        Copy-Item -LiteralPath (Join-Path $origem $a) -Destination $alvo -Force
        Unblock-File -LiteralPath $alvo -ErrorAction SilentlyContinue
    }
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Instalado em:`n$destino`n`nPara usar, abra o ""Alterar Personagem.cmd"" dessa pasta (com o jogo fechado).`n`nQuer abrir agora?",
        $Titulo, 'YesNo', 'Information')
    if ($r -eq 'Yes') {
        Start-Process -FilePath (Get-Command powershell.exe).Source -WorkingDirectory $destino -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $destino 'AlterarPersonagem.ps1')`""
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show("A instalação não deu certo:`n`n$($_.Exception.Message)", $Titulo, 'OK', 'Error') | Out-Null
    exit 1
}
