BEGIN;

INSERT INTO settings (key, value)
VALUES
  ('app.site_name', to_jsonb('MYA-L11 Mail'::text)),
  ('app.root_url', to_jsonb('http://100.106.212.28:9000'::text)),
  ('app.from_email', to_jsonb('MYA-L11 <noreply@redmono.test>'::text)),
  ('app.message_rate', to_jsonb(2)),
  ('app.send_optin_confirmation', to_jsonb(true)),
  ('privacy.unsubscribe_header', to_jsonb(true)),
  ('privacy.individual_tracking', to_jsonb(false)),
  ('smtp', '[{"host":"mailpit","name":"test-mailpit","port":1025,"uuid":"","enabled":true,"password":"","tls_type":"none","username":"","max_conns":2,"idle_timeout":"15s","wait_timeout":"5s","auth_protocol":"none","email_headers":{},"from_addresses":[],"hello_hostname":"mya-l11.redmono.test","max_msg_retries":2,"msg_retry_delay":"1s","tls_skip_verify":false}]'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

COMMIT;
