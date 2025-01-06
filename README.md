# Configuration DMS avec Traefik

Ce projet configure un serveur de messagerie Docker Mail Server (DMS) avec Traefik comme reverse proxy.

## Prérequis

- Docker et Docker Compose installés
- Un domaine configuré avec les enregistrements DNS appropriés
- Une IP publique fixe

## Structure du projet

```
.
├── data/
│   ├── traefik/
│   │   └── acme.json
│   └── dms/
│       ├── mail-data/
│       └── config/
│           └── user-patches.sh
├── docker-compose.yml
├── .env
└── README.md
```

## Configuration

1. Copiez le fichier `.env.example` en `.env` et configurez les variables :
   ```bash
   cp .env.example .env
   ```

2. Modifiez le fichier `.env` avec vos paramètres :
   - `PUBLIC_IP` : Votre IP publique
   - `DOMAIN` : Votre nom de domaine
   - `MAIL_HOSTNAME` : Le nom d'hôte du serveur mail
   - Modifiez les mots de passe par défaut

3. Créez le fichier acme.json et définissez les permissions :
   ```bash
   touch data/traefik/acme.json
   chmod 600 data/traefik/acme.json
   ```

## Démarrage

1. Lancez les conteneurs :
   ```bash
   docker-compose up -d
   ```

2. Vérifiez les logs :
   ```bash
   docker-compose logs -f
   ```

## Configuration des comptes

Le script `user-patches.sh` configure automatiquement :
- Un compte pour les notifications SMTP
- Un compte catch-all pour recevoir tous les emails
- Un compte pour les bounces

## Ports utilisés

- 25 : SMTP (STARTTLS)
- 465 : SMTPS (SSL/TLS implicite)
- 110 : POP3 (STARTTLS)
- 995 : POP3S (SSL/TLS implicite)

## Sécurité

- Les certificats SSL sont gérés automatiquement par Let's Encrypt via Traefik
- Le proxy protocol est activé pour préserver les IPs sources
- DKIM est configuré automatiquement au démarrage 