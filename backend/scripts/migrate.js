require('dotenv').config();

const pool = require('../src/db');
const { runSchemaMigrations } = require('../src/schema_migrations');

runSchemaMigrations(pool)
  .then(() => {
    console.log('Database migrations completed successfully.');
  })
  .catch((error) => {
    console.error('Database migrations failed.', error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
