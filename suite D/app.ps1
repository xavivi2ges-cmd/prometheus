# =========================================================================
# MOTOR 2: GESTOR DE JUEGOS Y LISTADOS (.DAT) 
# =========================================================================

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
$htmlPath = Join-Path $scriptPath "motor2.html"

# --- CONFIGURACIÓN DE LA SUITE A PANTALLA COMPLETA 1920x1080 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Game Stick Lite - Gestor de Juegos (Motor 2) v3.1"
$form.Size = New-Object System.Drawing.Size(1920, 1080)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

# --- INICIALIZACIÓN DEL NAVEGADOR WEB (CRÍTICO) ---
$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
$webBrowser.ScriptErrorsSuppressed = $true

# =========================================================================
# MAQUETACIÓN: PANEL DE CONTROL IZQUIERDO
# =========================================================================
$panelDatLeft = New-Object System.Windows.Forms.Panel
$panelDatLeft.Size = New-Object System.Drawing.Size(370, 1040)
$panelDatLeft.Dock = [System.Windows.Forms.DockStyle]::Left
$panelDatLeft.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

$btnLoadDat = New-Object System.Windows.Forms.Button
$btnLoadDat.Text = "CARGAR ARCHIVO .DAT"
$btnLoadDat.Size = New-Object System.Drawing.Size(350, 45)
$btnLoadDat.Location = New-Object System.Drawing.Point(10, 15)
$btnLoadDat.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLoadDat.ForeColor = [System.Drawing.Color]::White
$btnLoadDat.BackColor = [System.Drawing.Color]::FromArgb(230, 126, 34)
$btnLoadDat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnSaveDat = New-Object System.Windows.Forms.Button
$btnSaveDat.Text = "GUARDAR .DAT MODIFICADO"
$btnSaveDat.Size = New-Object System.Drawing.Size(350, 45)
$btnSaveDat.Location = New-Object System.Drawing.Point(10, 75)
$btnSaveDat.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveDat.ForeColor = [System.Drawing.Color]::White
$btnSaveDat.BackColor = [System.Drawing.Color]::FromArgb(211, 84, 0)
$btnSaveDat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# =========================================================================
# CONFIGURACIÓN DEL LISTBOX CON MODO DE DIBUJO PERSONALIZADO
# =========================================================================
$listBoxDat = New-Object System.Windows.Forms.ListBox
$listBoxDat.Location = New-Object System.Drawing.Point(10, 135)
$listBoxDat.Size = New-Object System.Drawing.Size(350, 872)
$listBoxDat.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$listBoxDat.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# ACTIVAMOS EL MODO OWNERDRAW: Le dice a Windows que nosotros pintaremos los colores uno a uno
$listBoxDat.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed

# CREAMOS LA FUENTE DEFINITIVA "CONSOLAS"
$fuenteConsolas = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)

# =========================================================================
# EVENTO DRAWITEM: MOTOR DE COLOR DUAL (VERDE / NARANJA / ROJO)
# =========================================================================
$listBoxDat.Add_DrawItem({
    param([object]$sender, [System.Windows.Forms.DrawItemEventArgs]$e)
    
    # Si la lista está vacía o el índice no es válido, salimos
    if ($e.Index -lt 0) { return }

    # 1. Recuperamos el objeto de la Tabla Conmutada mapeado en esa posición
    $itemActual = $listBoxDat.Items[$e.Index]

    # 2. Valores por defecto (Fondo original del ListBox)
    $colorFondo = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $colorTexto = [System.Drawing.Color]::LightGray # Por si acaso un ítem no tiene estado

    # 3. FILTRO DE COLORES POR ESTADO SEGÚN TUS INSTRUCCIONES
    if ($itemActual.Estado -eq "Ok") {
        # Verde: Juego con su carátula correcta en el DAT
        $colorTexto = [System.Drawing.Color]::LimeGreen
    } 
    elseif ($itemActual.Estado -eq "FaltaImagen") {
        # Naranja: Juego que no tiene carátula (Inyectará NO IMAGE.RAW)
        $colorTexto = [System.Drawing.Color]::DarkOrange
    } 
    elseif ($itemActual.Estado -eq "Huerfana") {
        # Rojo: Carátula suelta en el DAT sin juego asignado
        $colorTexto = [System.Drawing.Color]::Crimson
    }

    # 4. COMPROBACIÓN DE SELECCIÓN: Si el usuario hace clic en el renglón
    # Evitamos que falle si el índice no es válido o está fuera de rango
    if ($e.Index -lt 0) { return }

    # ¡NUEVO! Comprobamos si el elemento está seleccionado
    $estaSeleccionado = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected

    if ($estaSeleccionado) {
        # Elige aquí tu color de selección favorito para sustituir el verde pastel (ej: LightBlue, LightGray...)
        $brushFondo = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::LightBlue)
        $brushTexto = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Black)
    } else {
        # ¡BLANCO INMACULADO! Aquí forzamos que si no está seleccionado sea blanco puro sin interferencias
        $brushFondo = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $brushTexto = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Black)
    }

    # ¡TRUCO MAESTRO! Dibujamos el fondo nosotros mismos e impedimos que Windows pinte su fondo verde pastel encima
    $e.Graphics.FillRectangle($brushFondo, $e.Bounds)

    # Extraemos el texto real
    $nombreCaratula = $this.Items[$e.Index].ToString()
    
    # Pintamos el texto con el pincel que toca
    $e.Graphics.DrawString($nombreCaratula, $e.Font, $brushTexto, $e.Bounds.X, $e.Bounds.Y)

    # Si necesitas que dibuje el rectángulo de enfoque (los puntitos alrededor del seleccionado), descomenta la línea de abajo:
    # $e.DrawFocusRectangle()

    # Liberamos los pinceles de la memoria
    $brushFondo.Dispose()
    $brushTexto.Dispose()


})

