# TERRA App — Monorepo

App de corrida/caminhada com conquista de território.

## Pré-requisitos

- Node.js 20+
- Docker Desktop
- Flutter 3.22+
- (iOS build) macOS com Xcode 15+

## Setup Rápido

### 1. Banco local (PostgreSQL + PostGIS + Redis)

```bash
cd infra
docker compose up -d
# Aguarde os healthchecks passarem (~10s)
docker compose ps
```

Verificar PostGIS:
```bash
psql postgresql://terra:terra_dev_pass@localhost:5432/terra_dev -c "SELECT PostGIS_Version();"
```

### 2. API

```bash
cd api
cp .env.example .env
# Preencha as variáveis do Supabase no .env
npm install
npm run db:migrate
npm run dev
# API disponível em http://localhost:3000
```

### 3. Shared types

```bash
cd shared
npm install
npm run build
```

### 4. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

## Estrutura

```
terra/
├── api/        Node.js + TypeScript + Fastify
├── shared/     Tipos TypeScript compartilhados
├── mobile/     Flutter (iOS + Android)
├── infra/      Docker Compose local
└── docs/       Specs e planos
```

## Comandos úteis

| Comando | Descrição |
|---------|-----------|
| `npm run dev:api` | Sobe API em modo watch |
| `npm run test:api` | Testes com coverage |
| `npm run db:migrate` | Rodar migrations pendentes |
| `npm run db:rollback` | Reverter última migration |

## Ambientes

| Ambiente | Banco | API |
|----------|-------|-----|
| Local | Docker Compose | `npm run dev` |
| Staging | Supabase staging | Railway staging |
| Produção | Supabase prod | Railway prod |
