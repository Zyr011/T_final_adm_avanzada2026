#!/bin/bash

# Si falla un comando por ejemplo validacion de requerimentos el script finaliza.
set -euo pipefail

# Definicion de variables a usar
CLUSTER_NAME="dns-ha"
NAMESPACE="dns-ha"
DNS_DOMAIN="dns.trabajofinal.local"
DNS_HOST="127.0.0.1"
DNS_PORT="1053"


#Definicion de directorio root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "======================================"
echo " DINO - Deploy DNS HA"
echo "======================================"

cd "$ROOT_DIR"

# Funcion para revisar si los requerimentos estan cumplidos
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "[ERROR] Falta instalar: $1"
        exit 1
    fi
}

# Llamados de funcion para check
echo "[INFO] Verificando dependencias..."
check_command podman
check_command kind
check_command kubectl
check_command dig
check_command git

# Definicion para uso general
export KIND_EXPERIMENTAL_PROVIDER=podman

# Creacion del cluster, con previa validacion de no duplicacion
echo "[INFO] Verificando cluster kind..."
if kind get clusters | grep -qx "$CLUSTER_NAME"; then
    echo "[WARN] El cluster $CLUSTER_NAME ya existe. No se crea nuevamente."
else
    echo "[INFO] Creando cluster $CLUSTER_NAME..."
    kind create cluster --name "$CLUSTER_NAME" --config k8s/kind-cluster.yaml
fi

# Contextualizacion del entorno
echo "[INFO] Usando contexto kind-$CLUSTER_NAME..."
kubectl config use-context "kind-$CLUSTER_NAME"

# Aplicacion de namespace
echo "[INFO] Aplicando namespace..."
kubectl apply -f k8s/namespace.yaml

# Generando configmap. Importante en deploys luego de cambios de archivos de zonas o named.conf
echo "[INFO] Generando ConfigMap desde archivos BIND9..."
kubectl create configmap bind9-config --from-file=k8s/bind9/named.conf --from-file=k8s/bind9/db.trabajofinal.local -n "$NAMESPACE" --dry-run=client -o yaml > k8s/bind9-configmap.yaml

# Aplicacion de configmap
echo "[INFO] Aplicando ConfigMap..."
kubectl apply -f k8s/bind9-configmap.yaml

# Aplicacion de Service
echo "[INFO] Aplicando Service..."
kubectl apply -f k8s/bind9-service.yaml

# Aplicacion de statefulset
echo "[INFO] Aplicando StatefulSet..."
kubectl apply -f k8s/bind9-statefulset.yaml

# Verificacion de estado de pods
echo "[INFO] Esperando disponibilidad del StatefulSet..."
kubectl rollout status statefulset/bind9 -n "$NAMESPACE" --timeout=180s

# Muetra visual de creacion de recursos
echo "[INFO] Recursos creados:"
kubectl get nodes
kubectl get pods -n "$NAMESPACE" -o wide
kubectl get svc -n "$NAMESPACE"
kubectl get pvc -n "$NAMESPACE"

# Validacion de funcionamiento
echo "[INFO] Validando DNS UDP..."
dig @"$DNS_HOST" -p "$DNS_PORT" "$DNS_DOMAIN" +short >/tmp/dino_dns_udp.out

if [ ! -s /tmp/dino_dns_udp.out ]; then
    echo "[ERROR] No hubo respuesta DNS por UDP"
    exit 1
fi

cat /tmp/dino_dns_udp.out

echo "[INFO] Validando DNS TCP..."
dig @"$DNS_HOST" -p "$DNS_PORT" "$DNS_DOMAIN" +tcp +short >/tmp/dino_dns_tcp.out

if [ ! -s /tmp/dino_dns_tcp.out ]; then
    echo "[ERROR] No hubo respuesta DNS por TCP"
    exit 1
fi

cat /tmp/dino_dns_tcp.out

echo "======================================"
echo "[OK] Deploy finalizado correctamente"
echo "======================================"

