# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 1 DE 5
# =========================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- VARIABLES GLOBALES ANTI-CRASH ---
$global:VirtualFiles = @{}
$global:VirtualDatFiles = @{}
$global:FolderOriginalPath = ""
$global:DatOriginalPath = ""
$global:LastSavedFile = ""
$global:LastSavedTime = [DateTime]::MinValue

# --- CONTROL DE RUTAS LINDANTES ---
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$htmlPath = Join-Path $scriptPath "motor.html"

# --- VENTANA PRINCIPAL (GUI) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Suite Prometheus v3.0 - Motor Grafico Game Stick Lite"
$form.Size = New-Object System.Drawing.Size(1920, 1080)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

# --- NAVEGADOR WEB ÚNICO ---
$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
$webBrowser.ScriptErrorsSuppressed = $true
# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 2 DE 5
# =========================================================================

# --- CONTENEDOR DE PESTAÑAS (TAB CONTROL) ---
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$tabMenus = New-Object System.Windows.Forms.TabPage
$tabMenus.Text = "  GESTOR DE MENUS (CARPETAS)  "
$tabMenus.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$tabJuegos = New-Object System.Windows.Forms.TabPage
$tabJuegos.Text = "  GESTOR DE JUEGOS (.DAT)  "
$tabJuegos.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$tabControl.Controls.Add($tabMenus)
$tabControl.Controls.Add($tabJuegos)

# --- SOLUCIÓN AL BUG DE RENDERS: MIGRACIÓN DE CONTROL DINÁMICO ---
$tabControl.Add_SelectedIndexChanged({
    if ($tabControl.SelectedIndex -eq 0) {
        if ($tabJuegos.Controls.Contains($webBrowser)) { $tabJuegos.Controls.Remove($webBrowser) }
        if (-not $tabMenus.Controls.Contains($webBrowser)) { $tabMenus.Controls.Add($webBrowser) }
    } else {
        if ($tabMenus.Controls.Contains($webBrowser)) { $tabMenus.Controls.Remove($webBrowser) }
        # Nota: Se inyecta en $tabJuegos al hacer clic en un elemento de su lista
    }
})
# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 3 DE 5
# =========================================================================

# --- MAQUETACIÓN PANEL IZQUIERDO (MENUS) ---
$panelLeft = New-Object System.Windows.Forms.Panel
$panelLeft.Size = New-Object System.Drawing.Size(280, 1080)
$panelLeft.Dock = [System.Windows.Forms.DockStyle]::Left
$panelLeft.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

$btnLoadFolder = New-Object System.Windows.Forms.Button
$btnLoadFolder.Text = "CARGAR CARPETA DE MENU"
$btnLoadFolder.Size = New-Object System.Drawing.Size(260, 45)
$btnLoadFolder.Location = New-Object System.Drawing.Point(10, 15)
$btnLoadFolder.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLoadFolder.ForeColor = [System.Drawing.Color]::White
$btnLoadFolder.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$btnLoadFolder.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnSaveFolder = New-Object System.Windows.Forms.Button
$btnSaveFolder.Text = "GUARDAR CAMBIOS EN DISCO"
$btnSaveFolder.Size = New-Object System.Drawing.Size(260, 45)
$btnSaveFolder.Location = New-Object System.Drawing.Point(10, 75)
$btnSaveFolder.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveFolder.ForeColor = [System.Drawing.Color]::White
$btnSaveFolder.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$btnSaveFolder.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$listBoxFiles = New-Object System.Windows.Forms.ListBox
$listBoxFiles.Location = New-Object System.Drawing.Point(10, 135)
$listBoxFiles.Size = New-Object System.Drawing.Size(260, 840)
$listBoxFiles.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$listBoxFiles.ForeColor = [System.Drawing.Color]::LightGray
$listBoxFiles.Font = New-Object System.Drawing.Font("Consolas", 10)
$listBoxFiles.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$panelLeft.Controls.Add($btnLoadFolder)
$panelLeft.Controls.Add($btnSaveFolder)
$panelLeft.Controls.Add($listBoxFiles)
$tabMenus.Controls.Add($panelLeft)

