const express = require('express');
const { ping, getFruitQty } = require('./db');

const app = express();
const port = process.env.PORT || 3000;

app.get('/', async (req, res, next) => {
  try {
    const qty = await getFruitQty('apples');
    res.send(`<html><body><h1>Apples \u{1F34F}</h1><p>There are ${qty} apples.</p></body></html>`);
  } catch (err) {
    next(err);
  }
});

app.get('/healthz', (req, res) => res.send('ok'));

app.get('/readyz', async (req, res) => {
  try {
    await ping();
    res.send('ready');
  } catch (err) {
    console.error('readiness check failed:', err.message);
    res.status(503).send('not ready');
  }
});

app.listen(port, () => {
  console.log(`listening on ${port}`);
});

module.exports = app;
