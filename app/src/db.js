const { MongoClient } = require('mongodb');

const uri = process.env.MONGO_URI || 'mongodb://localhost:27017';
const dbName = process.env.MONGO_DB || 'fruits';

let client;
let db;

async function connect() {
  if (db) return db;
  client = new MongoClient(uri);
  await client.connect();
  db = client.db(dbName);
  return db;
}

async function ping() {
  const database = await connect();
  await database.command({ ping: 1 });
}

async function getFruitQty(name) {
  const database = await connect();
  const fruit = await database.collection('fruits').findOne({ name });
  return fruit ? fruit.qty : 0;
}

module.exports = { connect, ping, getFruitQty };
