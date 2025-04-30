#!/bin/bash

# === Caminhos e variáveis ===
LOG_FILE="/var/log/cert-renewal.log"
DEST_PATH="/path/to/ssl/destination"
DOMAINS=("example1.com" "example2.com" "example3.com")

# === Função de log ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Iniciando processo de renovação de certificados SSL..."

# === Renovação com Certbot via Docker ===
log "Executando Certbot em container..."
docker run --rm --name certbot \
  -v /path/to/log:/var/log/letsencrypt \
  -v /path/to/letsencrypt:/etc/letsencrypt \
  -v /root/.secrets/cloudflare.ini:/root/.secrets/cloudflare.ini \
  certbot/dns-cloudflare certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --email your-email@example.com \
  --agree-tos --non-interactive \
  $(for domain in "${DOMAINS[@]}"; do echo -n "-d $domain "; done) \
  | tee -a "$LOG_FILE"

if [ $? -ne 0 ]; then
  log "Erro durante a renovação. Verifique os logs."
  exit 1
fi

# === Cópia dos certificados ===
for DOMAIN in "${DOMAINS[@]}"; do
  log "Copiando certificados para o domínio: $DOMAIN"
  mkdir -p "$DEST_PATH/$DOMAIN"
  cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$DEST_PATH/$DOMAIN/"
  cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$DEST_PATH/$DOMAIN/"
  cp "/etc/letsencrypt/live/$DOMAIN/chain.pem" "$DEST_PATH/$DOMAIN/"
  cp "/etc/letsencrypt/live/$DOMAIN/cert.pem" "$DEST_PATH/$DOMAIN/"
  log "Certificados copiados para: $DEST_PATH/$DOMAIN/"
done

# === Validação e reinício de serviços ===
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
