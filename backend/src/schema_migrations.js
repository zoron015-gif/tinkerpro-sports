const crypto = require('node:crypto');

async function runSchemaMigrations(pool) {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INT UNSIGNED NOT NULL,
      name VARCHAR(255) NOT NULL,
      applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (version)
    ) ENGINE=InnoDB
  `);

async function ensureMerchantBusinessesSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS merchant_businesses (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      merchant_id BIGINT UNSIGNED NOT NULL,
      business_type VARCHAR(50) NOT NULL,
      name VARCHAR(255) NOT NULL,
      category VARCHAR(100) NOT NULL,
      address VARCHAR(500) NOT NULL,
      latitude DOUBLE NULL,
      longitude DOUBLE NULL,
      facility_type VARCHAR(50) NOT NULL,
      price_per_hour DECIMAL(10, 2) NOT NULL DEFAULT 0,
      slot_count INT UNSIGNED NOT NULL DEFAULT 1,
      sports_slots_json JSON NULL,
      event_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
      opening_hours VARCHAR(100) NOT NULL DEFAULT 'Open hours',
      availability VARCHAR(255) NOT NULL DEFAULT 'Any',
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      rate_periods JSON NULL,
      included_players INT UNSIGNED NOT NULL DEFAULT 0,
      additional_player_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
      amenities_json JSON NULL,
      details VARCHAR(1000) NULL,
      image_url LONGTEXT NULL,
      image_urls JSON NULL,
      visit_url VARCHAR(1000) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_merchant_businesses_merchant (merchant_id, created_at),
      CONSTRAINT fk_merchant_businesses_user
        FOREIGN KEY (merchant_id) REFERENCES users (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await ensureTableColumn(
    'merchant_businesses',
    'included_players',
    'INT UNSIGNED NOT NULL DEFAULT 0',
  );
  await ensureTableColumn(
    'merchant_businesses',
    'additional_player_fee',
    'DECIMAL(10, 2) NOT NULL DEFAULT 0',
  );
  await ensureTableColumn('conversation_members', 'archived_at', 'DATETIME NULL');
  await ensureTableColumn('conversation_members', 'deleted_at', 'DATETIME NULL');
  await ensureTableColumn(
    'conversation_members',
    'manually_unread_at',
    'DATETIME NULL',
  );
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id BIGINT UNSIGNED NOT NULL,
      blocked_user_id BIGINT UNSIGNED NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (blocker_id, blocked_user_id),
      KEY idx_user_blocks_blocked (blocked_user_id),
      CONSTRAINT fk_user_blocks_blocker FOREIGN KEY (blocker_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);

  const columns = [
    ['price_per_hour', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['slot_count', 'INT UNSIGNED NOT NULL DEFAULT 1'],
    ['sports_slots_json', 'JSON NULL'],
    ['event_fee', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['opening_hours', "VARCHAR(100) NOT NULL DEFAULT 'Open hours'"],
    ['rate_periods', 'JSON NULL'],
    ['amenities_json', 'JSON NULL'],
    ['image_urls', 'JSON NULL'],
    ['visit_url', 'VARCHAR(1000) NULL'],
    ['latitude', 'DOUBLE NULL'],
    ['longitude', 'DOUBLE NULL'],
    ['enabled', 'TINYINT(1) NOT NULL DEFAULT 1'],
  ];

  for (const [name, definition] of columns) {
    try {
      await pool.execute(
        `ALTER TABLE merchant_businesses ADD COLUMN ${name} ${definition}`,
      );
    } catch (error) {
      if (error.code !== 'ER_DUP_FIELDNAME') throw error;
    }
    for (const [name, definition] of [
      ['owner_email', 'VARCHAR(255) NULL'],
      ['owner_phone', 'VARCHAR(30) NULL'],
    ]) {
      try {
        await pool.execute(
          `ALTER TABLE saved_items ADD COLUMN ${name} ${definition}`,
        );
      } catch (error) {
        if (error.code !== 'ER_DUP_FIELDNAME') throw error;
      }
    }
  }
  await pool.execute(
    "ALTER TABLE merchant_businesses MODIFY COLUMN availability VARCHAR(255) NOT NULL DEFAULT 'Any'",
  );
  try {
    await pool.execute(
      'ALTER TABLE merchant_businesses ADD INDEX idx_merchant_businesses_type_enabled (business_type, enabled)',
    );
  } catch (error) {
    if (error.code !== 'ER_DUP_KEYNAME') throw error;
  }
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS sports_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      player_capacity INT UNSIGNED NULL,
      court_type VARCHAR(100) NULL,
      equipment TEXT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_sports_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS event_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      event_name VARCHAR(255) NULL,
      event_type VARCHAR(100) NULL,
      event_types_json JSON NULL,
      event_date DATE NULL,
      start_time TIME NULL,
      end_time TIME NULL,
      setup_hours DECIMAL(5, 2) NULL,
      teardown_hours DECIMAL(5, 2) NULL,
      estimated_attendance INT UNSIGNED NULL,
      accessibility_needs TEXT NULL,
      parking_security TEXT NULL,
      attendance_min INT UNSIGNED NULL,
      attendance_max INT UNSIGNED NULL,
      parking_needs JSON NULL,
      security_needs JSON NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_event_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS fitness_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      class_capacity INT UNSIGNED NULL,
      session_duration_minutes INT UNSIGNED NULL,
      instructor_name VARCHAR(255) NULL,
      class_schedule TEXT NULL,
      fitness_categories_json JSON NULL,
      fitness_coaches_json JSON NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_fitness_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  for (const [name, definition] of [
    ['fitness_categories_json', 'JSON NULL'],
    ['fitness_coaches_json', 'JSON NULL'],
  ]) {
    await ensureTableColumn('fitness_business_details', name, definition);
  }
  for (const [name, definition] of [
    ['event_types_json', 'JSON NULL'],
    ['attendance_min', 'INT UNSIGNED NULL'],
    ['attendance_max', 'INT UNSIGNED NULL'],
    ['accessibility_needs', 'JSON NULL'],
    ['parking_needs', 'JSON NULL'],
    ['security_needs', 'JSON NULL'],
  ]) {
    await ensureTableColumn('event_business_details', name, definition);
  }
}

async function ensureMessagingSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS conversations (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      type ENUM('direct', 'group') NOT NULL DEFAULT 'direct',
      title VARCHAR(120) NULL,
      created_by BIGINT UNSIGNED NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_conversations_created (created_at),
      CONSTRAINT fk_conversations_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS conversation_members (
      conversation_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NOT NULL,
      joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      archived_at DATETIME NULL,
      deleted_at DATETIME NULL,
      manually_unread_at DATETIME NULL,
      PRIMARY KEY (conversation_id, user_id),
      KEY idx_conversation_members_user (user_id),
      CONSTRAINT fk_conversation_members_conversation FOREIGN KEY (conversation_id)
        REFERENCES conversations (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_conversation_members_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS messages (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      conversation_id BIGINT UNSIGNED NOT NULL,
      sender_id BIGINT UNSIGNED NOT NULL,
      body TEXT NULL,
      attachment_json LONGTEXT NULL,
      read_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_messages_conversation_created (conversation_id, created_at),
      KEY idx_messages_unread (conversation_id, read_at),
      CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id)
        REFERENCES conversations (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS message_reads (
      message_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NOT NULL,
      read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (message_id, user_id),
      KEY idx_message_reads_user (user_id, read_at),
      CONSTRAINT fk_message_reads_message FOREIGN KEY (message_id)
        REFERENCES messages (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_message_reads_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  try {
    await pool.execute(
      'ALTER TABLE messages ADD COLUMN attachment_json LONGTEXT NULL AFTER body',
    );
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  await pool.execute('ALTER TABLE messages MODIFY COLUMN body TEXT NULL');
}

async function ensureBookingsSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS bookings (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      customer_id BIGINT UNSIGNED NOT NULL,
      venue_id BIGINT UNSIGNED NOT NULL,
      booking_date DATE NOT NULL,
      start_time TIME NOT NULL,
      duration_hours DECIMAL(5, 2) NOT NULL,
      players INT UNSIGNED NOT NULL,
      payment_method VARCHAR(50) NOT NULL,
      price_per_hour DECIMAL(10, 2) NOT NULL,
      total_amount DECIMAL(10, 2) NOT NULL,
      downpayment_amount DECIMAL(10, 2) NOT NULL,
      extra_player_charge DECIMAL(10, 2) NOT NULL DEFAULT 0,
      event_type VARCHAR(100) NULL,
      fitness_plan_type ENUM('session', 'monthly', 'yearly') NULL,
      fitness_category VARCHAR(100) NULL,
      fitness_coach_name VARCHAR(100) NULL,
      fitness_plan_price DECIMAL(10, 2) NULL,
      fitness_coach_price DECIMAL(10, 2) NULL,
      booking_token_hash CHAR(64) NULL,
      ticket_token_hash CHAR(64) NULL,
      idempotency_key VARCHAR(100) NULL,
      idempotency_request_hash CHAR(64) NULL,
      idempotency_response_json JSON NULL,
      idempotency_response_status SMALLINT UNSIGNED NULL,
      payment_status ENUM('unpaid', 'paid', 'not_required') NOT NULL DEFAULT 'not_required',
      payment_checkout_session_id VARCHAR(100) NULL,
      payment_reference VARCHAR(100) NULL,
      paid_at DATETIME NULL,
      status ENUM('pending', 'approved', 'finished', 'cancelled') NOT NULL DEFAULT 'pending',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_bookings_customer (customer_id, booking_date, start_time),
      KEY idx_bookings_venue_time (venue_id, booking_date, start_time, status),
      UNIQUE KEY uq_bookings_checkout_session (payment_checkout_session_id),
      UNIQUE KEY uq_bookings_customer_idempotency (customer_id, idempotency_key),
      CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_bookings_venue FOREIGN KEY (venue_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  for (const [name, definition] of [
    ['booking_token_hash', 'CHAR(64) NULL'],
    ['ticket_token_hash', 'CHAR(64) NULL'],
    ['idempotency_key', 'VARCHAR(100) NULL'],
    ['idempotency_request_hash', 'CHAR(64) NULL'],
    ['idempotency_response_json', 'JSON NULL'],
    ['idempotency_response_status', 'SMALLINT UNSIGNED NULL'],
    ['extra_player_charge', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['event_type', 'VARCHAR(100) NULL'],
    ['fitness_plan_type', "ENUM('session', 'monthly', 'yearly') NULL"],
    ['fitness_category', 'VARCHAR(100) NULL'],
    ['fitness_coach_name', 'VARCHAR(100) NULL'],
    ['fitness_plan_price', 'DECIMAL(10, 2) NULL'],
    ['fitness_coach_price', 'DECIMAL(10, 2) NULL'],
    ['sport_type', 'VARCHAR(100) NULL'],
    ['slot_number', 'INT UNSIGNED NULL'],
    ['occupies_full_studio', 'TINYINT(1) NOT NULL DEFAULT 1'],
    ['payment_status', "ENUM('unpaid', 'paid', 'not_required') NOT NULL DEFAULT 'not_required'"],
    ['payment_checkout_session_id', 'VARCHAR(100) NULL'],
    ['payment_reference', 'VARCHAR(100) NULL'],
    ['paid_at', 'DATETIME NULL'],
  ]) {
    await ensureTableColumn('bookings', name, definition);
  }
  const [indexes] = await pool.execute(
    `SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = 'bookings'
       AND index_name = 'uq_bookings_checkout_session'
     LIMIT 1`,
  );
  if (indexes.length === 0) {
    await pool.execute(
      'ALTER TABLE bookings ADD UNIQUE KEY uq_bookings_checkout_session (payment_checkout_session_id)',
    );
  }
  const [idempotencyIndexes] = await pool.execute(
    `SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = 'bookings'
       AND index_name = 'uq_bookings_customer_idempotency'
     LIMIT 1`,
  );
  if (idempotencyIndexes.length === 0) {
    await pool.execute(
      'ALTER TABLE bookings ADD UNIQUE KEY uq_bookings_customer_idempotency (customer_id, idempotency_key)',
    );
  }
}

async function ensureTableColumn(tableName, columnName, definition) {
  const [rows] = await pool.execute(
    `SELECT 1
       FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND column_name = ?
      LIMIT 1`,
    [tableName, columnName],
  );
  if (rows.length > 0) return;
  await pool.execute(
    `ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${definition}`,
  );
}

async function ensureFitnessBookingAttendanceSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS fitness_booking_attendance (
      booking_id BIGINT UNSIGNED NOT NULL,
      customer_id BIGINT UNSIGNED NOT NULL,
      attendance_date DATE NOT NULL,
      status ENUM('present', 'absent') NOT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (booking_id, attendance_date),
      KEY idx_fitness_attendance_customer (customer_id, booking_id),
      CONSTRAINT fk_fitness_attendance_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_fitness_attendance_customer FOREIGN KEY (customer_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
}

async function ensureCustomerProfileSchema() {
  await pool.execute('ALTER TABLE users MODIFY COLUMN avatar_url LONGTEXT NULL');
  await ensureTableColumn('users', 'address', 'VARCHAR(500) NULL');
  await ensureTableColumn('users', 'hobby', 'VARCHAR(255) NULL');
  await ensureTableColumn('merchant_profiles', 'business_image', 'LONGTEXT NULL');
}

async function ensureNewsAndReviewsSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS merchant_news (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      business_id BIGINT UNSIGNED NOT NULL,
      title VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      image_url LONGTEXT NULL,
      status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_merchant_news_business_status (business_id, status, created_at),
      CONSTRAINT fk_merchant_news_business FOREIGN KEY (business_id)
        REFERENCES merchant_businesses (id) ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS venue_reviews (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      business_id BIGINT UNSIGNED NOT NULL,
      booking_id BIGINT UNSIGNED NOT NULL,
      customer_id BIGINT UNSIGNED NOT NULL,
      rating TINYINT UNSIGNED NOT NULL,
      comment VARCHAR(2000) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_venue_reviews_booking_customer (booking_id, customer_id),
      KEY idx_venue_reviews_business (business_id, created_at),
      CONSTRAINT fk_venue_reviews_business FOREIGN KEY (business_id)
        REFERENCES merchant_businesses (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_venue_reviews_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_venue_reviews_customer FOREIGN KEY (customer_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT chk_venue_reviews_rating CHECK (rating BETWEEN 1 AND 5)
    ) ENGINE=InnoDB
  `);
}

