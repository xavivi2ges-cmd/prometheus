# --- PARCHE DE COMPATIBILIDAD GRÁFICA PARA WINDOWS ---
$registryPath = "HKCU:\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION"
$processName = [System.IO.Path]::GetFileName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
if (-not (Test-Path $registryPath)) { New-Item $registryPath -Force | Out-Null }
Set-ItemProperty -Path $registryPath -Name $processName -Value 11001 -Type DWord | Out-Null
Set-ItemProperty -Path $registryPath -Name "powershell.exe" -Value 11001 -Type DWord | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$global:VirtualFiles = @{}
$global:VirtualDatFiles = @{}
$global:CpdOriginalPath = ""
$global:DatOriginalPath = ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$htmlPath = Join-Path $scriptPath "motor.html"

# --- CONFIGURACIÓN DE LA SUITE A PANTALLA COMPLETA 1920x1080 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Game Stick Lite - Suite Prometheus v3.0 (HCSEMI Manager)"
$form.Size = New-Object System.Drawing.Size(1920, 1080)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$tabMenus = New-Object System.Windows.Forms.TabPage
$tabMenus.Text = "  EDITOR DE INTERFAZ (.CPD)  "
$tabMenus.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$tabJuegos = New-Object System.Windows.Forms.TabPage
$tabJuegos.Text = "  GESTOR DE JUEGOS (.DAT)  "
$tabJuegos.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$tabControl.Controls.Add($tabMenus)
$tabControl.Controls.Add($tabJuegos)

$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
$webBrowser.IsWebBrowserContextMenuEnabled = $false
$webBrowser.AllowWebBrowserDrop = $false
# =========================================================================
# MAQUETACIÓN PESTAÑA 1: INTERFAZ DE MENÚS (.CPD)
# =========================================================================
$panelCpdLeft = New-Object System.Windows.Forms.Panel
$panelCpdLeft.Size = New-Object System.Drawing.Size(280, 1040)
$panelCpdLeft.Dock = [System.Windows.Forms.DockStyle]::Left
$panelCpdLeft.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

$btnLoadCpd = New-Object System.Windows.Forms.Button
$btnLoadCpd.Text = "CARGAR RESOURCE.CPD / .WQW"
$btnLoadCpd.Size = New-Object System.Drawing.Size(260, 45)
$btnLoadCpd.Location = New-Object System.Drawing.Point(10, 15)
$btnLoadCpd.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLoadCpd.ForeColor = [System.Drawing.Color]::White
$btnLoadCpd.BackColor = [System.Drawing.Color]::FromArgb(74, 74, 229)
$btnLoadCpd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnSaveCpd = New-Object System.Windows.Forms.Button
$btnSaveCpd.Text = "GUARDAR CONTENEDOR FINAL"
$btnSaveCpd.Size = New-Object System.Drawing.Size(260, 45)
$btnSaveCpd.Location = New-Object System.Drawing.Point(10, 75)
$btnSaveCpd.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveCpd.ForeColor = [System.Drawing.Color]::White
$btnSaveCpd.BackColor = [System.Drawing.Color]::FromArgb(92, 184, 92)
$btnSaveCpd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$listBoxCpd = New-Object System.Windows.Forms.ListBox
$listBoxCpd.Location = New-Object System.Drawing.Point(10, 135)
$listBoxCpd.Size = New-Object System.Drawing.Size(260, 840)
$listBoxCpd.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$listBoxCpd.ForeColor = [System.Drawing.Color]::LightGray
$listBoxCpd.Font = New-Object System.Drawing.Font("Consolas", 10)
$listBoxCpd.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$panelCpdLeft.Controls.Add($btnLoadCpd)
$panelCpdLeft.Controls.Add($btnSaveCpd)
$panelCpdLeft.Controls.Add($listBoxCpd)
$tabMenus.Controls.Add($panelCpdLeft)

