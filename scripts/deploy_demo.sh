#!/bin/bash
set -e

# ==============================================================================
# Script de Despliegue de Presentación (Load Balancer Demo)
# ==============================================================================
echo "🚀 Iniciando el despliegue automático de la demo..."

# Colores para output vistoso
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Conexión al cluster EKS
echo -e "\n${BLUE}[1/3] Configurando el acceso al cluster EKS...${NC}"
# Tomamos el nombre del cluster y la región del código Terraform existente ("democluster" y "us-east-1")
aws eks update-kubeconfig --region us-east-1 --name democluster || echo -e "${YELLOW}Aviso: Fallo al actualizar kubeconfig. Asegúrate de tener las credenciales de AWS correctas.${NC}"

# 2. Despliegue de los manifiestos
echo -e "\n${BLUE}[2/3] Aplicando los manifiestos de Kubernetes...${NC}"
kubectl apply -f demo-app/k8s-manifest.yaml

# 3. Esperar al balanceador
echo -e "\n${BLUE}[3/3] Esperando a que AWS aprovisione el Network Load Balancer...${NC}"
echo "Esto puede tardar un par de minutos, siéntate y relájate..."

LB_HOSTNAME=""
# Reintentar obtener el hostname hasta que AWS lo asigne
while [ -z "$LB_HOSTNAME" ]; do
    sleep 5
    LB_HOSTNAME=$(kubectl get svc lb-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$LB_HOSTNAME" ]; then
        echo -n "."
    fi
done

echo -e "\n"
echo -e "${GREEN}✅ ==========================================${NC}"
echo -e "${GREEN}      DESPLIEGUE COMPLETADO CON ÉXITO        ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "🌍 La URL de tu aplicación balanceada es:"
echo -e "${YELLOW}➡️  http://$LB_HOSTNAME${NC}"
echo ""
echo -e "${YELLOW}⚠️ Nota: AWS puede tardar hasta 3 minutos adicionales en propagar el DNS.${NC}"
echo "Si la página no carga inmediatamente al hacer click, espera un poco y recarga."

