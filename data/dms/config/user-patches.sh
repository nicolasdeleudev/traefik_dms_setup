#!/bin/bash

# Configuration DKIM de manière idempotente
if [ ! -f "/tmp/docker-mailserver/opendkim/keys/${DOMAIN}/mail.private" ]; then
    # Générer les clés DKIM
    setup config dkim domain "${DOMAIN}"
    
    # Extraire la clé publique directement depuis mail.private
    DKIM_KEY="p=$(openssl rsa -in "/tmp/docker-mailserver/opendkim/keys/${DOMAIN}/mail.private" -pubout -outform PEM 2>/dev/null | grep -v '^-' | tr -d '\n')"
    echo "mail._domainkey IN TXT v=DKIM1; h=sha256; k=rsa; ${DKIM_KEY}" > "/tmp/docker-mailserver/opendkim/keys/${DOMAIN}/mail.txt"

    # Configuration des fichiers OpenDKIM
    echo "mail._domainkey.${DOMAIN} ${DOMAIN}:mail:/tmp/docker-mailserver/opendkim/keys/${DOMAIN}/mail.private" > "/tmp/docker-mailserver/opendkim/KeyTable"
    echo "*@${DOMAIN} mail._domainkey.${DOMAIN}" > "/tmp/docker-mailserver/opendkim/SigningTable"
    echo -e "127.0.0.1\nlocalhost\n${DOMAIN}" > "/tmp/docker-mailserver/opendkim/TrustedHosts"

    # Copier vers /etc/opendkim et ajuster les permissions
    cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
    chown -R opendkim:opendkim /etc/opendkim/
    chmod -R 0700 /etc/opendkim/keys/

    # Redémarrer OpenDKIM
    supervisorctl restart opendkim
fi

# Configuration Postfix avec proxy_interfaces
postconf -e "proxy_interfaces = ${PUBLIC_IP}"
postconf -e "proxy_protocol_networks = ${TRAEFIK_IP}"
postconf -e "smtpd_sender_restrictions = check_sender_access hash:/etc/postfix/from_filter, permit_sasl_authenticated, reject"

# Configuration Dovecot pour POP3 avec suppression immédiate
cat > /etc/dovecot/conf.d/99-pop3-delete.conf << EOF
protocol pop3 {
    pop3_delete_type = expunge
    pop3_deleted_flag = \Deleted
}
EOF

# Configuration des comptes de manière idempotente
for account in \
    "${DEFAULT_SMTP_ALIAS}:${DEFAULT_SMTP_PASSWORD}" \
    "${CATCHALL_ALIAS}:${CATCHALL_PASSWORD}" \
    "${BOUNCE_ALIAS}:${BOUNCE_PASSWORD}"
do
    alias="${account%:*}"
    password="${account#*:}"
    email="${alias}@${DOMAIN}"
    
    if ! setup email list | grep -q "${email}"; then
        setup email add "${email}" "${password}"
    fi
done

# Configuration des filtres d'envoi
cat > /etc/postfix/from_filter << EOF
${DEFAULT_SMTP_ALIAS}@${DOMAIN} FILTER smtp_only
EOF

# Configuration du catchall avec exclusion de bounce
cat > /etc/postfix/virtual << EOF
@${DOMAIN} ${CATCHALL_ALIAS}@${DOMAIN}
${BOUNCE_ALIAS}@${DOMAIN} ${BOUNCE_ALIAS}@${DOMAIN}
EOF

# Application des configurations
postmap /etc/postfix/from_filter
postmap /etc/postfix/virtual

# Rechargement des configurations
doveadm reload
postfix reload 