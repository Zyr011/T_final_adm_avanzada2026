# Trabajo Final - Administración de Sistemas Avanzada 2026

- **Asignatura:** Administración de Sistemas Avanzada
- **Alumno:** Lorenzo Moiola
- **Proyecto:** DINO - DNS autoritativo de alta disponibilidad sobre Kubernetes

---

# DINO: DINO is not one

DNS autoritativo de alta disponibilidad sobre Kubernetes.

---

## 1. Descripción del proyecto

El proyecto consiste en el diseño, despliegue e implementación de un servicio DNS de alta disponibilidad utilizando BIND9 sobre un entorno orquestado con Kubernetes.

El laboratorio se ejecuta sobre una máquina Ubuntu, utilizando `kind` para crear un clúster Kubernetes local y `Podman rootless` como motor de contenedores.

El servicio DNS se configura como autoritativo para la zona interna:

```text
trabajofinal.local
```

El objetivo principal es demostrar:

- despliegue de un clúster Kubernetes local;
- uso de Podman rootless;
- ejecución de BIND9 como servicio DNS autoritativo;
- alta disponibilidad mediante múltiples réplicas;
- persistencia de logs mediante PVC;
- separación de configuración mediante ConfigMaps;
- exposición del servicio mediante NodePort;
- automatización con scripts Bash;
- pruebas de carga, backup y tolerancia a fallos.

---

## 2. Tecnologías utilizadas

- **Kubernetes:** orquestador de contenedores.
- **kind:** herramienta para crear clústeres Kubernetes locales.
- **Podman rootless:** motor de contenedores sin privilegios de root.
- **BIND9:** servidor DNS autoritativo.
- **ConfigMap:** recurso para desacoplar la configuración del contenedor.
- **StatefulSet:** recurso para mantener identidad estable y PVC por réplica.
- **PVC:** almacenamiento persistente para logs de consultas DNS.
- **NodePort:** exposición del servicio DNS hacia el host Ubuntu.
- **Bash:** lenguaje utilizado para los scripts de automatización.
- **cron:** herramienta utilizada para programar backups periódicos.

---

## 3. Arquitectura general

El laboratorio se ejecuta localmente sobre Ubuntu.

```text
Ubuntu
└── Podman rootless
    └── kind
        └── Kubernetes cluster dns-ha
            ├── Control Plane
            ├── Worker 1
            │   └── Pod bind9-0
            │       └── PVC bind9-logs-bind9-0
            └── Worker 2
                └── Pod bind9-1
                    └── PVC bind9-logs-bind9-1
```

Dentro del namespace `dns-ha` se agrupan los recursos principales del proyecto:

```text
Namespace dns-ha
├── ConfigMap bind9-config
├── StatefulSet bind9
├── Service bind9-service
└── PVC por réplica
```

El Control Plane administra el estado del clúster. Los nodos Worker ejecutan las instancias del servicio DNS. El StatefulSet permite que cada réplica de BIND9 mantenga una identidad estable y un volumen persistente propio.

---

## 4. Estructura del repositorio

```text
dns-ha-kubernetes/
├── README.md
├── LICENSE
├── .gitignore
│
├── k8s/
│   ├── kind-cluster.yaml
│   ├── namespace.yaml
│   ├── bind9-configmap.yaml
│   ├── bind9-service.yaml
│   ├── bind9-statefulset.yaml
│   │
│   └── bind9/
│       ├── named.conf
│       └── db.trabajofinal.local
│
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── backup-dns.sh
│   ├── dns-stress.sh
│   └── test-ha.sh
│
├── backups/
│   └── .gitkeep
│
└── docs/
    └── evidencias/
```

### 4.1 Directorio `k8s/`

Contiene los manifiestos YAML necesarios para desplegar la infraestructura Kubernetes del proyecto.

### 4.2 Directorio `k8s/bind9/`

Contiene los archivos propios de configuración de BIND9. Estos archivos se utilizan para generar el ConfigMap aplicado dentro del clúster.

### 4.3 Directorio `scripts/`

Contiene los scripts Bash que automatizan el despliegue, limpieza, backup, pruebas de carga y pruebas de alta disponibilidad.

### 4.4 Directorio `backups/`

Directorio destinado a almacenar respaldos generados por el script de backup.

### 4.5 Directorio `docs/`