$btnLoadCpd.Add_Click({
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Filter = "Firmware Game Stick (*.cpd;*.wqw)|*.cpd;*.wqw"
    $openDialog.Title = "Selecciona el archivo Resource del firmware"
    
    if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:CpdOriginalPath = $openDialog.FileName
        $bytes = [System.IO.File]::ReadAllBytes($global:CpdOriginalPath)
        $len = $bytes.Length
        $po = 0

        while ($po + 30 -le $len) {
            if ($bytes[$po] -eq 0x57 -and $bytes[$po+1] -eq 0x51 -and $bytes[$po+2] -eq 0x57 -and $bytes[$po+3] -eq 0x03) {
                $bytes[$po] = 0x50; $bytes[$po+1] = 0x4b; $bytes[$po+2] = 0x03; $bytes[$po+3] = 0x04
                $compSz = [System.BitConverter]::ToUInt32($bytes, $po + 18)
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 26)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $po += 30
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen + $compSz
            } else { break }
        }
        while ($po + 46 -le $len) {
            if ($bytes[$po] -eq 0x57 -and $bytes[$po+1] -eq 0x51 -and $bytes[$po+2] -eq 0x57 -and $bytes[$po+3] -eq 0x02) {
                $bytes[$po] = 0x50; $bytes[$po+1] = 0x4b; $bytes[$po+2] = 0x01; $bytes[$po+3] = 0x02
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 30)
                $po += 46
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen
            } else { break }
        }
        for ($i = $len - 4; $i -ge $po; $i--) {
            if ($bytes[$i] -eq 0x57 -and $bytes[$i+1] -eq 0x51 -and $bytes[$i+2] -eq 0x57 -and $bytes[$i+3] -eq 0x01) {
                $bytes[$i] = 0x50; $bytes[$i+1] = 0x4b; $bytes[$i+2] = 0x05; $bytes[$i+3] = 0x06; break
            }
        }

        $tempZip = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllBytes($tempZip, $bytes)
        $archive = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
        
        $listBoxCpd.Items.Clear()
        $global:VirtualFiles.Clear()

        foreach ($entry in $archive.Entries) {
            if (-not [string]::IsNullOrEmpty($entry.Name)) {
                $entryStream = $entry.Open()
                $ms = New-Object System.IO.MemoryStream
                $entryStream.CopyTo($ms)
                $global:VirtualFiles[$entry.Name.ToLower()] = $ms.ToArray()
                $listBoxCpd.Items.Add($entry.Name)
                $entryStream.Close(); $ms.Close()
            }
        }
        $archive.Dispose()
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    }
})

$listBoxCpd.Add_SelectedIndexChanged({
    if ($listBoxCpd.SelectedItem -eq $null) { return }
    if ($tabMenus.Controls.Contains($webBrowser) -eq $false) { $tabMenus.Controls.Add($webBrowser) }
    
    $selectedFileName = $listBoxCpd.SelectedItem.ToString()
    $rawBytes = $global:VirtualFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }
    $base64String = [System.Convert]::ToBase64String($rawBytes)
    $webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String)) | Out-Null
})
# =========================================================================
# MAQUETACIÓN PESTAÑA 2: GESTOR DE JUEGOS Y LISTADOS (.DAT)
# =========================================================================
$panelDatLeft = New-Object System.Windows.Forms.Panel
$panelDatLeft.Size = New-Object System.Drawing.Size(280, 1080)
$panelDatLeft.Dock = [System.Windows.Forms.DockStyle]::Left
$panelDatLeft.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

$btnLoadDat = New-Object System.Windows.Forms.Button
$btnLoadDat.Text = "CARGAR ARCHIVO .DAT"
$btnLoadDat.Size = New-Object System.Drawing.Size(260, 45)
$btnLoadDat.Location = New-Object System.Drawing.Point(10, 15)
$btnLoadDat.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLoadDat.ForeColor = [System.Drawing.Color]::White
$btnLoadDat.BackColor = [System.Drawing.Color]::FromArgb(230, 126, 34)
$btnLoadDat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnSaveDat = New-Object System.Windows.Forms.Button
$btnSaveDat.Text = "GUARDAR .DAT MODIFICADO"
$btnSaveDat.Size = New-Object System.Drawing.Size(260, 45)
$btnSaveDat.Location = New-Object System.Drawing.Point(10, 75)
$btnSaveDat.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveDat.ForeColor = [System.Drawing.Color]::White
$btnSaveDat.BackColor = [System.Drawing.Color]::FromArgb(211, 84, 0)
$btnSaveDat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$listBoxDat = New-Object System.Windows.Forms.ListBox
$listBoxDat.Location = New-Object System.Drawing.Point(10, 135)
$listBoxDat.Size = New-Object System.Drawing.Size(260, 840)
$listBoxDat.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$listBoxDat.ForeColor = [System.Drawing.Color]::LightGray
$listBoxDat.Font = New-Object System.Drawing.Font("Consolas", 10)
$listBoxDat.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$panelDatLeft.Controls.Add($btnLoadDat)
$panelDatLeft.Controls.Add($btnSaveDat)
$panelDatLeft.Controls.Add($listBoxDat)
$tabJuegos.Controls.Add($panelDatLeft)

