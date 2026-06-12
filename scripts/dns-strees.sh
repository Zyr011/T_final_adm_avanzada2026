#!/bin/bash

# Si un comando falla el script finaliza
set -euo pipefail

# Definicion de variables de lab ( predefinidas en los archivos)
DNS_HOST="${1:-127.0.0.1}"
DNS_PORT="${2:-1053}"
DNS_NAME="${3:-dns.trabajofinal.local}"
TOTAL="${4:-1000}"

OK=0
FAIL=0

echo "======================================"
echo " DINO - DNS Stress"
echo "======================================"
echo "Servidor : $DNS_HOST"
echo "Puerto   : $DNS_PORT"
echo "Nombre   : $DNS_NAME"
echo "Consultas: $TOTAL"
echo "======================================"


# Ejecucion recursiva de consultas DNS

for i in $(seq 1 "$TOTAL"); do
    if dig @"$DNS_HOST" -p "$DNS_PORT" "$DNS_NAME" +short +tries=1 +time=1 >/dev/null; then
        OK=$((OK + 1))
    else
        FAIL=$((FAIL + 1))
    fi

    if (( i % 100 == 0 )); then
        echo "[INFO] Consultas ejecutadas: $i | OK: $OK | FAIL: $FAIL"
    fi
done

echo "======================================"
echo "Resultado final"
echo "OK   : $OK"
echo "FAIL : $FAIL"
echo "======================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