Directorio reservado para diagramas, capturas y evidencias del laboratorio.

---

## 5. Requisitos previos

El laboratorio fue validado sobre Ubuntu.

Herramientas necesarias:

- `podman`
- `kind`
- `kubectl`
- `dig`
- `git`
- `bash`
- `cron`

Verificación rápida:

```bash
podman --version
kind version
kubectl version --client
dig -v
git --version
```

---

## 6. Configuración de kind con Podman rootless

Para indicar a `kind` que utilice Podman como proveedor de contenedores:

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
```

Opcionalmente, se puede dejar configurado de forma permanente para el usuario:

```bash
echo 'export KIND_EXPERIMENTAL_PROVIDER=podman' >> ~/.bashrc
source ~/.bashrc
```

---

## 7. Recursos Kubernetes

### 7.1 `kind-cluster.yaml`

Define el clúster local de kind.

Este archivo establece:

- un nodo Control Plane;
- dos nodos Worker;
- la imagen de Kubernetes utilizada por los nodos kind;
- el mapeo de puertos entre el host Ubuntu y el clúster.

El laboratorio utiliza `extraPortMappings` para publicar el servicio DNS desde el clúster hacia el host Ubuntu.

---

### 7.2 `namespace.yaml`

Define el namespace `dns-ha`.

El namespace permite agrupar los recursos del proyecto en un espacio lógico separado dentro del clúster Kubernetes.

---

### 7.3 `bind9-configmap.yaml`

Define el ConfigMap `bind9-config`.

Este recurso contiene la configuración de BIND9 generada a partir de los archivos:

```text
k8s/bind9/named.conf
k8s/bind9/db.trabajofinal.local
```

El ConfigMap permite separar la configuración del contenedor, evitando modificar o reconstruir la imagen de BIND9 cada vez que se cambia la configuración DNS.

---

### 7.4 `bind9-statefulset.yaml`

Define el StatefulSet encargado de ejecutar BIND9.

Se utiliza StatefulSet porque cada réplica del servicio DNS necesita:

- identidad estable;
- nombre persistente;
- PVC propio;
- persistencia de logs ante reinicios o eliminación de Pods.

Las réplicas esperadas son:

```text
bind9-0
bind9-1
```

Cada réplica utiliza un PVC propio para almacenar logs.

---

### 7.5 `bind9-service.yaml`

Define el Service `bind9-service`.

Este recurso expone el servicio DNS dentro del clúster y permite el acceso desde el host mediante NodePort.

BIND9 escucha internamente en:

```text
53/UDP
53/TCP
```

El Service publica el servicio mediante:

```text
30053/UDP
30053/TCP
```

kind redirige el tráfico del host hacia ese NodePort mediante `extraPortMappings`.

---

## 8. Configuración DNS

BIND9 se configura como servidor DNS autoritativo para la zona:

```text
trabajofinal.local
```

Los archivos principales son:

```text
k8s/bind9/named.conf
k8s/bind9/db.trabajofinal.local
```

La recursión DNS no se habilita, ya que el objetivo del laboratorio es validar un servicio DNS autoritativo interno.

---

## 9. Flujo de consulta DNS

El flujo esperado de una consulta DNS es:

```text
Host Ubuntu
        ↓
Puerto 1053 del host
        ↓
kind extraPortMapping
        ↓
NodePort 30053
        ↓
Service bind9-service
        ↓
Pod BIND9 disponible
        ↓
Respuesta DNS
```

El acceso desde el host se realiza utilizando `dig` contra `127.0.0.1` y el puerto `1053`.

---

## 10. Flujo de logs

Cada instancia de BIND9 registra consultas DNS en:

```text
/var/log/bind/queries.log
```

Cada Pod del StatefulSet tiene su propio PVC:

```text
bind9-0 -> bind9-logs-bind9-0
bind9-1 -> bind9-logs-bind9-1
```

El flujo esperado de logs es:

```text
Consulta DNS
        ↓
Pod BIND9 seleccionado
        ↓
BIND9 registra la consulta
        ↓
/var/log/bind/queries.log
        ↓