$btnLoadDat.Add_Click({
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Filter = "Contenedor Juegos Game Stick (*.dat)|*.dat"
    $openDialog.Title = "Selecciona ROOT.DAT o un emulador 000-014.dat"
    
    if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:DatOriginalPath = $openDialog.FileName
        $bytes = [System.IO.File]::ReadAllBytes($global:DatOriginalPath)
        $len = $bytes.Length
        $po = 0

        while ($po + 30 -le $len) {
            if ($bytes[$po] -eq 0x57 -and $bytes[$po+1] -eq 0x51 -and $bytes[$po+2] -eq 0x57 -and $bytes[$po+3] -eq 0x03) {
                $bytes[$po] = 0x50; $bytes[$po+1] = 0x4b; $bytes[$po+2] = 0x03; $bytes[$po+3] = 0x04
                $compSz = [System.BitConverter]::ToUInt32($bytes, $po + 18)
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 26)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $po += 30
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen + $compSz
            } else { break }
        }
        while ($po + 46 -le $len) {
            if ($bytes[$po] -eq 0x57 -and $bytes[$po+1] -eq 0x51 -and $bytes[$po+2] -eq 0x57 -and $bytes[$po+3] -eq 0x02) {
                $bytes[$po] = 0x50; $bytes[$po+1] = 0x4b; $bytes[$po+2] = 0x01; $bytes[$po+3] = 0x02
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 30)
                $po += 46
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen
            } else { break }
        }
        for ($i = $len - 4; $i -ge $po; $i--) {
            if ($bytes[$i] -eq 0x57 -and $bytes[$i+1] -eq 0x51 -and $bytes[$i+2] -eq 0x57 -and $bytes[$i+3] -eq 0x01) {
                $bytes[$i] = 0x50; $bytes[$i+1] = 0x4b; $bytes[$i+2] = 0x05; $bytes[$i+3] = 0x06; break
            }
        }

        $tempZip = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllBytes($tempZip, $bytes)
        $archive = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
        
        $listBoxDat.Items.Clear()
        $global:VirtualDatFiles.Clear()

        foreach ($entry in $archive.Entries) {
            if (-not [string]::IsNullOrEmpty($entry.Name)) {
                $entryStream = $entry.Open()
                $ms = New-Object System.IO.MemoryStream
                $entryStream.CopyTo($ms)
                $global:VirtualDatFiles[$entry.Name.ToLower()] = $ms.ToArray()
                $listBoxDat.Items.Add($entry.Name)
                $entryStream.Close(); $ms.Close()
            }
        }
        $archive.Dispose()
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    }
})

$listBoxDat.Add_SelectedIndexChanged({
    if ($listBoxDat.SelectedItem -eq $null) { return }
    if ($tabJuegos.Controls.Contains($webBrowser) -eq $false) { $tabJuegos.Controls.Add($webBrowser) }
    
    $selectedFileName = $listBoxDat.SelectedItem.ToString()
    $rawBytes = $global:VirtualDatFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }
    $base64String = [System.Convert]::ToBase64String($rawBytes)
    $webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String)) | Out-Null
})
# --- INTERCEPTOR DUAL CON CANDADO ANTI-REPETICION ---
$global:LastSavedFile = ""
$global:LastSavedTime = [DateTime]::MinValue

