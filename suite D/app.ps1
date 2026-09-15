<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Prometheus Suite D - Interfaz de Control</title>
    <style>
        :root {
            --bg-dark: #121212;
            --bg-panel: #1e1e1e;
            --accent: #00adb5;
            --text-main: #eeeeee;
            --text-muted: #888888;
            --border-color: #333333;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-dark);
            color: var(--text-main);
            height: 100vh;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        /* Barra de Pestañas Superior Corregida */
        .tab-bar {
            display: flex;
            background-color: #000000;
            border-bottom: 2px solid var(--border-color);
        }
        .tab-btn {
            background: none; border: none;
            color: var(--text-muted); padding: 15px 25px;
            font-size: 14px; font-weight: bold;
            cursor: pointer; transition: all 0.3s;
        }
        .tab-btn:hover { color: var(--text-main); background-color: #111; }
        .tab-btn.active {
            color: var(--accent);
            border-bottom: 3px solid var(--accent);
            background-color: var(--bg-panel);
        }
        /* Contenedores de Contenido */
        .tab-content { display: none; flex: 1; height: calc(100vh - 52px); }
        .tab-content.active { display: flex; }

        /* Estructura de Paneles Limpia */
        .sidebar {
            width: 320px; background-color: var(--bg-panel);
            border-right: 1px solid var(--border-color);
            display: flex; flex-direction: column; padding: 20px; gap: 15px;
        }
        .main-viewer {
            flex: 1; background-color: #151515;
            display: flex; flex-direction: column;
            align-items: center; justify-content: center;
            padding: 20px; position: relative;
        }

        .btn {
            background-color: #252525; color: var(--text-main);
            border: 1px solid var(--border-color); padding: 12px;
            border-radius: 4px; cursor: pointer; font-weight: bold;
            text-align: center; transition: background 0.2s;
        }
        .btn:hover { background-color: var(--accent); color: #000; }
        .btn-primary { background-color: #2b579a; border: none; }
        .btn-primary:hover { background-color: #3b78cd; }

        .list-container {
            flex: 1; border: 1px solid var(--border-color);
            background-color: #111; border-radius: 4px; overflow-y: auto;
        }
        .game-item { padding: 10px; border-bottom: 1px solid #222; cursor: pointer; font-size: 13px; }
        .game-item:hover, .game-item.selected { background-color: #252525; color: var(--accent); }

        /* Visores con IDs y Clases de Tamaño Estricto (Sin mezclas) */
        .canvas-container {
            border: 2px dashed #444; background-color: #000;
            display: flex; align-items: center; justify-content: center;
            overflow: hidden; box-shadow: 0 0 20px rgba(0,0,0,0.5);
        }
        .canvas-1280 { width: 1280px; height: 720px; max-width: 100%; max-height: 80%; }
        .canvas-568 { width: 568px; height: 284px; }
        .preview-img { width: 100%; height: 100%; object-fit: contain; display: none; }
        
        .viewer-title { position: absolute; top: 20px; left: 20px; font-size: 14px; color: var(--text-muted); letter-spacing: 1px; text-transform: uppercase; }
        .placeholder-text { color: #555; font-size: 14px; text-align: center; }
    </style>
</head>
<body>

    <!-- BARRA DE PESTAÑAS CORRECTA -->
    <div class="tab-bar">
        <button class="tab-btn active" onclick="switchTab('tab-editor')">EDITOR DE INTERFAZ</button>
        <button class="tab-btn" onclick="switchTab('tab-juegos')">GESTOR DE JUEGOS .DAT</button>
    </div>

    <!-- PESTAÑA 1: EDITOR DE INTERFAZ -->
    <div id="tab-editor" class="tab-content active">
        <div class="sidebar">
            <h3 style="color: var(--accent);">Operaciones CPD</h3>
            <button class="btn btn-primary" onclick="triggerAction('LOAD_CPD')">CARGAR RESOURCE.CPD</button>
            <div style="flex: 1;"></div>
            <button class="btn" onclick="triggerAction('SAVE_CPD')">GUARDAR CONTENEDOR FINAL</button>
        </div>
        <div class="main-viewer">
            <div class="viewer-title">Visor de Menú Principal (1280x720)</div>
            <div class="canvas-container canvas-1280">
                <img id="img-menu-view" class="preview-img" alt="Menu View">
                <div class="placeholder-text" id="cpd-placeholder">Ningún contenedor resource.cpd cargado.<br>Dimensiones: 1280 x 720</div>
            </div>
        </div>
    </div>

    <!-- PESTAÑA 2: GESTOR DE JUEGOS (MULTIMEDIA INDEPENDIENTE RECUPERADO) -->
    <div id="tab-juegos" class="tab-content">
        <div class="sidebar">
            <h3 style="color: var(--accent);">Estructura de Juegos</h3>
            <button class="btn" onclick="triggerAction('LOAD_DAT_DIR')">CARGAR CARPETA DE JUEGOS</button>
            <label style="font-size: 12px; color: var(--text-muted); margin-top: 10px;">Juegos Detectados (FILELIST.TXT):</label>
            <div class="list-container" id="game-list">
                <div class="placeholder-text" style="padding: 20px;">Carga la carpeta para listar los títulos.</div>
            </div>
        </div>
        <div class="main-viewer">
            <div class="viewer-title">Gestor Multimedia (.RAW - 568x284)</div>
            <div class="canvas-container canvas-568" style="border-style: solid; border-color: var(--accent);">
                <img id="img-game-view" class="preview-img" alt="Game View">
                <div class="placeholder-text" id="game-placeholder">Ningún archivo multimedia seleccionado.<br>Dimensión Estricta: 568 x 284</div>
            </div>
        </div>
    </div>

    <script>
        function switchTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
            event.target.classList.add('active');
        }

        // COMUNICACIÓN CLÁSICA: Usamos el cambio de título que tu versión semifuncional entiende perfectamente
        function triggerAction(actionName) {
            document.title = "ACTION:" + actionName;
            // Pequeño reset para que PowerShell pueda capturar el mismo clic seguidamente si hace falta
            setTimeout(() => { document.title = "Prometheus Suite D - Interfaz de Control"; }, 100);
        }

        // Al hacer clic en un juego, avisamos a PowerShell cambiando el título con el nombre del juego
        function selectGame(gameName) {
            document.title = "SELECT_GAME:" + gameName;
            setTimeout(() => { document.title = "Prometheus Suite D - Interfaz de Control"; }, 100);
        }

        // FUNCIÓN QUE LLAMA POWERSHELL PARA RELLENAR LA LISTA (Mantiene tu lógica original)
        function populateGameList(gamesArray) {
            const listContainer = document.getElementById('game-list');
            listContainer.innerHTML = '';
            if (!gamesArray || gamesArray.length === 0) {
                listContainer.innerHTML = '<div class="placeholder-text" style="padding:20px;">FILELIST.TXT vacío.</div>';
                return;
            }
            gamesArray.forEach(game => {
                const item = document.createElement('div');
                item.className = 'game-item';
                item.innerText = game;
                item.onclick = function() {
                    document.querySelectorAll('.game-item').forEach(el => el.classList.remove('selected'));
                    item.classList.add('selected');
                    selectGame(game);
                };
                listContainer.appendChild(item);
            });
        }

        // ==============================================================================
        // --- SEPARACIÓN ABSOLUTA DE CANALES DE IMAGEN (EL FIN DEL BUG) ---
        // ==============================================================================
        
        // Canal Exclusivo 1: Solo pinta en el Visor Grande (1280x720)
        window.loadMenuRaw = function(base64Data) {
            const img = document.getElementById('img-menu-view');
            const placeholder = document.getElementById('cpd-placeholder');
            if(placeholder) placeholder.style.display = 'none';
            img.src = "data:image/png;base64," + base64Data;
            img.style.display = 'block';
        };

        // Canal Exclusivo 2: Solo pinta en el Visor Pequeño (568x284) del Gestor Multimedia
        window.loadGameRaw = function(base64Data) {
            const img = document.getElementById('img-game-view');
            const placeholder = document.getElementById('game-placeholder');
            if(placeholder) placeholder.style.display = 'none';
            img.src = "data:image/png;base64," + base64Data;
            img.style.display = 'block';
        };
    </script>
</body>
</html>
