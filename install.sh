#!/bin/bash

# FISGON - Instalador de comando global (Soporte Linux y Termux)
# https://github.com/code-KxK/fisgon

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detectar si está ejecutándose en Termux
if [ -d "$PREFIX/bin" ]; then
    BIN_PATH="$PREFIX/bin/fisgon"
    USE_SUDO=""
else
    BIN_PATH="/usr/local/bin/fisgon"
    USE_SUDO="sudo"
fi

echo -e "\e[1;36m[+] Instalando FISGON de forma global...\e[0m"

# Crear el script lanzador con o sin sudo dependiendo del entorno
$USE_SUDO bash -c "cat << 'EOF' > $BIN_PATH
#!/bin/bash
cd '$SCRIPT_DIR' && ./dnsinspect.sh \"\$1\"
EOF"

# Dar permisos de ejecución
if [ -f "$BIN_PATH" ]; then
    $USE_SUDO chmod +x $BIN_PATH
    chmod +x "$SCRIPT_DIR/dnsinspect.sh"
    echo -e "\e[1;32m[✓] ¡Instalación exitosa en el entorno local!\e[0m"
    echo -e "Ya puedes usar el comando tecleando simplemente: \e[1;33mfisgon dominio.com\e[0m"
else
    echo -e "\e[1;31m[-] Error al crear el acceso global.\e[0m"
    exit 1
fi
