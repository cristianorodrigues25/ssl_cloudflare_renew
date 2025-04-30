
# Certbot SSL Auto-Renewal (Docker + Cloudflare)

Este repositório contém um script Bash que automatiza a renovação de certificados SSL Let's Encrypt utilizando o Certbot com o plugin DNS da Cloudflare. O script foi projetado para ambientes em containers Docker e suporta agendamento via `cron` ou `systemd timer`.

## 🔧 Funcionalidades

- Utiliza o Docker para executar o Certbot com o plugin `dns-cloudflare`.
- Renova certificados SSL para múltiplos domínios.
- Copia automaticamente os novos certificados para os volumes montados nos containers.
- Valida a configuração do NGINX e reinicia os containers NGINX e WAF, se necessário.
- Suporta agendamento via `cron` ou `systemd timer`.

## 📂 Estrutura do Repositório

```
.
├── renew_certificates.sh       # Script de renovação
├── systemd/
│   ├── renew-certificates.service
│   └── renew-certificates.timer
└── README.md
```

## 📜 Pré-requisitos

- Docker instalado e configurado.
- Plugin `dns-cloudflare` do Certbot (via imagem oficial).
- Arquivo de credenciais da Cloudflare (`cloudflare.ini`).
- Montagem correta dos volumes `letsencrypt` nos containers NGINX e WAF.

## 🚀 Execução Manual

1. Torne o script executável:

   ```bash
   chmod +x renew_certificates.sh
   ```

2. Execute o script:

   ```bash
   ./renew_certificates.sh
   ```

## 🕒 Agendamento via systemd (Recomendado)

### 1. Instale o unit service e o timer:

```bash
sudo cp systemd/renew-certificates.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now renew-certificates.timer
```

### 2. Verifique o status do timer:

```bash
systemctl list-timers | grep renew-certificates
```

## 🕓 Agendamento via cron (Alternativa)

Execute `crontab -e` e adicione a seguinte linha para agendar a execução do script bimestralmente (nos primeiros dias dos meses pares):

```cron
0 3 1 1,3,5,7,9,11 * /path/to/renew_certificates.sh >> /var/log/cert-renewal-cron.log 2>&1
```

## 🔐 Segurança

Garanta que o arquivo de credenciais da Cloudflare tenha permissões restritas:

```bash
chmod 600 /path/to/cloudflare.ini
```
