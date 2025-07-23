#!/bin/bash

# === Caminhos e variáveis ===
LOG_FILE="/var/log/cert-renewal.log"
DEST_PATH="/path/to/ssl/destination"
LETSENCRYPT_PATH="/path/to/letsencrypt"   # ajuste conforme seu volume real do letsencrypt
DOMAINS=("example1.com" "example2.com" "example3.com")

# === Função de log ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Iniciando processo de renovação de certificados SSL..."

# === Renovação por domínio ===
for DOMAIN in "${DOMAINS[@]}"; do
  log "Iniciando renovação para o domínio: $DOMAIN"

  docker run --rm --name certbot \
    -v "$LETSENCRYPT_PATH:/etc/letsencrypt" \
    -v /path/to/log:/var/log/letsencrypt \
    -v /root/.secrets/cloudflare.ini:/root/.secrets/cloudflare.ini \
    certbot/dns-cloudflare certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --email your-email@example.com \
    --agree-tos --non-interactive \
    --force-renewal \
    -d "$DOMAIN" | tee -a "$LOG_FILE"

  if [ $? -ne 0 ]; then
    log "Erro durante a renovação do domínio $DOMAIN. Abortando processo."
    exit 1
  fi
done

# === Cópia dos certificados atualizados ===
for DOMAIN in "${DOMAINS[@]}"; do
  log "Copiando certificados para o domínio: $DOMAIN"

  # Encontra o diretório mais recente (considera possíveis sufixos -0001, -0002...)
  CERT_DIR=$(find "$LETSENCRYPT_PATH/live/" -maxdepth 1 -type d -name "${DOMAIN}*" | sort | tail -n 1)

  if [ ! -d "$CERT_DIR" ]; then
    log "Diretório de certificado não encontrado para $DOMAIN. Pulando cópia."
    continue
  fi

  mkdir -p "$DEST_PATH/$DOMAIN"

  cp "$CERT_DIR/fullchain.pem" "$DEST_PATH/$DOMAIN/"
  cp "$CERT_DIR/privkey.pem" "$DEST_PATH/$DOMAIN/"
  cp "$CERT_DIR/chain.pem" "$DEST_PATH/$DOMAIN/"
  cp "$CERT_DIR/cert.pem" "$DEST_PATH/$DOMAIN/"

  log "Certificados copiados para: $DEST_PATH/$DOMAIN/"
done

# === Validação e reinício dos serviços ===
log "Validando configuração do NGINX..."
docker exec nginx nginx -t | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
  log "Configuração válida. Reiniciando NGINX e WAF..."
  docker exec nginx nginx -s reload
  docker restart waf
  log "Serviços reiniciados com sucesso."
else
  log "Erro na configuração do NGINX. Reinício abortado."
fi

log "Processo concluído."