# =========================================================================
# ASIGNACIÓN DE COMPONENTES AL PANEL
# =========================================================================
$panelDatLeft.Controls.Add($btnLoadDat)
$panelDatLeft.Controls.Add($btnSaveDat)
$panelDatLeft.Controls.Add($listBoxDat)


$panelDatLeft.Controls.Add($btnLoadDat)
$panelDatLeft.Controls.Add($btnSaveDat)
$panelDatLeft.Controls.Add($listBoxDat)

# Agregamos los componentes directamente al Formulario principal
$form.Controls.Add($webBrowser)
$form.Controls.Add($panelDatLeft)

# =========================================================================
# EVENTO DE CARGA DE ARCHIVO .DAT
# =========================================================================
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
            $stream = $entry.Open()
            $memStream = New-Object System.IO.MemoryStream
            $stream.CopyTo($memStream)
            $global:VirtualDatFiles[$entry.FullName.ToLower()] = $memStream.ToArray()
            $memStream.Dispose()
            $stream.Dispose()
        }

        $archive.Dispose()
        [System.IO.File]::Delete($tempZip)
        # =========================================================================
        # NUEVO CABLEADO: CONMUTACIÓN ALFABÉTICA Y ENCODING ASIÁTICO ULTRA-BLINDADO
        # =========================================================================
        # Ordenamos las carátulas por su número natural indexado (0.raw, 1.raw, 10.raw...)
        $caratulasOrdenadas = $global:VirtualDatFiles.keys | Where-Object { $_ -like "*.raw" } | Sort-Object { [int]($_ -replace '\D') } 
        
        # Buscamos tanto filelist.txt como fileinfo.txt
        $claveFileList = $global:VirtualDatFiles.keys | Where-Object { $_ -like "*filelist.txt" -or $_ -like "*fileinfo.txt" } | Select-Object -First 1

        if ($claveFileList) {
            $bytesFileList = $global:VirtualDatFiles[$claveFileList]
            
            # SOLUCIÓN ENCODING DEFINITIVA: Método nativo compatible con Windows
            try {
                # Forzamos codificación GB2312/GBK nativa de la Game Stick sin librerías externas
                $encAsiatico = [System.Text.Encoding]::GetEncoding("gb2312")
                $textoFileList = $encAsiatico.GetString($bytesFileList)
            } catch {
                # Fallback de emergencia si la máquina no soporta el paquete extendido
                $textoFileList = [System.Text.Encoding]::UTF8.GetString($bytesFileList)
            }

            # Procesamos las líneas en su ORDEN REAL DE LA CONSOLA (Crucial para el Line to Line)
            $lineasJuegos = ($textoFileList -split "[\r\n]+") | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

            $global:TablaConmutada = @()
            for ($i = 0; $i -lt $lineasJuegos.Count; $i++) {
                $caratulaRaw = $null
                if ($i -lt $caratulasOrdenadas.Count) { $caratulaRaw = $caratulasOrdenadas[$i] }
                $global:TablaConmutada += [PSCustomObject]@{
                    Indice    = $i
                    Datos     = $lineasJuegos[$i] 
                    Rawkey    = $caratulaRaw      
                }
            }
        }
        
                # ... [Tu código actual de carga de archivos y selección automática] ...
        if ($global:VirtualDatFiles -and $global:VirtualDatFiles.Count -gt 0) {
            $listBoxDat.Items.Clear()
            $listaInapelable = $global:VirtualDatFiles.keys | Sort-Object
            foreach ($elemento in $listaInapelable) {
                [void]$listBoxDat.Items.Add($elemento)
            }

            if ($claveFileList) {
                $idxAuto = $listBoxDat.Items.IndexOf($claveFileList)
                if ($idxAuto -ge 0) { $listBoxDat.SelectedIndex = $idxAuto }
            }
        }

        # --- [NUEVA INYECCIÓN DE CONTROL PROMETHEUS] ---
        # Contamos cuántas carátulas .raw existen físicamente dentro del .DAT que acabamos de abrir
        $totalRawEnDat = ($global:VirtualDatFiles.keys | Where-Object { $_ -like "*.raw" }).Count

        # Se lo notificamos directamente a la Card Azul del HTML mediante una llamada limpia
        if ($webBrowser.Document) {
            [void]$webBrowser.Document.InvokeScript("execScript", @("if(document.getElementById('countTotalCaratulas')){ document.getElementById('countTotalCaratulas').textContent = '$totalRawEnDat'; }", "JavaScript"))
        }

    } # <-- CIERRA EL IF DEL SHOWDIALOG
}) # <-- CIERRA EL EVENTO DEL BOTÓN

