-- Set passwords for internal Supabase roles
-- Mounted at /docker-entrypoint-initdb.d/init-scripts/99-roles.sql
-- \set reads the env var via shell backtick

\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';

-- Create _realtime schema needed by Supabase Realtime service
CREATE SCHEMA IF NOT EXISTS _realtime;
ALTER SCHEMA _realtime OWNER TO supabase_admin;