PVC persistente de la réplica
```

Esto permite conservar logs aunque un Pod sea eliminado o reiniciado.

---

## 11. Despliegue automático

El despliegue automático se realiza mediante:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

El script `deploy.sh` debe encargarse de:

- verificar dependencias necesarias;
- configurar el uso de Podman rootless con kind;
- crear el clúster kind;
- aplicar el namespace;
- generar el ConfigMap desde los archivos BIND9;
- aplicar el Service;
- aplicar el StatefulSet;
- verificar que los recursos principales hayan sido creados.

---

## 12. Despliegue manual

Crear el clúster:

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman

kind create cluster --name dns-ha --config k8s/kind-cluster.yaml
```

Aplicar namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

Generar ConfigMap:

```bash
kubectl create configmap bind9-config --from-file=k8s/bind9/named.conf --from-file=k8s/bind9/db.trabajofinal.local -n dns-ha --dry-run=client -o yaml > k8s/bind9-configmap.yaml
```

Aplicar recursos:

```bash
kubectl apply -f k8s/bind9-configmap.yaml
kubectl apply -f k8s/bind9-service.yaml
kubectl apply -f k8s/bind9-statefulset.yaml
```

Verificar recursos:

```bash
kubectl get nodes
kubectl get pods -n dns-ha -o wide
kubectl get svc -n dns-ha
kubectl get pvc -n dns-ha
```

---

## 13. Scripts

### 13.1 `deploy.sh`

Script encargado de desplegar el laboratorio completo.

Funciones esperadas:

- validar dependencias;
- crear el clúster;
- aplicar manifiestos Kubernetes;
- generar el ConfigMap;
- validar que los Pods estén disponibles.

---

### 13.2 `destroy.sh`

Script encargado de eliminar el laboratorio.

Funciones esperadas:

- eliminar el clúster kind;
- limpiar recursos asociados al laboratorio;
- mostrar el estado final de los contenedores Podman.

---

### 13.3 `backup-dns.sh`

Script encargado de generar respaldos del servicio DNS.

Funciones esperadas:

- respaldar archivos de configuración BIND9;
- exportar el ConfigMap aplicado;
- recolectar logs de BIND9;
- guardar información de PVC;
- guardar estado básico del clúster;
- generar un archivo comprimido de backup;
- registrar la ejecución en un log.

---

### 13.4 `dns-stress.sh`

Script encargado de generar consultas DNS masivas.

Funciones esperadas:

- ejecutar múltiples consultas hacia el servicio DNS;
- permitir definir host, puerto, dominio y cantidad de consultas;
- mostrar cantidad de consultas realizadas;
- detectar consultas fallidas.

---

### 13.5 `prueba-ha.pod.sh / prueba-ha-worker.sh`

Script encargado de automatizar pruebas de alta disponibilidad.

Funciones esperadas:

- simular caída de un Pod BIND9;
- verificar recreación del Pod;
- simular caída de un Worker;
- validar que el servicio continúe disponible mientras exista una réplica activa;
- restaurar el entorno luego de la prueba.

---

## 14. Backup y cron

El script de backup puede ejecutarse manualmente:

```bash
chmod +x scripts/backup-dns.sh
./scripts/backup-dns.sh
```
También puede programarse mediante cron:

```bash
crontab -e
```

Ejemplo de ejecución periódica:

```cron
*/5 * * * * /home/lorenzo/dns-ha-kubernetes/scripts/backup-dns.sh
```

---

## 15. Limpieza del entorno

La limpieza automática se realiza mediante:

```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh
```

También puede eliminarse el clúster manualmente:

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
kind delete cluster --name dns-ha
```

Verificación:

```bash
podman ps -a
kind get clusters
```

---

## 16. Consideraciones

### 16.1 Puerto 1053

Se utiliza `1053` en el host porque el puerto `53` es privilegiado y el laboratorio usa Podman rootless.

También se evita `5353`, ya que puede estar ocupado por mDNS/Avahi.

### 16.2 NodePort 30053

El puerto `30053` está dentro del rango válido de NodePort de Kubernetes y dentro de la banda reservada para asignaciones estáticas.

### 16.3 Windows

El entorno validado es Ubuntu. En Windows se recomienda usar una VM Ubuntu en VirtualBox.

---

## 17. Autor

**Lorenzo Moiola**  
Tecnicatura Superior en Administración de Sistemas y Software Libre  
Universidad Nacional del Comahue - Centro Regional Zona Atlántica

---

## 18. Licencia

El repositorio se encuentra protegido por la licencia descrita en el archivo en *LICENSE.md*