# --- SELECCIÓN DE JUEGO Y ENVÍO AL NAVEGADOR (CON ENCODING ASIÁTICO FIX) ---
$listBoxDat.Add_SelectedIndexChanged({
    if ($listBoxDat.SelectedItem -eq $null) { return }
    $selectedFileName = $listBoxDat.SelectedItem.ToString()
    
    # Buscamos en el diccionario virtual con control de minúsculas
    $rawBytes = $global:VirtualDatFiles[$selectedFileName.ToLower()]
    if ($rawBytes -eq $null) { return }

    # Si lo que seleccionamos es el listado de texto (.txt), lo decodificamos correctamente antes de enviarlo
    if ($selectedFileName -like "*.txt") {
        try {
            # Sistema nativo compatible con PowerShell de Windows para la Game Stick (GBK/Chino)
            $encAsiatico = [System.Text.Encoding]::GetEncoding("gb2312")
            $textoLimpio = $encAsiatico.GetString($rawBytes)
        } catch {
            $textoLimpio = [System.Text.Encoding]::UTF8.GetString($rawBytes)
        }
        
        # Convertimos el texto ya limpio en un Base64 seguro para que el Navegador no tenga que adivinar el idioma
        $bytesUtf8Limpios = [System.Text.Encoding]::UTF8.GetBytes($textoLimpio)
        $base64String = [System.Convert]::ToBase64String($bytesUtf8Limpios)
    } else {
        # Si es un archivo .raw (imagen) o binario, se envía el Base64 tal cual estaba original
        $base64String = [System.Convert]::ToBase64String($rawBytes)
    }

    # Enviamos al script del Navegador sin tuberías conflictivas
    [void]$webBrowser.Document.InvokeScript("loadRawFromSuite", @($selectedFileName, $base64String))

    # --- PROMETHEUS CALCULATOR AUTOMÁTICO EN CADA SELECCIÓN/REFRESCO ---
    # Calculamos las carátulas huérfanas basándonos en las líneas de juegos reales indexadas
    $totalCaratulasRaws = ($global:VirtualDatFiles.keys | Where-Object { $_ -like "*.raw" }).Count
    $juegosCount = 0
    
    # Buscamos el total de juegos cargado actualmente desde las líneas procesadas
    $claveListActiva = $global:VirtualDatFiles.keys | Where-Object { $_ -like "*filelist.txt" -or $_ -like "*fileinfo.txt" } | Select-Object -First 1
    if ($claveListActiva) {
        $bytesActivos = $global:VirtualDatFiles[$claveListActiva]
        try { $txtActivo = [System.Text.Encoding]::GetEncoding("gb2312").GetString($bytesActivos) } catch { $txtActivo = [System.Text.Encoding]::UTF8.GetString($bytesActivos) }
        $juegosCount = (($txtActivo -split "[\r\n]+") | Where-Object { $_.Trim() -ne "" }).Count
    }

    # --- ACTUALIZACIÓN DINÁMICA DE CARDS TRAS CAMBIO O CARGA ---
    $totalCaratulasRaws = ($global:VirtualDatFiles.keys | Where-Object { $_ -like "*.raw" }).Count
    
    # Inyectamos el valor en la Card Azul (Total) y ejecutamos el método de Huérfanas
    if ($webBrowser.Document) {
        [void]$webBrowser.Document.InvokeScript("execScript", @("if(document.getElementById('countTotalCaratulas')){ document.getElementById('countTotalCaratulas').textContent = '$totalCaratulasRaws'; }", "JavaScript"))
        [void]$webBrowser.Document.InvokeScript("updateRemoteCounters", @($huerfanasCount))
    }

    # Las carátulas huérfanas son aquellas cuyo número de índice supera la cantidad de juegos asignados en consola
    $huerfanasCount = 0
    if ($totalCaratulasRaws -gt $juegosCount) {
        $huerfanasCount = $totalCaratulasRaws - $juegosCount
    }

    # Inyectamos de forma segura el recuento dinámico en la Card 4 de Prometheus en el HTML
    if ($webBrowser.Document) {
        [void]$webBrowser.Document.InvokeScript("updateRemoteCounters", @($huerfanasCount))
    }
})

