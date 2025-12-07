
# 📸 Tarefas com LocalStack

Este projeto demonstra uma aplicação Flutter integrada a um backend Node.js e ao LocalStack, simulando serviços AWS (S3, DynamoDB, SQS, SNS) para gerenciamento de tarefas com fotos.

---

## Funcionalidades

- Adicionar tarefas com nome, data, prioridade e foto (da galeria ou câmera)
- Listar tarefas cadastradas (dados vindos do DynamoDB simulado)
- Visualizar fotos das tarefas (armazenadas no S3 simulado)
- Swipe-to-refresh para atualizar a lista

---

## Pré-requisitos

- [Docker](https://www.docker.com/) instalado
- [Flutter](https://docs.flutter.dev/get-started/install) (SDK 3.10+)
- [Node.js](https://nodejs.org/) (v16+ recomendado)
- [LocalStack](https://app.localstack.cloud/getting-started)

---

## Como inicializar o projeto

### 1. Suba o LocalStack

No diretório raiz do projeto:

```sh
docker-compose up
```

Isso irá iniciar o LocalStack simulando S3, DynamoDB, SQS e SNS na porta 4566.

### 2. Instale as dependências do backend

```sh
cd back
npm install
```

### 3. Inicie o backend Node.js

```sh
node backend_upload.js
```

O backend estará disponível em http://localhost:3000

### 4. Instale as dependências do app Flutter

```sh
cd appdefoto
flutter pub get
```

### 5. Rode o app Flutter

Conecte um emulador ou dispositivo e execute:

```sh
flutter run
```

No Android Emulator, o app já está configurado para acessar o backend via `10.0.2.2`.

---

## Observações

- As imagens são salvas no bucket S3 simulado (`shopping-images`).
- As tarefas são persistidas no DynamoDB simulado.
- O backend inicializa e garante a existência dos recursos AWS simulados.
- O app permite escolher imagens da galeria ou tirar foto na hora.
- Logo abaixo, o app também carrega as tarefas já existentes no container
- Para visualizar os dados, utilize a visualização web do LocalStack (https://app.localstack.cloud/inst/default/status)

---

## Estrutura do Projeto

- `docker-compose.yml` — Sobe o LocalStack
- `back/` — Backend Node.js (Express, AWS SDK)
- `appdefoto/` — App Flutter

---

## Demonstração

1. Suba o LocalStack e backend
2. Rode o app Flutter
3. Adicione tarefas com foto (galeria/câmera)
4. Veja as tarefas e imagens sendo listadas e exibidas
5. Valide na visualização web que as imagens estão no bucket S3 simulado
