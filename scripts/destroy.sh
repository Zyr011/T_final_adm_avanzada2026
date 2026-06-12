#!/bin/bash

# Si falla un comando el script finaliza para evitar fallos en cadena

set -euo pipefail

# Definicion de variables
CLUSTER_NAME="dns-ha"

echo "======================================"
echo " DINO - Destroy"
echo "======================================"

# Definicion para uso general
export KIND_EXPERIMENTAL_PROVIDER=podman

# Si existe el cluster -> eliminarlo
if kind get clusters | grep -qx "$CLUSTER_NAME"; then
    echo "[INFO] Eliminando cluster $CLUSTER_NAME..."
    kind delete cluster --name "$CLUSTER_NAME"
else
    echo "[WARN] No existe cluster $CLUSTER_NAME en kind con Podman"
fi

# Prueba de funcionamiento
echo "[INFO] Clusters kind restantes:"
kind get clusters || true

echo "[INFO] Contenedores Podman restantes:"
podman ps -a

echo "======================================"
echo "[OK] Limpieza finalizada"
echo "======================================"

