import { createHmac } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createClient } from "../../packages/database/node_modules/@supabase/supabase-js/dist/index.mjs";

const DEMO_BUNDLES = [
  ["Camila Rojas", "Tomás Álvarez", "Paula Mella"],
  ["Matías Soto", "Daniela Vera", "Rodrigo Fuentes"],
  ["Antonia Pérez", "Javier Silva", "Carolina Torres"],
  ["Diego Morales", "Valentina Araya", "Felipe López"],
  ["Francisca Castillo", "Nicolás Reyes", "Andrea Muñoz"],
  ["Benjamín Navarro", "Constanza Díaz", "Marcelo Pino"],
  ["Javiera Contreras", "Sebastián Rivas", "Patricia Soto"],
  ["Ignacio Herrera", "María Paz Correa", "Cristóbal Leiva"],
];

const REPORTED_SEXES = ["femenino", "masculino", "otro", "prefiero_no_decir"];

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

function getDemoEmail(bundleIndex, role) {
  return `demo-${String(bundleIndex + 1).padStart(2, "0")}-${role}@auth.gymu.invalid`;
}

function getInstitutionalUsername(bundleIndex, role) {
  return `demo.${String(bundleIndex + 1).padStart(2, "0")}.${role.replace("_", "-")}`;
}

function getIdentityHmac(identityHmacKey, username) {
  return createHmac("sha256", identityHmacKey).update(`gymu-demo:${username}`).digest("hex");
}

async function getOrCreateUser(supabase, email) {
  const { data: existingUsers, error: existingUsersError } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (existingUsersError) throw existingUsersError;

  const existingUser = existingUsers.users.find((user) => user.email === email);
  if (existingUser) return existingUser.id;

  const { data, error } = await supabase.auth.admin.createUser({ email, email_confirm: true });
  if (error || !data.user) throw error ?? new Error(`Could not create ${email}.`);
  return data.user.id;
}

async function main() {
  loadEnvironmentFile(resolve(".env.local"));
  loadEnvironmentFile(resolve("apps/weightroom/.env.local"));

  if (process.env.GYMU_DEMO_MODE !== "enabled") {
    throw new Error("GYMU_DEMO_MODE=enabled is required to seed demonstration users.");
  }

  const supabaseUrl = requireEnvironment("NEXT_PUBLIC_SUPABASE_URL");
  const secretKey = requireEnvironment("SUPABASE_SECRET_KEY");
  const identityHmacKey = requireEnvironment("GUSM_IDENTITY_HMAC_KEY");
  const supabase = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const roles = ["student", "u_staff", "gym_staff"];
  const people = [];

  for (const [bundleIndex, names] of DEMO_BUNDLES.entries()) {
    for (const [roleIndex, role] of roles.entries()) {
      const institutionalUsername = getInstitutionalUsername(bundleIndex, role);
      const userId = await getOrCreateUser(supabase, getDemoEmail(bundleIndex, role));
      people.push({
        bundleKey: `demo-${String(bundleIndex + 1).padStart(2, "0")}`,
        userId,
        role,
        userName: names[roleIndex],
        institutionalUsername,
        identityHmac: getIdentityHmac(identityHmacKey, institutionalUsername),
        themePreference: bundleIndex % 2 === 0 ? "dark" : "light",
        dateOfBirth: `${1997 + (bundleIndex % 7)}-${String((bundleIndex % 11) + 1).padStart(2, "0")}-15`,
        reportedSex: REPORTED_SEXES[bundleIndex % REPORTED_SEXES.length],
        heightCm: 158 + bundleIndex * 3,
        weightKg: 54 + bundleIndex * 5,
        careerEntryYear: 2017 + (bundleIndex % 9),
        programOffset: bundleIndex + roleIndex,
      });
    }
  }

  const { error } = await supabase.rpc("seed_demo_personas_v3", { p_people: people });
  if (error) throw error;

  const { error: enrichmentError } = await supabase.rpc("enrich_demo_persona_history");
  if (enrichmentError) throw enrichmentError;

  const { error: currentBlockError } = await supabase.rpc("seed_demo_current_block_context");
  if (currentBlockError) throw currentBlockError;

  console.log(`Seeded ${DEMO_BUNDLES.length} isolated demonstration groups.`);
}

main().catch((error) => {
  console.error("Could not seed demonstration users.", error);
  process.exitCode = 1;
});
