-- ================================================================
-- LCNC Lab - PostgreSQL Initialization
-- Creates a separate database for every service
-- Runs automatically on first postgres container start
-- ================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Dedicated database per service
CREATE DATABASE nocodb;
CREATE DATABASE n8ndb;
CREATE DATABASE formbricksdb;
CREATE DATABASE metabasedb;
CREATE DATABASE flowisedb;

-- Grant full access to lcncadmin on every database
GRANT ALL PRIVILEGES ON DATABASE nocodb TO lcncadmin;
GRANT ALL PRIVILEGES ON DATABASE n8ndb TO lcncadmin;
GRANT ALL PRIVILEGES ON DATABASE formbricksdb TO lcncadmin;
GRANT ALL PRIVILEGES ON DATABASE metabasedb TO lcncadmin;
GRANT ALL PRIVILEGES ON DATABASE flowisedb TO lcncadmin;
