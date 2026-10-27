import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createClient } from "../../packages/database/node_modules/@supabase/supabase-js/dist/index.mjs";

function loadEnvironmentFile(path) {
  if (!existsSync(path)) return;

  for (const line of readFileSync(path, "utf8").split(/\r?\n/u)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*['"]?([^'"#]+)['"]?\s*$/u);
    if (match && process.env[match[1]] === undefined) process.env[match[1]] = match[2].trim();
  }
}

function requireEnvironment(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

async function main() {
  loadEnvironmentFile(resolve(".env.local"));
  loadEnvironmentFile(resolve("apps/weightroom/.env.local"));

  if (process.env.GYMU_DEMO_MODE !== "enabled") {
    throw new Error("GYMU_DEMO_MODE=enabled is required for cleanup.");
  }
  if (process.env.GYMU_DEMO_CLEANUP_CONFIRM !== "remove-demo-personas") {
    throw new Error("Set GYMU_DEMO_CLEANUP_CONFIRM=remove-demo-personas to continue.");
  }

  const supabase = createClient(
    requireEnvironment("NEXT_PUBLIC_SUPABASE_URL"),
    requireEnvironment("SUPABASE_SECRET_KEY"),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  const { data: users, error: usersError } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (usersError) throw usersError;

  const demoUsers = users.users.filter((user) =>
    /^demo-\d{2}-(student|u_staff|gym_staff)@auth\.gymu\.invalid$/u.test(user.email ?? ""),
  );
  const { error: resetError } = await supabase.rpc("reset_demo_personas");
  if (resetError) throw resetError;

  for (const user of demoUsers) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) throw error;
  }

  console.log(`Removed ${demoUsers.length} demonstration identities.`);
}

main().catch((error) => {
  console.error("Could not remove demonstration users.", error);
  process.exitCode = 1;
});
