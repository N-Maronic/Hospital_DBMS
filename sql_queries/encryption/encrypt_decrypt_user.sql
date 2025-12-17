-- ================================
-- STEP 0: SESSION SETUP
-- ================================
SET app.encryption_key = 'secret-demo-key-123';
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ================================
-- STEP 1: ENCRYPT USER TABLE
-- ================================
ALTER TABLE public."user"
  ALTER COLUMN id_number TYPE bytea
    USING pgp_sym_encrypt(id_number, current_setting('app.encryption_key')),
  ALTER COLUMN phone_number TYPE bytea
    USING pgp_sym_encrypt(phone_number, current_setting('app.encryption_key')),
  ALTER COLUMN address TYPE bytea
    USING pgp_sym_encrypt(address, current_setting('app.encryption_key')),
  ALTER COLUMN email TYPE bytea
    USING pgp_sym_encrypt(email, current_setting('app.encryption_key'));

-- ================================
-- STEP 2: SHOW ENCRYPTED DATA
-- ================================
SELECT
  id,
  id_number,
  phone_number,
  address,
  email
FROM public."user"
LIMIT 5;

-- ================================
-- STEP 3: DECRYPT USER TABLE
-- ================================
ALTER TABLE public."user"
  ALTER COLUMN id_number TYPE text
    USING pgp_sym_decrypt(id_number, current_setting('app.encryption_key'))::text,
  ALTER COLUMN phone_number TYPE text
    USING pgp_sym_decrypt(phone_number, current_setting('app.encryption_key'))::text,
  ALTER COLUMN address TYPE text
    USING pgp_sym_decrypt(address, current_setting('app.encryption_key'))::text,
  ALTER COLUMN email TYPE text
    USING pgp_sym_decrypt(email, current_setting('app.encryption_key'))::text;

-- ================================
-- STEP 4: SHOW DECRYPTED DATA
-- ================================
SELECT
  id,
  id_number,
  phone_number,
  address,
  email
FROM public."user"
LIMIT 5;