$webBrowser.Add_DocumentTitleChanged({
    $title = $webBrowser.DocumentTitle
    if ($title -and $title.StartsWith("SAVERAW:")) {
        $payload = $title.Substring(8)
        $separatorIdx = $payload.IndexOf("|")
        if ($separatorIdx -gt 0) {
            $fileName = $payload.Substring(0, $separatorIdx)
            $base64Data = $payload.Substring($separatorIdx + 1)
            
            $now = [DateTime]::Now
            $timeDiff = ($now - $global:LastSavedTime).TotalSeconds
            if ($fileName -eq $global:LastSavedFile -and $timeDiff -lt 1.5) { return }
            
            $global:LastSavedFile = $fileName
            $global:LastSavedTime = $now
            $binData = [System.Convert]::FromBase64String($base64Data)

            if ($tabControl.SelectedIndex -eq 0) {
                $global:VirtualFiles[$fileName.ToLower()] = $binData
            } else {
                $global:VirtualDatFiles[$fileName.ToLower()] = $binData
            }
            [System.Windows.Forms.MessageBox]::Show("Cambios aplicados temporalmente en memoria para: $fileName`n`nNo olvides pulsar el boton Guardar del panel izquierdo al terminar.", "Exito Prometheus", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        $webBrowser.Document.Title = "Suite Motor Grafico Game Stick Lite"
    }
})

# --- RE-EMPAQUETADOR BINARIO EXCLUSIVO PARA ARCHIVOS .DAT ---
$btnSaveDat.Add_Click({
    if ($global:DatOriginalPath -eq "" -or $global:VirtualDatFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Primero debes cargar un archivo .dat.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    try {
        $backupPath = $global:DatOriginalPath + ".backup"
        if (-not (Test-Path $backupPath)) { [System.IO.File]::Copy($global:DatOriginalPath, $backupPath, $true) }

        $tempZip = [System.IO.Path]::GetTempFileName()
        $stream = [System.IO.File]::Open($tempZip, [System.IO.FileMode]::OpenOrCreate)
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)

        foreach ($key in $global:VirtualDatFiles.Keys) {
            $origName = ""
            foreach ($item in $listBoxDat.Items) { if ($item.ToLower() -eq $key) { $origName = $item; break } }
            if ($origName -eq "") { $origName = $key }
            $entry = $archive.CreateEntry($origName, [System.IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            $fileBytes = $global:VirtualDatFiles[$key]
            $entryStream.Write($fileBytes, 0, $fileBytes.Length)
            $entryStream.Close()
        }
        $archive.Dispose(); $stream.Close()

        $bytes = [System.IO.File]::ReadAllBytes($tempZip)
        $len = $bytes.Length
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

        $po = 0
        while ($po + 30 -le $len) {
            if ($bytes[$po] -eq 0x50 -and $bytes[$po+1] -eq 0x4b -and $bytes[$po+2] -eq 0x03 -and $bytes[$po+3] -eq 0x04) {
                $bytes[$po] = 0x57; $bytes[$po+1] = 0x51; $bytes[$po+2] = 0x57; $bytes[$po+3] = 0x03
                $compSz = [System.BitConverter]::ToUInt32($bytes, $po + 18)
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 26)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $po += 30
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen + $compSz
            } else { break }
        }
        while ($po + 46 -le $len) {
            if ($bytes[$po] -eq 0x50 -and $bytes[$po+1] -eq 0x4b -and $bytes[$po+2] -eq 0x01 -and $bytes[$po+3] -eq 0x02) {
                $bytes[$po] = 0x57; $bytes[$po+1] = 0x51; $bytes[$po+2] = 0x57; $bytes[$po+3] = 0x02
                $nameLen = [System.BitConverter]::ToUInt16($bytes, $po + 28)
                $extraLen = [System.BitConverter]::ToUInt16($bytes, $po + 30)
                $po += 46
                if ($po + $nameLen -le $len) { for ($pi = 0; $pi -lt $nameLen; $pi++) { $bytes[$po] = $bytes[$po] -bxor 0xe5; $po++ } }
                $po += $extraLen
            } else { break }
        }
        for ($i = $len - 4; $i -ge $po; $i--) {
            if ($bytes[$i] -eq 0x50 -and $bytes[$i+1] -eq 0x4b -and $bytes[$i+2] -eq 0x05 -and $bytes[$i+3] -eq 0x06) {
                $bytes[$i] = 0x57; $bytes[$i+1] = 0x51; $bytes[$i+2] = 0x57; $bytes[$i+3] = 0x01; break
            }
        }
        [System.IO.File]::WriteAllBytes($global:DatOriginalPath, $bytes)
        [System.Windows.Forms.MessageBox]::Show("Contenedor de juegos .DAT reconstruido con exito. Copia guardada en .backup", "Operacion Completada", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error critico en DAT: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# =========================================================================
# ARRANQUE GENERAL DE PROMETHEUS
# =========================================================================
$tabMenus.Controls.Add($webBrowser)
$form.Controls.Add($tabControl)

if (Test-Path $htmlPath) { $webBrowser.Navigate($htmlPath) } 
else { [System.Windows.Forms.MessageBox]::Show("No se encontro el archivo motor.html", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) }

$form.ShowDialog() | Out-Null