# --- ACCIÓN: CARGAR CARPETA ---
$btnLoadFolder.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Selecciona la carpeta que contiene los archivos del menu"
    
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:FolderOriginalPath = $folderDialog.SelectedPath
        $listBoxFiles.Items.Clear()
        $global:VirtualFiles.Clear()
        
        $files = Get-ChildItem $global:FolderOriginalPath -File
        foreach ($file in $files) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $global:VirtualFiles[$file.Name.ToLower()] = $bytes
            $listBoxFiles.Items.Add($file.Name)
        }
    }
})

# --- ACCIÓN: SELECCIONAR ARCHIVO DE MENU ---
$listBoxFiles.Add_SelectedIndexChanged({
    if ($listBoxFiles.SelectedItem -eq $null) { return }
    $selectedFileName = $listBoxFiles.SelectedItem.ToString()
    $rawBytes = $global:VirtualFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }
    $base64String = [System.Convert]::ToBase64String($rawBytes)
    $webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String)) | Out-Null
})

# --- ACCIÓN: APLICAR CAMBIOS EN DISCO ---
$btnSaveFolder.Add_Click({
    if ($global:FolderOriginalPath -eq "" -or $global:VirtualFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Primero debes cargar una carpeta con archivos.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    try {
        foreach ($key in $global:VirtualFiles.Keys) {
            $origName = ""
            foreach ($item in $listBoxFiles.Items) { if ($item.ToLower() -eq $key) { $origName = $item; break } }
            if ($origName -eq "") { $origName = $key }
            $destPath = Join-Path $global:FolderOriginalPath $origName
            [System.IO.File]::WriteAllBytes($destPath, $global:VirtualFiles[$key])
        }
        [System.Windows.Forms.MessageBox]::Show("Archivos de menu guardados correctamente en disco.", "Operacion Completada", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error al guardar en disco: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 4 DE 5
# =========================================================================

# --- MAQUETACIÓN PANEL IZQUIERDO (JUEGOS .DAT) ---
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

# --- ACCIÓN: CARGAR Y PARSEAR ARCHIVO .DAT ---
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

# --- ACCIÓN: SELECCIONAR JUEGO DENTRO DEL .DAT ---
$listBoxDat.Add_SelectedIndexChanged({
    if ($listBoxDat.SelectedItem -eq $null) { return }
    if (-not $tabJuegos.Controls.Contains($webBrowser)) { $tabJuegos.Controls.Add($webBrowser) }
    
    $selectedFileName = $listBoxDat.SelectedItem.ToString()
    $rawBytes = $global:VirtualDatFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }
    $base64String = [System.Convert]::ToBase64String($rawBytes)
    $webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String)) | Out-Null
})
# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 4 DE 5
# =========================================================================

# --- MAQUETACIÓN PANEL IZQUIERDO (JUEGOS .DAT) ---
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

# --- ACCIÓN: CARGAR Y PARSEAR ARCHIVO .DAT ---
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

# --- ACCIÓN: SELECCIONAR JUEGO DENTRO DEL .DAT ---
$listBoxDat.Add_SelectedIndexChanged({
    if ($listBoxDat.SelectedItem -eq $null) { return }
    if (-not $tabJuegos.Controls.Contains($webBrowser)) { $tabJuegos.Controls.Add($webBrowser) }
    
    $selectedFileName = $listBoxDat.SelectedItem.ToString()
    $rawBytes = $global:VirtualDatFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }
    $base64String = [System.Convert]::ToBase64String($rawBytes)
    $webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String)) | Out-Null
})
# =========================================================================
# SUITE PROMETHEUS V3.0 - PARTE 5 DE 5 (INTERCEPTOR Y RE-EMPAQUETADOR)
# =========================================================================

# --- INTERCEPTOR DUAL CON CANDADO ANTI-REPETICIÓN ---
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
# ARRANQUE GENERAL DE LA SUITE
# =========================================================================
$tabMenus.Controls.Add($webBrowser)
$form.Controls.Add($tabControl)

if (Test-Path $htmlPath) { 
    $webBrowser.Navigate($htmlPath) 
} else { 
    [System.Windows.Forms.MessageBox]::Show("No se encontro el archivo motor.html en la ruta del script.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) 
}

$form.ShowDialog() | Out-Null
