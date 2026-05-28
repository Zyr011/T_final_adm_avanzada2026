# Trabajo Final Administracion de Sistemas Avanzada 2026

**Asignatura:** Administración de Sistemas Avanzada
**Alumno:** Lorenzo Moiola 
**Proyecto:** Kubernetes Alta disponibilidad DNS 

---

## 1. Descripción del Proyecto

El proyecto consiste en el diseño, despliegue e implementación de un servicio DNS de Alta Disponibilidad (HA) utilizando BIND9 sobre un entorno orquestado con Kubernetes. La infraestructura local se montará utilizando kind para simular un clúster multi-nodo real de producción. El objetivo principal es demostrar los principios de resiliencia, balanceo de carga y autorrecuperación de la infraestructura ante fallos simulados en contenedores o nodos del clúster, garantizando la continuidad del servicio DNS.
El desarrollo desacopla completamente la lógica del software de su configuración y estado, siguiendo buenas practicas.

---

## 2. Tecnologías Usadas

* **Orquestador:** Kubernetes
* **Entorno de Simulación:** kind 
* **Servicio DNS:** BIND9 (Imagen oficial de la empresa)
* **Almacenamiento y Configuración:** Kubernetes ConfigMaps, Persistent Volumes (PV) y Persistent Volume Claims (PVC)

---

## 3. Módulos de la Asignatura

Este trabajo pretende aplicar de forma directa conocimientos relacionados con contenedores y orquestación mediante Kubernetes, administración de Pods y Deployments, almacenamiento persistente desacoplado del ciclo de vida de los contenedores y mecanismos de alta disponibilidad orientados a la mitigación de puntos únicos de fallo (SPOF).

---
