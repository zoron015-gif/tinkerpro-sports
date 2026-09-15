const mysql = require('mysql2/promise');

const requiredDatabaseSettings = ['DB_HOST', 'DB_NAME', 'DB_USER'];
const missingDatabaseSettings = requiredDatabaseSettings.filter(
  (name) => !process.env[name],
);

if (missingDatabaseSettings.length > 0) {
  throw new Error(
    `Missing database settings: ${missingDatabaseSettings.join(', ')}. ` +
      'Set them in backend/.env.',
  );
}

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  waitForConnections: true,
  connectionLimit: 10,
  dateStrings: true,
});

module.exports = pool;
