alter table private.demo_persona_bundle enable row level security;
alter table private.demo_persona_lease enable row level security;

revoke all on table private.demo_persona_bundle from public, anon, authenticated;
revoke all on table private.demo_persona_lease from public, anon, authenticated;