async function ensureUserActivitySchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS user_activity_logs (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id BIGINT UNSIGNED NOT NULL,
      activity_type VARCHAR(50) NOT NULL,
      title VARCHAR(255) NOT NULL,
      description VARCHAR(500) NOT NULL,
      venue_id BIGINT UNSIGNED NULL,
      venue_name VARCHAR(255) NULL,
      sport_type VARCHAR(100) NULL,
      details_json JSON NULL,
      actor_user_id BIGINT UNSIGNED NULL,
      actor_role VARCHAR(50) NULL,
      request_id CHAR(36) NULL,
      ip_address VARCHAR(45) NULL,
      user_agent VARCHAR(500) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_user_activity_logs_user_created (user_id, created_at, id),
      KEY idx_user_activity_logs_request (request_id),
      CONSTRAINT fk_user_activity_logs_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await ensureTableColumn(
    'user_activity_logs',
    'venue_id',
    'BIGINT UNSIGNED NULL',
  );
  await ensureTableColumn(
    'user_activity_logs',
    'venue_name',
    'VARCHAR(255) NULL',
  );
  await ensureTableColumn(
    'user_activity_logs',
    'sport_type',
    'VARCHAR(100) NULL',
  );
  await ensureTableColumn(
    'user_activity_logs',
    'details_json',
    'JSON NULL',
  );
  for (const [name, definition] of [
    ['actor_user_id', 'BIGINT UNSIGNED NULL'],
    ['actor_role', 'VARCHAR(50) NULL'],
    ['request_id', 'CHAR(36) NULL'],
    ['ip_address', 'VARCHAR(45) NULL'],
    ['user_agent', 'VARCHAR(500) NULL'],
  ]) {
    await ensureTableColumn('user_activity_logs', name, definition);
  }
  const [activityIndexes] = await pool.execute(
    `SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = 'user_activity_logs'
       AND index_name = 'idx_user_activity_logs_request'
     LIMIT 1`,
  );
  if (activityIndexes.length === 0) {
    try {
      await pool.execute(
        'CREATE INDEX idx_user_activity_logs_request ON user_activity_logs (request_id)',
      );
    } catch (error) {
      if (error.code !== 'ER_DUP_KEYNAME') throw error;
    }
  }
  await pool.execute(`
    UPDATE user_activity_logs a
    JOIN bookings b
      ON b.id = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(a.description, '#', -1), ' ', 1) AS UNSIGNED)
    JOIN merchant_businesses v ON v.id = b.venue_id
    SET a.venue_id = b.venue_id,
        a.venue_name = v.name,
        a.sport_type = v.category,
        a.details_json = JSON_OBJECT(
          'bookingId', b.id,
          'bookingDate', DATE_FORMAT(b.booking_date, '%Y-%m-%d'),
          'startTime', TIME_FORMAT(b.start_time, '%H:%i:%s'),
          'durationHours', b.duration_hours,
          'players', b.players
        )
    WHERE a.venue_id IS NULL
      AND a.activity_type IN ('booking_requested', 'booking_approved', 'booking_finished')
      AND a.description REGEXP '^Booking #[0-9]+'
  `);
}

