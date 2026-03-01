# 🚀 CI/CD con Terraform y GitHub Actions

[![Terraform CI/CD](https://github.com/Proyecto-Cloud/CI-CD-amb-Terraform-i-GitHub-Actions/actions/workflows/terraform.yml/badge.svg)](https://github.com/Proyecto-Cloud/CI-CD-amb-Terraform-i-GitHub-Actions/actions/workflows/terraform.yml)
[![App CI/CD](https://github.com/Proyecto-Cloud/CI-CD-amb-Terraform-i-GitHub-Actions/actions/workflows/deploy-app.yml/badge.svg)](https://github.com/Proyecto-Cloud/CI-CD-amb-Terraform-i-GitHub-Actions/actions/workflows/deploy-app.yml)

Este proyecto implementa un flujo **CI/CD automatizado y desacoplado** para desplegar infraestructura en **AWS** utilizando **Terraform** y una aplicación web en **Kubernetes (EKS)**, todo orquestado mediante **GitHub Actions** siguiendo buenas prácticas.

---

## 🎯 Objetivo
Automatizar la validación, revisión y despliegue, tanto de la infraestructura como del software, mediante Pull Requests. De esta manera se evitan cambios manuales directos y errores en producción, asegurando un entorno robusto, trazable y reproducible.

---

## 🏗️ Arquitectura del Proyecto

El repositorio está dividido lógicamente en dos partes independientes, cada una con su propio ciclo de vida:

### 1. Infraestructura como Código (Terraform)
Despliega toda la base necesaria en AWS para soportar la aplicación:
- **Red**: VPC, Subnets Públicas/Privadas, Internet Gateway y NAT Gateway.
- **Cómputo**: Clúster de Amazon EKS (`democluster`) con un Node Group de máquinas `t3.medium`.
- **Seguridad**: Security Groups para el *Control Plane* de Kubernetes y comunicación node-pod.

### 2. Aplicación de Demostración (`demo-app/`)
Una aplicación web programada en **Python (Flask)**:
- Genera una interfaz visual que varía dependiendo del pod donde se está ejecutando.
- Se empaqueta en **Docker** y se escala a 3 réplicas en EKS.
- Expuesta mediante un manifiesto de `Service` de tipo LoadBalancer que crea automáticamente un **Network Load Balancer (NLB)** de AWS para evidenciar el balanceo de carga visualmente.

---

```markdown
## 🚀 Flujo de trabajo (CI/CD)
```

El proyecto utiliza la estrategia *GitHub Flow*. Hay dos pipelines separados para evitar que los cambios en la web afecten a la infraestructura y viceversa:

### 📁 Terraform Pipeline (`.github/workflows/terraform.yml`)
1. Cada cambio en la infraestructura se hace en una **rama feature**.
2. Al abrir una **Pull Request** hacia `main`:
   - Se ejecuta el CI: `fmt`, `validate` y `plan`.
   - El resultado del `terraform plan` se comenta automáticamente en la PR gracias a la Action `github-script`.
3. Después de la aprobación verbal o técnica, al hacer **merge a `main`**:
   - Se ejecuta el CD: `terraform apply` de forma automática.
4. El estado de Terraform se guarda en un **backend remoto (S3 + DynamoDB)** para garantizar el bloqueo (*State Locking*) de concurridencia.

### 📁 App Pipeline (`.github/workflows/deploy-app.yml`)
- Este pipeline solo se activa si se modifican archivos dentro de la carpeta `demo-app/`.
- Al hacer merge hacia `main`, el pipeline **construye la imagen Docker**, sube la nueva versión a **Docker Hub**, se autentifica en EKS AWS y aplica/reinicia los manifiestos con `kubectl` automáticamente.

---

## 🛠️ ¿Cómo lanzar la Demo Rápida?

Si la infraestructura de Terraform ya está desplegada en tu entorno (con `terraform apply`), puedes forzar el despliegue de la Demo localmente ejecutando el script helper:

```bash
chmod +x deploy_demo.sh
./deploy_demo.sh
```
El script conectará con tu clúster de EKS, desplegará los recursos de Kubernetes y se quedará a la espera para imprimirte la URL final del balanceador una vez AWS lo haya provisto.

---

## 📋 Requisitos
Para replicar o trabajar con este repositorio, necesitarás:
- **Cuenta AWS** activa (con permisos EKS, EC2, IAM etc).
- **Secretos de AWS configurados en GitHub Actions**:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_SESSION_TOKEN` (Importante si usas cuentas de laboratorio AWS Academy).
- **Secretos de Docker configurados en GitHub Actions**:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`
- Roles IAM preexistentes de AWS Academy Learner Lab: `LabEksClusterRole` y `LabEksNodeRole`.

---

## ⚙️ Backend Setup Automatizado (S3 + DynamoDB)

Si utilizas cuentas de estudiante de AWS Academy (o tus credenciales cambian a menudo), ejecutar el siguiente script te creará dinámicamente el backend: un **Bucket de S3 único** basado en tu Account ID y una tabla **DynamoDB**. Finalmente sobrescribirá el archivo `backend.tf` de Terraform y migrará el estado local a la nube.

```bash
chmod +x setup_backend.sh
./setup_backend.sh
```

---

## ⚠️ Notas Importantes
- La rama `main` debe estar **protegida** contra escritura directa.
- Todo despliegue de infraestructura pasa obligatoriamente por una Pull Request.

---

### Autores
Proyecto realizado como práctica técnica de CI/CD con Terraform, EKS y GitHub Actions.
