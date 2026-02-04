# CI/CD amb Terraform i GitHub Actions

Aquest projecte implementa un flux **CI/CD bàsic** per desplegar infraestructura a **AWS** utilitzant **Terraform** i **GitHub Actions**, seguint bones pràctiques de treball en equip.

## Objectiu
Automatitzar la validació, revisió i desplegament de la infraestructura mitjançant Pull Requests, evitant canvis manuals i errors en producció.

## Flux de treball
1. Cada canvi es fa en una **branca feature**.
2. En obrir una **Pull Request** cap a `main`:
   - S’executa el CI (`fmt`, `validate`, `plan`).
   - El resultat del `terraform plan` es comenta automàticament a la PR.
3. Després de l’aprovació, en fer **merge a `main`**:
   - S’executa el CD (`terraform apply`) de forma automàtica.
4. L’estat de Terraform es guarda en un **backend remot (S3 + DynamoDB)**.

## Requisits
- Compte AWS
- Bucket S3 i taula DynamoDB per al backend
- Secrets d’AWS configurats a GitHub Actions
- Terraform instal·lat (per a execució local opcional)

## Notes
- La branca `main` està protegida.
- No es permeten pushes directes.
- Tot desplegament passa obligatòriament per una Pull Request.

## Autors
Projecte realitzat com a pràctica de CI/CD amb Terraform i GitHub Actions.