# --- INTERCEPTOR DE TITULO CON CANDADO ANTI-REPETICION Y RECEPTOR SAVERAW ---
$global:LastSavedFile = ""
$global:LastSavedTime = [DateTime]::MinValue

$webBrowser.Add_DocumentTitleChanged({
    $title = $webBrowser.DocumentTitle
    if ($title) {
        if ($title.StartsWith("SAVERAW:")) {
            $payload = $title.Substring(8)
            $separatorIdx = $payload.IndexOf("|")
            if ($separatorIdx -gt 0) {
                $fileName = $payload.Substring(0, $separatorIdx)
                $base64Data = $payload.Substring($separatorIdx + 1)
                
                # Filtro inteligente anti-duplicados por tiempo
                $now = [DateTime]::Now
                $timeDiff = ($now - $global:LastSavedTime).TotalSeconds
                if ($fileName -eq $global:LastSavedFile -and $timeDiff -lt 1.5) { return }
                
                $global:LastSavedFile = $fileName
                $global:LastSavedTime = $now

                try {
                    # Decodificamos el Base64 UTF-8 que viene de la web
                    $bytesUtf8 = [System.Convert]::FromBase64String($base64Data)
                    $textoPlano = [System.Text.Encoding]::UTF8.GetString($bytesUtf8)

                    # Método nativo compatible con Windows para la Game Stick
                    $encAsiatico = [System.Text.Encoding]::GetEncoding("gb2312")

                    # Convertimos el texto plano de vuelta a los bytes codificados en Chino nativo
                    $bytesAsiaticosFinales = $encAsiatico.GetBytes($textoPlano)

                    # Guardamos los bytes chinos corregidos en la memoria virtual del sistema
                    $global:VirtualDatFiles[$fileName.ToLower()] = $bytesAsiaticosFinales
                    
                    [System.Windows.Forms.MessageBox]::Show("Lista de juegos ('$fileName') actualizada temporalmente en memoria.", "Éxito de Sincronización", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    
                    # Forzamos refresco del listbox para actualizar los contadores Prometheus de inmediato
                    $idxActual = $listBoxDat.SelectedIndex
                    if ($idxActual -ge 0) {
                        $listBoxDat.SelectedIndex = -1
                        $listBoxDat.SelectedIndex = $idxActual
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Error al procesar el guardado de la lista: $_", "Error Interno", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            # Devolvemos el título a su estado base para poder volver a escuchar futuros cambios
            $webBrowser.Document.Title = "Suite Motor Grafico Game Stick Lite"
        }
    }
})
# --- INTERCEPTOR DE PETICIONES DE CARA-TULAS DESDE EL GRID ---
$webBrowser.Add_StatusTextChanged({
    $status = $webBrowser.StatusText
    if ($status -like "REQ_COVER:*") {
        $coverName = $status.Substring(10)
		$rawBytes = $global:VirtualDatFiles[$coverName.ToLower()]
        
        if ($rawBytes -ne $null) {
            $base64String = [System.Convert]::ToBase64String($rawBytes)
            [void]$webBrowser.Document.InvokeScript("loadRawFromSuite", @($coverName, $base64String))
            [void]$webBrowser.Document.InvokeScript("renderAllCaratula")
        }
        [void]$webBrowser.Document.InvokeScript("execScript", @("window.status = '';", "JavaScript"))
    }
})

# =========================================================================
# --- RE-EMPAQUETADOR BINARIO EXCLUSIVO PARA ARCHIVOS .DAT ---
# =========================================================================
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

        foreach ($key in $global:VirtualDatFiles.keys) {
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
        [System.Windows.Forms.MessageBox]::Show("Contenedor de juegos .DAT reconstruido con éxito. Copia guardada en .backup", "Operación Completada", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        # --- FORCE REFRESH PROMETHEUS POST-SAVE ---
        # Volvemos a disparar el evento del ListBox para forzar a la UI a recalcular y limpiar las Cards tras guardar
        $idxActual = $listBoxDat.SelectedIndex
        if ($idxActual -ge 0) {
            $listBoxDat.SelectedIndex = -1
            $listBoxDat.SelectedIndex = $idxActual
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error crítico en DAT: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# =========================================================================
# ARRANQUE GENERAL DE MOTOR 2
# =========================================================================
if (Test-Path $htmlPath) { 
    $webBrowser.Navigate($htmlPath) 
} else { 
    [System.Windows.Forms.MessageBox]::Show("No se encontró el archivo motor2.html en la ruta:`n$htmlPath", "Error de Fichero", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) 
}

# =========================================================================
# Interceptor Prometheus de Navegación Personalizada
# =========================================================================
$webBrowser.add_Navigating({
    param([object]$sender, [System.Windows.Forms.WebBrowserNavigatingEventArgs]$e)
	
    # Comprobamos si la propiedad Url existe y no está vacía antes de usar .ToString()   
    if ($null -ne $e.Url) { 
        $url = $e.Url.ToString()
    } else {
	    $url = "" # O el valor por defecto que quieras darle si no hay URL
    }	
    # Detectamos la orden de purga enviada por el HTML
    if ($url -like "*eliminarHuerfanas*") {
        # 1. Cancelamos la navegación para que no dé error de página no encontrada
        $e.Cancel = $true

        if (-not $global:VirtualDatFiles) { 
            [System.Windows.Forms.MessageBox]::Show("Error: El contenedor virtual 000.DAT no está cargado.", "Prometheus Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return 
        }
        # =========================================================================
        # 2. Identificar cuáles son las huérfanas reales en el diccionario virtual
        # =========================================================================
        $clavesAEliminar = New-Object System.Collections.Generic.List[string]

        # 1. Obtenemos el número total de juegos válidos indexados en el Filelist
        $totalJuegosIndexados = 0
        if ($global:TablaConmutada) {
            $totalJuegosIndexados = $global:TablaConmutada.Count
        }

        # 2. ¡CORREGIDO AQUÍ! Cambiamos \(keys por las llaves reales del diccionario global
        # 2. ¡CORREGIDO Y ALINEADO! Filtramos por .raw y ordenamos numéricamente
        $caratulasOrdenadas = $global:VirtualDatFiles.Keys | Where-Object { $_ -like "*.raw" } | Sort-Object { 
            $numOnly = $_ -replace '\D'
            if ($numOnly -ne '') { [int64]$numOnly } else { [int64]::MaxValue }
        }


        # === TU CHIVATO DE DEPURACIÓN ===
        Write-Host "=== DUELO EN ALTA JOPMA (PROMETHEUS) ===" -ForegroundColor Cyan
        Write-Host "-> totalJuegosIndexados vale: [$totalJuegosIndexados]" -ForegroundColor Yellow
        Write-Host "-> caratulasOrdenadas.Count vale: [$($caratulasOrdenadas.Count)]" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan

        # 3. Cualquier carátula cuyo orden de lista supere la cantidad de juegos es una huérfana
        for ($i = 0; $i -lt $caratulasOrdenadas.Count; $i++) {
            if ($i -ge $totalJuegosIndexados) {
                [void]$clavesAEliminar.Add($caratulasOrdenadas[$i])
            }
        }

        # DIAGNÓSTICO DE EMERGENCIA SEGURO: Si intenta borrar todo, te muestra qué está viendo el script
        $totalRawEnVirtualDat = $caratulasOrdenadas.Count
        # ¡CORREGIDO! Añadidos los '$' a las variables dentro de la condición
        # ¡CORREGIDO! Añadidas las llaves { } que engloban las acciones del 'if'
        if ($clavesAEliminar.Count -eq $totalRawEnVirtualDat -and $totalRawEnVirtualDat -gt 0) {
            $ejemploJuego = if ($totalJuegosIndexados -gt 0) { $global:TablaConmutada[0].Datos } else { "LISTA VACÍA" }
            $ejemploCaratula = if ($totalRawEnVirtualDat -gt 0) { $caratulasOrdenadas[0] } else { "SIN CARÁTULAS" }
        }

            
            [System.Windows.Forms.MessageBox]::Show(
                "¡ALERTA DE BORRADO COMPLETO!`n`n" +
                "El script va a borrar todo porque el contador de juegos indexados es 0.`n`n" +
                "Ejemplo de juego indexado: [$ejemploJuego]`n" +
                "Ejemplo de ID de carátula en DAT: [$ejemploCaratula]`n`n" +
                "Total juegos en Filelist: $totalJuegosIndexados", 
                "Diagnóstico Prometheus", 
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }

        # 3. Purgar las huérfanas
        $totalBorrados = 0
        foreach ($keyAEliminar in $clavesAEliminar) {
            $global:VirtualDatFiles.Remove($keyAEliminar)
            $totalBorrados++
        }

        # 4. Actualizar la interfaz visual si hubo purga
        if ($totalBorrados -gt 0) {
            # Limpiamos por completo el ListBox del marco izquierdo
            $listBoxDat.Items.Clear()

            # A) METEMOS LOS JUEGOS (Verde o Naranja)
            foreach ($juego in $global:TablaConmutada) {
                [void]$listBoxDat.Items.Add($juego)
            }

            # B) IDENTIFICAMOS Y METEMOS LAS HUÉRFANAS REALES (Rojo)
            $caratulasAsignadas = $global:TablaConmutada | Where-Object { $_.Estado -eq "Ok" } | Select-Object -ExpandProperty Rawkey
            $caratulasOrdenadasFiltradas = $global:VirtualDatFiles.Keys | Sort-Object

            foreach ($caratula in $caratulasOrdenadasFiltradas) {
                if ($caratula -like "*₀₀₀.raw" -and $caratula -notin $caratulasAsignadas) {
					$objetoHuerfano = [PSCustomObject]@{
                        Indice = -1
                        Datos  = "Caratula huerfana detectada en el contenedor"
                        Rawkey = $caratula
                        Estado = "Huerfana"
                    }
                    [void]$listBoxDat.Items.Add($objetoHuerfano)
                }
            }

            # Recalculamos el nuevo total de carátulas que quedan vivas
            $totalRawEnDat = ($global:VirtualDatFiles.Keys | Where-Object { $_ -like "*.raw" }).Count

            # Inyectamos los nuevos valores en las Cards del HTML en tiempo real
            if ($webBrowser.Document) {
                # Ponemos a 0 el contador de la Card de Huérfanas
                [void]$webBrowser.Document.InvokeScript("execScript", @("if(document.getElementById('countHuerfanas')){ document.getElementById('countHuerfanas').textContent = '0'; }", "JavaScript"))
                # Actualizamos el nuevo total de la Card Azul
                [void]$webBrowser.Document.InvokeScript("execScript", @("if(document.getElementById('countTotalCaratulas')){ document.getElementById('countTotalCaratulas').textContent = '`$($totalRawEnDat)'; }", "JavaScript"))
            }

            # ¡CORREGIDO! Cambiado '\$totalBorrados' por '\$totalBorrados' para que muestre el número real
            [System.Windows.Forms.MessageBox]::Show("PROMETHEUS PURGE COMPLETED:`n`nSe han eliminado permanentemente $totalBorrados carátulas huérfanas de la memoria virtual.", "Éxito", 
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Aviso: No se ejecutó ninguna acción porque no se detectaron carátulas huérfanas reales.", "Información", 
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
}) 
# Lanzamiento del formulario
$form.ShowDialog() | Out-Null