async function ensureVenueHeartsSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS venue_hearts (
      business_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id, user_id),
      KEY idx_venue_hearts_user (user_id, business_id),
      CONSTRAINT fk_venue_hearts_business FOREIGN KEY (business_id)
        REFERENCES merchant_businesses (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_venue_hearts_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
}
  const connection = await pool.getConnection();
  const lockName = `tinkerpro_migrations_${crypto
    .createHash('sha256')
    .update(String(process.env.DB_NAME || 'database'))
    .digest('hex')
    .slice(0, 24)}`;
  let lockAcquired = false;
  try {
    const [lockRows] = await connection.execute(
      'SELECT GET_LOCK(?, 60) AS acquired',
      [lockName],
    );
    lockAcquired = Number(lockRows[0]?.acquired) === 1;
    if (!lockAcquired) {
      throw new Error('Could not acquire the database migration lock.');
    }

    const [applied] = await connection.execute(
      'SELECT version FROM schema_migrations',
    );
    const appliedVersions = new Set(applied.map((row) => Number(row.version)));
    if (!appliedVersions.has(1)) {
      const foundationalMigrations = await Promise.allSettled([
        ensureMerchantBusinessesSchema(),
        ensureMessagingSchema(),
      ]);
      const failedMigration = foundationalMigrations.find(
        (result) => result.status === 'rejected',
      );
      if (failedMigration) throw failedMigration.reason;
      await ensureBookingsSchema();
      await ensureFitnessBookingAttendanceSchema();
      await ensureCustomerProfileSchema();
      await ensureNewsAndReviewsSchema();
      await ensureUserActivitySchema();
      await ensureVenueHeartsSchema();
      await connection.execute(
        `INSERT INTO schema_migrations (version, name)
         VALUES (?, ?)`,
        [1, 'legacy-schema-upgrades'],
      );
    }
  } finally {
    try {
      if (lockAcquired) {
        await connection.execute('SELECT RELEASE_LOCK(?)', [lockName]);
      }
    } finally {
      connection.release();
    }
  }
}

module.exports = { runSchemaMigrations };
