/**
 * Baby Sleep Tracker — Backend API
 * 
 * Endpoints:
 *   GET  /api/data?token=<token>      → Returns all data for this token
 *   PUT  /api/data?token=<token>      → Saves/replaces all data for this token
 *   GET  /api/health                  → Health check
 * 
 * Data is stored in SQLite — one row per token (user).
 * The token is hashed server-side so raw tokens aren't stored.
 * 
 * Environment variables:
 *   PORT          — server port (default 3456)
 *   DATA_DIR      — directory for SQLite DB (default ./data)
 *   ALLOWED_ORIGINS — comma-separated CORS origins (default *)
 */

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

// ---- Config ----
const PORT = process.env.PORT || 3456;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim())
  : ['*'];

// Ensure data directory
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

// ---- SQLite setup ----
const Database = require('better-sqlite3');
const db = new Database(path.join(DATA_DIR, 'sleep.db'));

db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS user_data (
    token_hash TEXT PRIMARY KEY,
    data TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

const getStmt = db.prepare('SELECT data, updated_at FROM user_data WHERE token_hash = ?');
const upsertStmt = db.prepare(`
  INSERT INTO user_data (token_hash, data, updated_at)
  VALUES (?, ?, datetime('now'))
  ON CONFLICT(token_hash) DO UPDATE SET data = excluded.data, updated_at = datetime('now')
`);

// ---- Helpers ----
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function extractToken(req) {
  // From query param or Authorization header
  const q = req.query.token;
  if (q) return q;
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  return null;
}

// ---- Express app ----
const app = express();

app.use(cors({
  origin: ALLOWED_ORIGINS[0] === '*' ? true : ALLOWED_ORIGINS,
  methods: ['GET', 'PUT', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '5mb' }));

// Rate limiting (simple in-memory)
const rateLimits = new Map();
function rateLimit(key, maxPerMin) {
  const now = Date.now();
  const windowStart = now - 60000;
  let hits = rateLimits.get(key) || [];
  hits = hits.filter(t => t > windowStart);
  if (hits.length >= maxPerMin) return false;
  hits.push(now);
  rateLimits.set(key, hits);
  return true;
}

// Clean up rate limit map every 5 min
setInterval(() => {
  const cutoff = Date.now() - 120000;
  for (const [key, hits] of rateLimits) {
    const valid = hits.filter(t => t > cutoff);
    if (valid.length === 0) rateLimits.delete(key);
    else rateLimits.set(key, valid);
  }
}, 300000);

// ---- Routes ----

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Get data
app.get('/api/data', (req, res) => {
  const token = extractToken(req);
  if (!token) return res.status(401).json({ error: 'Token required' });

  const tokenHash = hashToken(token);
  if (!rateLimit(tokenHash, 30)) return res.status(429).json({ error: 'Rate limited' });

  const row = getStmt.get(tokenHash);
  if (!row) return res.json({ data: null, updatedAt: null });

  try {
    const parsed = JSON.parse(row.data);
    res.json({ data: parsed, updatedAt: row.updated_at });
  } catch (e) {
    res.json({ data: null, updatedAt: null });
  }
});

// Save data
app.put('/api/data', (req, res) => {
  const token = extractToken(req);
  if (!token) return res.status(401).json({ error: 'Token required' });

  const tokenHash = hashToken(token);
  if (!rateLimit(tokenHash, 20)) return res.status(429).json({ error: 'Rate limited' });

  const payload = req.body;
  if (!payload) return res.status(400).json({ error: 'Body required' });

  try {
    const jsonStr = JSON.stringify(payload);
    if (jsonStr.length > 5 * 1024 * 1024) {
      return res.status(413).json({ error: 'Payload too large (max 5MB)' });
    }
    upsertStmt.run(tokenHash, jsonStr);
    res.json({ status: 'ok', updatedAt: new Date().toISOString() });
  } catch (e) {
    console.error('Save error:', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// 404 for everything else
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ---- Start ----
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Baby Sleep API running on port ${PORT}`);
  console.log(`Data dir: ${DATA_DIR}`);
  console.log(`CORS origins: ${ALLOWED_ORIGINS.join(', ')}`);
});
