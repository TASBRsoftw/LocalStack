const express = require('express');
const AWS = require('aws-sdk');
const bodyParser = require('body-parser');
const cors = require('cors');
const multer = require('multer');

const app = express();
const port = 3000; // Porta do backend Node.js fora da faixa 4500-4600

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
const upload = multer(); // Para multipart/form-data

// Configuração do S3 apontando para o LocalStack
const s3 = new AWS.S3({
  endpoint: 'http://localhost:4566',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
  s3ForcePathStyle: true,
});

const dynamodb = new AWS.DynamoDB({
  endpoint: 'http://localhost:4566',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
});
const docClient = new AWS.DynamoDB.DocumentClient({
  endpoint: 'http://localhost:4566',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
});
const sqs = new AWS.SQS({
  endpoint: 'http://localhost:4566',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
});
const sns = new AWS.SNS({
  endpoint: 'http://localhost:4566',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
});

const BUCKET_NAME = 'shopping-images';
const TASKS_TABLE = 'tasks';
const SQS_QUEUE_NAME = 'tasks-queue';
const SNS_TOPIC_NAME = 'tasks-topic';
let SQS_QUEUE_URL = '';
let SNS_TOPIC_ARN = '';
let awsReady = false;

// Função para garantir que o bucket existe
async function ensureBucket() {
  try {
    await s3.headBucket({ Bucket: BUCKET_NAME }).promise();
    console.log('Bucket já existe:', BUCKET_NAME);
  } catch (err) {
    if (err.statusCode === 404 || err.statusCode === 400) {
      try {
        await s3.createBucket({ Bucket: BUCKET_NAME }).promise();
        console.log('Bucket criado:', BUCKET_NAME);
      } catch (createErr) {
        console.error('Erro ao criar bucket:', createErr);
      }
    } else {
      console.error('Erro ao verificar bucket:', err);
    }
  }
}

async function ensureDynamoTable() {
  try {
    await dynamodb.describeTable({ TableName: TASKS_TABLE }).promise();
    console.log('Tabela DynamoDB já existe:', TASKS_TABLE);
  } catch (err) {
    if (err.code === 'ResourceNotFoundException') {
      await dynamodb.createTable({
        TableName: TASKS_TABLE,
        KeySchema: [{ AttributeName: 'id', KeyType: 'HASH' }],
        AttributeDefinitions: [{ AttributeName: 'id', AttributeType: 'S' }],
        ProvisionedThroughput: { ReadCapacityUnits: 1, WriteCapacityUnits: 1 },
      }).promise();
      console.log('Tabela DynamoDB criada:', TASKS_TABLE);
    } else {
      console.error('Erro ao verificar/criar tabela DynamoDB:', err);
    }
  }
}

async function ensureSqsQueue() {
  try {
    const data = await sqs.createQueue({ QueueName: SQS_QUEUE_NAME }).promise();
    SQS_QUEUE_URL = data.QueueUrl;
    console.log('Fila SQS pronta:', SQS_QUEUE_URL);
  } catch (err) {
    console.error('Erro ao criar fila SQS:', err);
  }
}

async function ensureSnsTopic() {
  try {
    const data = await sns.createTopic({ Name: SNS_TOPIC_NAME }).promise();
    SNS_TOPIC_ARN = data.TopicArn;
    console.log('Tópico SNS pronto:', SNS_TOPIC_ARN);
  } catch (err) {
    console.error('Erro ao criar tópico SNS:', err);
  }
}

async function initializeAwsResources() {
  await ensureBucket();
  await ensureDynamoTable();
  await ensureSqsQueue();
  await ensureSnsTopic();
  awsReady = true;
}

initializeAwsResources();

// Rota para upload via multipart/form-data
app.post('/upload', upload.single('file'), async (req, res) => {
  let buffer, filename;
  if (req.file) {
    buffer = req.file.buffer;
    filename = req.file.originalname || `foto_${Date.now()}.jpg`;
  } else if (req.body.image) {
    buffer = Buffer.from(req.body.image, 'base64');
    filename = `foto_${Date.now()}.jpg`;
  } else {
    return res.status(400).json({ error: 'No image provided' });
  }
  const params = {
    Bucket: BUCKET_NAME,
    Key: filename,
    Body: buffer,
    ContentType: 'image/jpeg',
  };
  try {
    await s3.putObject(params).promise();
    res.json({ message: 'Upload successful', filename });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/task', upload.single('file'), async (req, res) => {
  if (!awsReady) {
    return res.status(503).json({ error: 'Serviços AWS ainda inicializando, tente novamente em instantes.' });
  }
  const { name, date, priority } = req.body;
  let imageUrl = null;
  let buffer, filename;
  if (req.file) {
    buffer = req.file.buffer;
    filename = req.file.originalname || `foto_${Date.now()}.jpg`;
    const params = {
      Bucket: BUCKET_NAME,
      Key: filename,
      Body: buffer,
      ContentType: 'image/jpeg',
    };
    await s3.putObject(params).promise();
    imageUrl = filename;
  }
  // Salvar tarefa no DynamoDB
  const id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const item = { id, name, date, priority, imageUrl };
  try {
    await docClient.put({ TableName: TASKS_TABLE, Item: item }).promise();
    console.log('Tarefa salva no DynamoDB:', item);
  } catch (err) {
    console.error('Erro ao salvar no DynamoDB:', err);
    return res.status(500).json({ error: 'Erro ao salvar no DynamoDB', details: err });
  }
  // Enviar evento para SQS
  try {
    await sqs.sendMessage({ QueueUrl: SQS_QUEUE_URL, MessageBody: JSON.stringify(item) }).promise();
    console.log('Mensagem enviada para SQS');
  } catch (err) {
    console.error('Erro ao enviar para SQS:', err);
  }
  // Publicar evento no SNS
  try {
    await sns.publish({ TopicArn: SNS_TOPIC_ARN, Message: JSON.stringify(item) }).promise();
    console.log('Mensagem publicada no SNS');
  } catch (err) {
    console.error('Erro ao publicar no SNS:', err);
  }
  res.json({ message: 'Tarefa criada com sucesso', item });
});

app.get('/tasks', async (req, res) => {
  if (!awsReady) {
    return res.status(503).json({ error: 'Serviços AWS ainda inicializando, tente novamente em instantes.' });
  }
  try {
    const data = await docClient.scan({ TableName: TASKS_TABLE }).promise();
    res.json({ items: data.Items || [] });
  } catch (err) {
    console.error('Erro ao buscar tarefas no DynamoDB:', err);
    res.status(500).json({ error: 'Erro ao buscar tarefas', details: err });
  }
});

app.listen(port, () => {
  console.log(`Backend Node.js rodando em http://localhost:${port}`);
});
