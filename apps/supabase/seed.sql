-- Seed data for local development
-- Add test data here. Runs after migrations via `supabase db reset`.

-- Demo account: demo@example.com / demo1234
DO $$
DECLARE
  demo_uid uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    confirmation_token, recovery_token, reauthentication_token,
    email_change, email_change_token_new, email_change_token_current,
    email_change_confirm_status,
    phone, phone_change, phone_change_token,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, is_sso_user, is_anonymous
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    demo_uid,
    'authenticated',
    'authenticated',
    'demo@example.com',
    crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '', '', '',
    '', '', '',
    0,
    '', '', '',
    '{"provider":"email","providers":["email"]}',
    '{"name":"Demo User"}',
    false, false, false
  );

  INSERT INTO auth.identities (
    id, user_id, provider_id, provider, identity_data,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    demo_uid, demo_uid, demo_uid, 'email',
    jsonb_build_object('sub', demo_uid, 'email', 'demo@example.com'),
    now(), now(), now()
  );
END $$;
