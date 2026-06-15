#!/bin/bash

# Configuración automática del repositorio
if [ -d .git ]; then
    URL_REMOTO=$(git config --get remote.origin.url)
    USUARIO_GITHUB=$(echo "$URL_REMOTO" | sed -E 's|https://github.com([^/]+)/.*|\1|')
    REPOSITORIO=$(echo "$URL_REMOTO" | sed -E 's|https://github.com[^/]+/([^.]+).*|\1|')
else
    USUARIO_GITHUB="eoeg2011"
    REPOSITORIO="fisgon"
fi

URL_PAGINAS="https://raw.githubusercontent.com/eoeg2011/fisgon/main/paginas.txt"
ARCHIVO_LOCAL="$HOME/paginas.txt"

# Verificar herramientas necesarias
if ! command -v dig &> /dev/null; then
    echo "Error: Requieres 'dig'. Instálalo con: pkg install dnsutils"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: Requieres 'curl'. Instálalo con: pkg install curl"
    exit 1
fi

# Descarga automática si no existe
if [ ! -f "$ARCHIVO_LOCAL" ]; then
    echo -e "\e[1;33m[INSTALACIÓN]\e[0m No se encontró 'paginas.txt'. Descargando lista..."
    curl -s -f -o "$ARCHIVO_LOCAL" "$URL_PAGINAS"
    
    if [ $? -ne 0 ] || [ ! -s "$ARCHIVO_LOCAL" ]; then
        echo -e "\e[1;31m[ERROR]\e[0m No se pudo descargar el archivo."
        rm -f "$ARCHIVO_LOCAL"
        exit 1
    fi
    echo -e "\e[1;32m[ÉXITO]\e[0m Lista descargada instalada.\n"
fi

# Limpieza rápida de posibles caracteres corruptos (\r de Windows o espacios raros)
sed -i 's/\r//g; s|://||g' "$ARCHIVO_LOCAL"

if [ -z "$1" ]; then 
    echo "Uso: ./dnsinspect.sh [pagina.com o IP]"
    exit 1
fi

# Limpiar el argumento de entrada por si meten http:// o diagonales
TARGET_INPUT=$(echo "$1" | sed -E 's|https?://||; s|/.*||')

target_dns="$TARGET_INPUT"
if [[ ! "$TARGET_INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then 
    echo -e "\e[1;34m[AUDITORÍA AUTOMÁTICA]\e[0m Buscando servidor de nombres para: $TARGET_INPUT"
    found=$(dig +short NS "$TARGET_INPUT" | head -n 1)
    if [ -z "$found" ]; then 
        found=$(dig "$TARGET_INPUT" | grep -A 1 "AUTHORITY SECTION" | tail -n 1 | awk '{print $5}')
    fi
    if [ ! -z "$found" ]; then 
        ip_found=$(dig +short "$found" | head -n 1)
        if [ ! -z "$ip_found" ]; then 
            target_dns="$ip_found"
        else 
            target_dns="$found"
        fi
        echo -e "\e[1;32m[DNS ASIGNADO]:\e[0m $target_dns"
    else 
        echo -e "\e[1;31m[ERROR]\e[0m No se halló el DNS. Usando $TARGET_INPUT directamente..."
    fi
fi

echo -e "\n\e[1;35m[INICIANDO ANÁLISIS DE CACHÉ]:\e[0m Servidor -> $target_dns\n"
si_count=0
no_count=0

# Procesar el archivo local línea por línea
while IFS= read -r line || [ -n "$line" ]; do
    # Limpiar espacios en blanco o saltos de línea raros en la variable
    line=$(echo "$line" | tr -d '\r' | xargs)
    
    if [[ -z "$line" ]]; then 
        continue
    fi
    if [[ "$line" =~ ^# ]]; then
        echo -e "\n\e[1;36m==== $line ====\e[0m"
        continue
    fi
    
    # EXPLICACIÓN DE CAMBIOS AQUÍ:
    # +time=1 -> Espera máximo 1 segundo de respuesta global
    # +tries=1 -> No reintentes si falla, pasa rápido
    # +tries=1 +timeout=1 reduce drásticamente el congelamiento si el DNS descarta paquetes
    res=$(dig @"$target_dns" "$line" +norecurse +time=1 +tries=1 2>/dev/null)
    
    if echo "$res" | grep -q "ANSWER SECTION" && ! echo "$res" | grep -q "status: SERVFAIL"; then
        echo -e "\e[1;32m[SI VISITADA]\e[0m $line"
        ((si_count++))
    else
        echo -e "\e[1;31m[NO VISITADA]\e[0m $line"
        ((no_count++))
    fi
done < "$ARCHIVO_LOCAL"

total=$((si_count + no_count))
echo -e "\n\e[1;33m========================================\e[0m"
echo -e "\e[1;32mPÁGINAS VISITADAS ENCONTRADAS:\e[0m $si_count"
echo -e "\e[1;31mPÁGINAS NO VISITADAS:\e[0m $no_count"
echo -e "\e[1;34mTOTAL DE SITIOS AUDITADOS:\e[0m $total"
echo -e "\e[1;33m========================================\e[0m\n"
