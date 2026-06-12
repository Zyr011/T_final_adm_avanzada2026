#!/bin/bash

# Si un comando falla el script se detiene
set -euo pipefail

# Definicion de variables a utilizar

NAMESPACE="dns-ha"
APP_LABEL="app=bind9"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_BASE="$ROOT_DIR/backups"
LOG_DIR="$ROOT_DIR/backups/logs"
SCRIPT_PATH="$(realpath "$0")"
CRON_LOG="$ROOT_DIR/backups/backup-cron.log"
CRON_LINE="*/5 * * * * $SCRIPT_PATH >> $CRON_LOG 2>&1"

# Creacion de tarea cron cada 5 minutos (intensiva para demo durante lab)

install_cron() {
    mkdir -p "$LOG_DIR"
    echo "[INFO] Instalando tarea cron cada 5 minutos..."
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "$CRON_LINE") | crontab -
    echo "[OK] Cron instalado:"
    crontab -l | grep "$SCRIPT_PATH"
}

# Remover tarea cron
remove_cron() {
    echo "[INFO] Eliminando tarea cron del backup..."
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    echo "[OK] Cron eliminado"
}

# Ejecutar backup inmediato

run_backup() {
    TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
    BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"
    BACKUP_FILE="$BACKUP_BASE/backup_$TIMESTAMP.tar.gz"
    RUN_LOG="$BACKUP_DIR/backup.log"

    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"

    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RUN_LOG"
    }

    log "Iniciando backup DNS"

    cd "$ROOT_DIR"

# Copia de los archivos de configuracion bind9 en el repositorio al estado actual
    log "Copiando archivos BIND9 del repositorio"
    mkdir -p "$BACKUP_DIR/bind9"
    cp k8s/bind9/named.conf "$BACKUP_DIR/bind9/"
    cp k8s/bind9/db.trabajofinal.local "$BACKUP_DIR/bind9/"

    log "Exportando ConfigMap"
    kubectl get configmap bind9-config -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/bind9-configmap.yaml"

# Guardado de estado del cluster y logs del cluster
    log "Guardando estado del cluster"
    kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt"
    kubectl get all -n "$NAMESPACE" -o wide > "$BACKUP_DIR/resources.txt"
    kubectl get pvc -n "$NAMESPACE" -o wide > "$BACKUP_DIR/pvc.txt"
    kubectl get pv -o wide > "$BACKUP_DIR/pv.txt"
    kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp > "$BACKUP_DIR/events.txt"

    log "Recolectando logs de BIND9"
    mkdir -p "$BACKUP_DIR/logs"

    PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}')"

# Recoleccion de datos directo de los pods
    if [ -z "$PODS" ]; then
        log "WARN: No se encontraron Pods BIND9"
    else
        for POD in $PODS; do
            log "Recolectando logs del Pod $POD"
            kubectl logs -n "$NAMESPACE" "$POD" --all-containers=true > "$BACKUP_DIR/logs/${POD}_kubectl.log" 2>/dev/null || true
            kubectl exec -n "$NAMESPACE" "$POD" -- cat /var/log/bind/queries.log > "$BACKUP_DIR/logs/${POD}_queries.log" 2>/dev/null || true
        done
    fi
# Compresion del archivo

    log "Comprimiendo backup"
    tar -czf "$BACKUP_FILE" -C "$BACKUP_BASE" "backup_$TIMESTAMP"

    log "Backup generado: $BACKUP_FILE"

    log "Finalizando backup"
}

# Menu case y llamado a la accion de funciones
case "${1:-}" in
    --install-cron)
        install_cron
        ;;
    --remove-cron)
        remove_cron
        ;;
    *)
        run_backup
        ;;
esac
