import { DatabaseSync } from "node:sqlite";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
const sqlite = new DatabaseSync(":memory:");
class Stmt {
  sql: string; args: any[];
  constructor(sql: string, args: any[] = []) { this.sql = sql; this.args = args; }
  bind(...a: any[]) { return new Stmt(this.sql, a); }
  async first<T = any>() { const r = sqlite.prepare(this.sql).get(...this.args); return (r ?? null) as T | null; }
  async all<T = any>() { return { results: sqlite.prepare(this.sql).all(...this.args) as T[] }; }
  async run() { const r = sqlite.prepare(this.sql).run(...this.args); return { meta: { changes: Number(r.changes) } }; }
}
const DB = { prepare: (sql: string) => new Stmt(sql) };
for (const parte of readFileSync(new URL("./tablas.sql", import.meta.url), "utf8").split(";")) { if (parte.trim()) sqlite.exec(parte); }
// tablas del servidor que usa la parte nueva
sqlite.exec("CREATE TABLE devices (id TEXT PRIMARY KEY, name TEXT, owner_email TEXT, platform TEXT, battery REAL, last_seen_at TEXT, last_location_json TEXT, last_location_at TEXT, push_token TEXT, approval_status TEXT, device_role TEXT)");
sqlite.exec("CREATE TABLE family_places (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL, created_at TEXT NOT NULL)");
sqlite.exec("CREATE TABLE family_members (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, member_email TEXT NOT NULL, name TEXT, owner_name TEXT, role TEXT, status TEXT)");
sqlite.exec("CREATE TABLE location_history (id TEXT PRIMARY KEY, device_id TEXT, latitude REAL, longitude REAL, accuracy REAL, altitude REAL, heading REAL, address TEXT, captured_at TEXT, created_at TEXT)");
const env: any = { DB, SESSION_SECRET: "x", PASSKEY_ORIGIN: "https://panel.test", RESEND_API_KEY: "re_test", MAIL_FROM: "Ojo Guard <a@b.c>", SUPPORT_EMAIL: "s@b.c" };
const correos: Array<{ to: string; subject: string; html: string }> = [];
const avisos: Array<{ token: string | null; title: string; body: string }> = [];
const pings: any[] = [];
let sesionActual: any = { email: "lucas@correo.com", method: "passkey" };
const now = () => new Date().toISOString();
const minutesBetween = (iso: string | null, nowMs: number) => (iso ? (nowMs - Date.parse(iso)) / 60000 : null);
const normalizeEmail = (e: string) => String(e).trim().toLowerCase();
const escapeHtml = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
const json = (d: unknown, status = 200) => new Response(JSON.stringify(d), { status, headers: { "content-type": "application/json" } });
const hash = async (v: string) => createHash("sha256").update(v).digest("hex");
let correoOk = true;
function setCorreoOk(v: boolean) { correoOk = v; }
const fetchCorreo = async (_u: string, init: any) => { if (!correoOk) return new Response("fallo", { status: 500 }); const b = JSON.parse(init.body); correos.push({ to: b.to[0], subject: b.subject, html: b.html }); return new Response("{}", { status: 200 }); };
const sendExpoNotice = async (token: string | null, title: string, body: string, _o?: any) => { avisos.push({ token, title, body }); return true; };
const queueAutoLocateCommand = async (_e: any, d: any) => { pings.push(d); };
const readSessionInfo = async (_r: Request, _s: string) => sesionActual;
function setSesion(s: any) { sesionActual = s; }
function pedido(url: string, metodo: string, cuerpo?: unknown) { return new Request(url, { method: metodo, headers: { "content-type": "application/json" }, body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo) }); }
