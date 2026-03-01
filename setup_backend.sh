#!/bin/bash
set -e

echo "🚀 Iniciando configuración de Bootstrap de Terraform..."

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Obtener AWS Account ID para hacer el nombre del bucket único
echo -e "\n${BLUE}[1/4] Obteniendo AWS Account ID actual...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${YELLOW}❌ Error: No se pudo obtener el Account ID. ¿Están configuradas tus credenciales de AWS?${NC}"
    exit 1
fi

BUCKET_NAME="terraform-state-${ACCOUNT_ID}-project"
DYNAMODB_TABLE="terraform-locks"
REGION="us-east-1"

echo -e "✅ AWS Account ID: ${ACCOUNT_ID}"
echo -e "✅ Nombre de Bucket S3 dinámico: ${BUCKET_NAME}"

# 2. Reemplazar el nombre del bucket en bootstrap/main.old y guardar como main.tf
echo -e "\n${BLUE}[2/4] Preparando código original de bootstrap/main.tf...${NC}"
# Usamos sed para reemplazar el nombre duro por el dinámico y guardarlo en main.tf
sed "s/bucket = \"fila2-terraform-state-2026-project\"/bucket = \"${BUCKET_NAME}\"/g" bootstrap/main.old > bootstrap/main.tf

# 3. Aplicar infraestructura inicial (S3 y DynamoDB) con Terraform
echo -e "\n${BLUE}[3/4] Desplegando el Backend S3 con Terraform (Bootstrap)...${NC}"
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..

# 4. Generar backend.tf dinámicamente para el proyecto real
echo -e "\n${BLUE}[4/4] Configuranto terraform/backend.tf para usar la nueva infra...${NC}"
cat <<EOF > terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "terraform.tfstate"
    region         = "${REGION}"
    encrypt        = true
    dynamodb_table = "${DYNAMODB_TABLE}"
  }
}
EOF
echo -e "${GREEN}✅ Archivo backend.tf generado correctamente.${NC}"

# 5. Forzar migración del estado de Terraform
echo -e "\n${BLUE}[5/5] Ejecutando Terraform Init y migrando el estado local hacia S3...${NC}"
cd terraform
# El comando -migrate-state detectará que antes usabas local y ahora S3, 
# y subirá el archivo terraform.tfstate a la nube automáticamente.
terraform init -migrate-state -force-copy

echo -e "\n${GREEN}🎉 ¡TODO LISTO! Tu infraestructura de Terraform ahora guarda el estado remótamente basándose en tu código original.${NC}"
echo "Recuerda subir los cambios a GitHub."
