-- TinkerPro Sports user schema
-- MySQL 8.0+

CREATE DATABASE IF NOT EXISTS tinkerpro_sports
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE tinkerpro_sports;

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NULL,
  first_name VARCHAR(100) NULL,
  last_name VARCHAR(100) NULL,
  phone VARCHAR(30) NULL,
  avatar_url LONGTEXT NULL,
  role ENUM('customer', 'merchant') NOT NULL DEFAULT 'customer',
  status ENUM('pending', 'active', 'suspended', 'deleted') NOT NULL DEFAULT 'pending',
  email_verified_at DATETIME NULL,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role_status (role, status),
  KEY idx_users_created_at (created_at)
) ENGINE=InnoDB;

CREATE TABLE user_identities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  provider ENUM('google') NOT NULL,
  provider_user_id VARCHAR(255) NOT NULL,
  provider_email VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_identity_provider_user (provider, provider_user_id),
  UNIQUE KEY uq_user_provider (user_id, provider),
  KEY idx_identities_user_id (user_id),
  CONSTRAINT fk_identities_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS merchant_profiles (
  user_id BIGINT UNSIGNED NOT NULL,
  business_name VARCHAR(255) NULL,
  business_type VARCHAR(100) NULL,
  registration_number VARCHAR(100) NULL,
  categories_json JSON NULL,
  facility_type VARCHAR(50) NULL,
  address VARCHAR(500) NULL,
  contact_email VARCHAR(255) NULL,
  owner_designation VARCHAR(150) NULL,
  business_image LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_merchant_profiles_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE merchant_profiles
  ADD COLUMN IF NOT EXISTS business_image LONGTEXT NULL;

ALTER TABLE users
  MODIFY COLUMN avatar_url LONGTEXT NULL;

CREATE TABLE IF NOT EXISTS merchant_businesses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  merchant_id BIGINT UNSIGNED NOT NULL,
  business_type VARCHAR(50) NOT NULL,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(100) NOT NULL,
  address VARCHAR(500) NOT NULL,
  facility_type VARCHAR(50) NOT NULL,
  price_per_hour DECIMAL(10, 2) NOT NULL,
  opening_hours VARCHAR(100) NOT NULL,
  availability VARCHAR(50) NOT NULL DEFAULT 'Any',
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  amenities_json JSON NULL,
  details VARCHAR(1000) NULL,
  image_url LONGTEXT NULL,
  image_urls JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_merchant_businesses_merchant (merchant_id, created_at),
  KEY idx_merchant_businesses_type_enabled (business_type, enabled),
  CONSTRAINT fk_merchant_businesses_user
    FOREIGN KEY (merchant_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE merchant_businesses
  ADD COLUMN IF NOT EXISTS price_per_hour DECIMAL(10, 2) NOT NULL DEFAULT 0
  AFTER facility_type;

ALTER TABLE merchant_businesses
  ADD COLUMN IF NOT EXISTS image_urls JSON NULL
  AFTER image_url;

ALTER TABLE merchant_businesses
  ADD COLUMN IF NOT EXISTS enabled TINYINT(1) NOT NULL DEFAULT 1
  AFTER availability;

ALTER TABLE merchant_businesses
  ADD COLUMN IF NOT EXISTS opening_hours VARCHAR(100) NOT NULL DEFAULT 'Open hours'
  AFTER price_per_hour,
  ADD COLUMN IF NOT EXISTS availability VARCHAR(50) NOT NULL DEFAULT 'Any'
  AFTER opening_hours,
  ADD COLUMN IF NOT EXISTS amenities_json JSON NULL
  AFTER availability;

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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS event_business_details (
  business_id BIGINT UNSIGNED NOT NULL,
  event_name VARCHAR(255) NULL,
  event_type VARCHAR(100) NULL,
  event_date DATE NULL,
  start_time TIME NULL,
  end_time TIME NULL,
  setup_hours DECIMAL(5, 2) NULL,
  teardown_hours DECIMAL(5, 2) NULL,
  estimated_attendance INT UNSIGNED NULL,
  accessibility_needs TEXT NULL,
  parking_security TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id),
  CONSTRAINT fk_event_business_details_business
    FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fitness_business_details (
  business_id BIGINT UNSIGNED NOT NULL,
  class_capacity INT UNSIGNED NULL,
  session_duration_minutes INT UNSIGNED NULL,
  instructor_name VARCHAR(255) NULL,
  class_schedule TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id),
  CONSTRAINT fk_fitness_business_details_business
    FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE email_verification_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_verification_token (token_hash),
  KEY idx_email_verification_user (user_id),
  KEY idx_email_verification_expiry (expires_at),
  CONSTRAINT fk_email_verification_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE password_reset_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_password_reset_token (token_hash),
  KEY idx_password_reset_user (user_id),
  KEY idx_password_reset_expiry (expires_at),
  CONSTRAINT fk_password_reset_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE user_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  session_token_hash CHAR(64) NOT NULL,
  ip_address VARBINARY(16) NULL,
  user_agent VARCHAR(512) NULL,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_token (session_token_hash),
  KEY idx_sessions_user (user_id),
  KEY idx_sessions_expiry (expires_at),
  CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE saved_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  item_type ENUM('sports', 'event', 'fitness') NOT NULL,
  item_key VARCHAR(255) NOT NULL,
  title VARCHAR(255) NOT NULL,
  subtitle VARCHAR(255) NULL,
  image_url VARCHAR(2048) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_saved_item_user (user_id, item_type, item_key),
  KEY idx_saved_items_user_created (user_id, created_at),
  CONSTRAINT fk_saved_items_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;
