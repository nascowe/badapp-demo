const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();
const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');
const _ = require('lodash');

const app = express();
const db = new sqlite3.Database(':memory:');
const PORT = process.env.PORT || 3000;

// Intentionally weak/hardcoded secret for SAST/secrets demo.
const JWT_SECRET = 'campus-demo-secret-123';
const FAKE_AWS_ACCESS_KEY_ID = 'AKIAIOSFODNN7EXAMPLE';

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());

function seed() {
  db.serialize(() => {
    db.run('CREATE TABLE students (id INTEGER PRIMARY KEY, name TEXT, email TEXT, role TEXT)');
    db.run("INSERT INTO students VALUES (1, 'Ava Chen', 'ava.chen@student.example.edu', 'student')");
    db.run("INSERT INTO students VALUES (2, 'Noah Patel', 'noah.patel@student.example.edu', 'student')");
    db.run("INSERT INTO students VALUES (3, 'Mia Garcia', 'mia.garcia@staff.example.edu', 'admin')");

    db.run('CREATE TABLE grants (id INTEGER PRIMARY KEY, title TEXT, principal_investigator TEXT, amount INTEGER)');
    db.run("INSERT INTO grants VALUES (1, 'Quantum Materials Lab', 'Prof. Lee', 850000)");
    db.run("INSERT INTO grants VALUES (2, 'Bioinformatics Center', 'Prof. Morgan', 1200000)");
  });
}
seed();

app.get('/', (req, res) => {
  res.send(`
    <h1>CampusHub</h1>
    <p>University student and research services portal.</p>
    <ul>
      <li><a href="/api/students/search?q=Ava">Student search</a></li>
      <li><a href="/api/feedback?message=hello">Feedback</a></li>
      <li><a href="/api/research-grants">Research grants API</a></li>
    </ul>
  `);
});

// SAST/IAST/DAST: SQL injection via string concatenation.
app.get('/api/students/search', (req, res) => {
  const q = req.query.q || '';
  const sql = "SELECT id, name, email, role FROM students WHERE name LIKE '%" + q + "%'");
  db.all(sql, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message, sql });
    res.json({ query: q, sql, results: rows });
  });
});

// DAST/API Security: reflected XSS.
app.get('/api/feedback', (req, res) => {
  const message = req.query.message || '';
  res.set('Content-Type', 'text/html');
  res.send(`<h2>Thanks for your feedback</h2><p>${message}</p>`);
});

// SAST/IAST: path traversal.
app.get('/api/files', (req, res) => {
  const name = req.query.name || 'public-handbook.txt';
  const filePath = path.join(__dirname, 'files', name);
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) return res.status(404).json({ error: 'file not found', attempted: filePath });
    res.type('text/plain').send(data);
  });
});

// SAST/IAST/RASP: command injection.
app.get('/api/admin/ping', (req, res) => {
  const host = req.query.host || '127.0.0.1';
  childProcess.exec(`ping -c 1 ${host}`, (err, stdout, stderr) => {
    res.json({ host, stdout, stderr, error: err ? err.message : null });
  });
});

// API Security: sensitive data on an unauthenticated endpoint.
app.get('/api/research-grants', (req, res) => {
  db.all('SELECT * FROM grants', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ classification: 'internal-research', grants: rows });
  });
});

// Weak auth example.
app.post('/api/login', (req, res) => {
  const { email } = req.body;
  const token = jwt.sign({ email, role: email && email.includes('staff') ? 'admin' : 'student' }, JWT_SECRET, { expiresIn: '7d' });
  res.cookie('campushub_session', token, { httpOnly: false, secure: false });
  res.json({ token });
});

// Prototype pollution pattern for SAST/SCA-related demo.
app.post('/api/preferences', (req, res) => {
  const defaults = { theme: 'light', alerts: true };
  const merged = _.merge(defaults, req.body);
  res.json({ preferences: merged });
});

app.listen(PORT, () => {
  console.log(`CampusHub vulnerable API running at http://localhost:${PORT}`);
  console.log('Demo secret loaded:', FAKE_AWS_ACCESS_KEY_ID.substring(0, 4) + '...');
});
