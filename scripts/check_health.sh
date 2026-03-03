#!/bin/bash

# Script de comprobación rápida (Pre-Presentación)
# Este script verifica que todo esté levantado y funcionando en AWS / EKS.

echo "======================================================"
echo "🚀 INICIANDO CHEQUEO DE SALUD DEL PROYECTO CI/CD 🚀"
echo "======================================================"
echo ""

# 1. Comprobar credenciales de AWS
echo "👉 [1/5] Verificando credenciales de AWS..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✅ Conexión con AWS establecida."
else
    echo "❌ ERROR: No se ha podido contactar con AWS. Revisa tus credenciales en ~/.aws/credentials."
    exit 1
fi
echo ""

# 2. Refrescar y comprobar conexión al Clúster EKS
echo "👉 [2/5] Refrescando conexión al clúster (democluster)..."
if aws eks update-kubeconfig --region us-east-1 --name democluster > /dev/null 2>&1; then
    echo "✅ Contexto de Kubernetes actualizado."
else
    echo "❌ ERROR: No se ha encontrado el clúster EKS. ¿Se ha ejecutado terraform apply?"
    exit 1
fi
echo ""

# 3. Comprobar Nodos EC2 (Workers de EKS)
echo "👉 [3/5] Verificando Nodos EC2 (Workers)..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -w Ready | wc -l)
if [ "$NODES" -ge 2 ]; then
    echo "✅ Se han detectado $NODES Nodos operando en estado 'Ready'."
else
    echo "⚠️ ADVERTENCIA: Se esperaban al menos 2 Nodos, pero se han detectado $NODES. Revisa la consola EC2."
fi
echo ""

# 4. Comprobar ejecución de la App (Pods)
echo "👉 [4/5] Verificando réplicas de la Demo-App..."
PODS=$(kubectl get pods | grep load-balancer-demo | grep Running | wc -l)
if [ "$PODS" -eq 3 ]; then
    echo "✅ 3 réplicas de la Demo-App corriendo correctamente."
else
    echo "⚠️ ADVERTENCIA: Hay $PODS réplicas corriendo. Se esperaban 3. Ejecuta 'kubectl get pods' para investigar."
fi
echo ""

# 5. Comprobar y obtener la URL Pública del Balanceador
echo "👉 [5/5] Obteniendo el Balanceador de Carga (NLB)..."
URL=$(kubectl get svc lb-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -n "$URL" ]; then
    echo "✅ Balanceador de carga desplegado con éxito."
    echo ""
    echo "======================================================"
    echo "🎉 TODO LISTO PARA LA DEMO 🎉"
    echo "======================================================"
    echo "🌐 URL DE TU APLICACIÓN: http://$URL"
    echo "(Si la IP acaba de cambiar, puede tardar hasta 3 minutos en propagarse en AWS)"
else
    echo "❌ ERROR: No se ha encontrado el Load Balancer. ¿Está desplegado el k8s-manifest.yaml?"
fi
