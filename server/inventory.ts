import { and, asc, count, desc, eq, isNull, lte } from "drizzle-orm";
import type { Product } from "../drizzle/schema";
import { inventoryAlerts, notificationSettings, products, stockMovements } from "../drizzle/schema";
import { getDb } from "./db";
import { maskTelegramToken, sendTelegramMessage } from "./telegram";

const DEMO_PRODUCTS = [
  { name: "Café especial 250g", sku: "CAF-250", category: "Mercearia", stock: 6, minimumStock: 10, status: "active" as const },
  { name: "Leite integral 1L", sku: "LEI-1L", category: "Laticínios", stock: 24, minimumStock: 12, status: "active" as const },
  { name: "Biscoito de aveia", sku: "BIS-AVE", category: "Mercearia", stock: 8, minimumStock: 8, status: "active" as const },
  { name: "Sabonete líquido 300ml", sku: "SAB-300", category: "Higiene", stock: 42, minimumStock: 15, status: "active" as const },
  { name: "Água mineral 500ml", sku: "AGU-500", category: "Bebidas", stock: 0, minimumStock: 20, status: "active" as const },
];

const memoryProducts: Product[] = [];
const memoryMovements: Array<{ id: number; productId: number; change: number; stockAfter: number; reason: string; createdAt: Date }> = [];
const memoryAlerts: Array<{ id: number; productId: number; severity: "critical" | "warning"; status: "open" | "sent" | "failed" | "resolved"; message: string; sentAt: Date | null; resolvedAt: Date | null; createdAt: Date }> = [];
let memorySettings = {
  id: 1,
  botToken: null as string | null,
  chatId: null as string | null,
  enabled: 0,
  frequencyMinutes: 5,
  scheduleTaskUid: null as string | null,
  lastCheckAt: null as Date | null,
  createdAt: new Date(),
  updatedAt: new Date(),
};
let nextMemoryId = 1;

export type PublicSettings = {
  enabled: boolean;
  frequencyMinutes: number;
  chatId: string | null;
  tokenConfigured: boolean;
  maskedToken: string | null;
  lastCheckAt: string | null;
};

export type DashboardData = {
  products: Product[];
  alerts: Array<{
    id: number;
    productId: number;
    productName: string;
    sku: string;
    stock: number;
    minimumStock: number;
    status: string;
    severity: string;
    alertStatus: string;
    message: string;
    createdAt: string;
  }>;
  stats: {
    totalProducts: number;
    criticalProducts: number;
    outOfStock: number;
    healthyProducts: number;
  };
  settings: PublicSettings;
};

function asPublicSettings(settings: typeof memorySettings | typeof notificationSettings.$inferSelect | null): PublicSettings {
  if (!settings) {
    return { enabled: false, frequencyMinutes: 5, chatId: null, tokenConfigured: false, maskedToken: null, lastCheckAt: null };
  }
  return {
    enabled: settings.enabled === 1,
    frequencyMinutes: settings.frequencyMinutes,
    chatId: settings.chatId ?? null,
    tokenConfigured: Boolean(settings.botToken),
    maskedToken: maskTelegramToken(settings.botToken),
    lastCheckAt: settings.lastCheckAt?.toISOString() ?? null,
  };
}

async function seedIfEmpty() {
  const db = await getDb();
  if (!db) {
    if (memoryProducts.length === 0) {
      for (const product of DEMO_PRODUCTS) memoryProducts.push({ id: nextMemoryId++, ...product, createdAt: new Date(), updatedAt: new Date() });
    }
    return;
  }
  const [{ total }] = await db.select({ total: count() }).from(products);
  if (Number(total) === 0) {
    await db.insert(products).values(DEMO_PRODUCTS);
  }
}

export async function listProducts() {
  await seedIfEmpty();
  const db = await getDb();
  if (!db) return [...memoryProducts].sort((a, b) => a.stock - a.minimumStock - (b.stock - b.minimumStock));
  return db.select().from(products).orderBy(asc(products.name));
}

export async function createProduct(input: { name: string; sku: string; category: string; stock: number; minimumStock: number; status: "active" | "paused" }) {
  const db = await getDb();
  if (!db) {
    const now = new Date();
    const product = { id: nextMemoryId++, ...input, createdAt: now, updatedAt: now } as Product;
    memoryProducts.push(product);
    return product;
  }
  await db.insert(products).values(input);
  const [created] = await db.select().from(products).where(eq(products.sku, input.sku)).limit(1);
  return created;
}

export async function updateProduct(id: number, input: Partial<{ name: string; sku: string; category: string; stock: number; minimumStock: number; status: "active" | "paused" }>) {
  const db = await getDb();
  if (!db) {
    const product = memoryProducts.find(item => item.id === id);
    if (!product) throw new Error("Produto não encontrado");
    Object.assign(product, input, { updatedAt: new Date() });
    return product;
  }
  await db.update(products).set({ ...input, updatedAt: new Date() }).where(eq(products.id, id));
  const [updated] = await db.select().from(products).where(eq(products.id, id)).limit(1);
  return updated;
}

export async function deleteProduct(id: number) {
  const db = await getDb();
  if (!db) {
    const index = memoryProducts.findIndex(item => item.id === id);
    if (index < 0) throw new Error("Produto não encontrado");
    memoryProducts.splice(index, 1);
    for (let i = memoryMovements.length - 1; i >= 0; i--) if (memoryMovements[i].productId === id) memoryMovements.splice(i, 1);
    for (let i = memoryAlerts.length - 1; i >= 0; i--) if (memoryAlerts[i].productId === id) memoryAlerts.splice(i, 1);
    return { success: true };
  }
  await db.delete(stockMovements).where(eq(stockMovements.productId, id));
  await db.delete(inventoryAlerts).where(eq(inventoryAlerts.productId, id));
  await db.delete(products).where(eq(products.id, id));
  return { success: true };
}

export async function adjustStock(id: number, change: number, reason: string) {
  const current = (await listProducts()).find(item => item.id === id);
  if (!current) throw new Error("Produto não encontrado");
  const previousStock = current.stock;
  const nextStock = Math.max(0, previousStock + change);
  const db = await getDb();
  if (!db) {
    current.stock = nextStock;
    current.updatedAt = new Date();
    memoryMovements.unshift({ id: nextMemoryId++, productId: id, change: nextStock - previousStock, stockAfter: nextStock, reason, createdAt: new Date() });
  } else {
    await db.update(products).set({ stock: nextStock, updatedAt: new Date() }).where(eq(products.id, id));
    await db.insert(stockMovements).values({ productId: id, change: nextStock - previousStock, stockAfter: nextStock, reason });
  }
  if (nextStock > current.minimumStock) await resolveAlerts(id);
  else await createOpenAlertIfNeeded({ ...current, stock: nextStock });
  return (await listProducts()).find(item => item.id === id);
}

async function openAlertForProduct(product: { id: number; name: string; sku: string; stock: number; minimumStock: number }) {
  const message = product.stock === 0
    ? `🚨 Sem estoque: ${product.name} (${product.sku}). Reposição necessária agora.`
    : `⚠️ Estoque baixo: ${product.name} (${product.sku}) está com ${product.stock} unidade(s). Mínimo: ${product.minimumStock}.`;
  const db = await getDb();
  if (!db) {
    const created = { id: nextMemoryId++, productId: product.id, severity: "critical" as const, status: "open" as const, message, sentAt: null, resolvedAt: null, createdAt: new Date() };
    memoryAlerts.unshift(created);
    return created;
  }
  await db.insert(inventoryAlerts).values({ productId: product.id, severity: "critical", status: "open", message });
  const [created] = await db.select().from(inventoryAlerts).where(and(eq(inventoryAlerts.productId, product.id), isNull(inventoryAlerts.resolvedAt))).orderBy(desc(inventoryAlerts.createdAt)).limit(1);
  return created;
}

async function getOpenAlert(productId: number) {
  const db = await getDb();
  if (!db) return memoryAlerts.find(alert => alert.productId === productId && !alert.resolvedAt);
  const [alert] = await db.select().from(inventoryAlerts).where(and(eq(inventoryAlerts.productId, productId), isNull(inventoryAlerts.resolvedAt))).orderBy(desc(inventoryAlerts.createdAt)).limit(1);
  return alert;
}

async function createOpenAlertIfNeeded(product: { id: number; name: string; sku: string; stock: number; minimumStock: number }) {
  if (!(await getOpenAlert(product.id))) await openAlertForProduct(product);
}

export async function resolveAlerts(productId: number) {
  const now = new Date();
  const db = await getDb();
  if (!db) {
    for (const alert of memoryAlerts) if (alert.productId === productId && !alert.resolvedAt) { alert.resolvedAt = now; alert.status = "resolved"; }
    return;
  }
  await db.update(inventoryAlerts).set({ resolvedAt: now, status: "resolved" }).where(and(eq(inventoryAlerts.productId, productId), isNull(inventoryAlerts.resolvedAt)));
}

async function getSettingsRecord() {
  const db = await getDb();
  if (!db) return memorySettings;
  const [settings] = await db.select().from(notificationSettings).orderBy(asc(notificationSettings.id)).limit(1);
  return settings ?? null;
}

export async function getNotificationSettings() {
  return asPublicSettings(await getSettingsRecord());
}

export async function saveNotificationSettings(input: { botToken?: string; chatId: string; enabled: boolean; frequencyMinutes: number }) {
  const current = await getSettingsRecord();
  const values = {
    botToken: input.botToken?.trim() || current?.botToken || null,
    chatId: input.chatId.trim() || null,
    enabled: input.enabled ? 1 : 0,
    frequencyMinutes: input.frequencyMinutes,
    updatedAt: new Date(),
  };
  const db = await getDb();
  if (!db) {
    memorySettings = { ...memorySettings, ...values };
    return asPublicSettings(memorySettings);
  }
  if (current) await db.update(notificationSettings).set(values).where(eq(notificationSettings.id, current.id));
  else await db.insert(notificationSettings).values({ id: 1, ...values });
  return getNotificationSettings();
}

export async function markScheduleIdentity(taskUid: string) {
  const current = await getSettingsRecord();
  const db = await getDb();
  if (!current) return;
  if (!current.scheduleTaskUid) {
    if (!db) memorySettings.scheduleTaskUid = taskUid;
    else await db.update(notificationSettings).set({ scheduleTaskUid: taskUid }).where(eq(notificationSettings.id, current.id));
  }
}

export async function checkStockAndNotify() {
  const currentProducts = (await listProducts()).filter(product => product.status === "active");
  const settings = await getSettingsRecord();
  let created = 0;
  let sent = 0;
  let resolved = 0;
  let failed = 0;

  for (const product of currentProducts) {
    if (product.stock <= product.minimumStock) {
      const existing = await getOpenAlert(product.id);
      const alert = existing ?? await openAlertForProduct(product);
      if (!existing) created += 1;
      if (!existing && settings?.enabled === 1 && settings.botToken && settings.chatId) {
        try {
          await sendTelegramMessage(settings.botToken, settings.chatId, alert.message);
          const db = await getDb();
          if (!db) { const item = memoryAlerts.find(row => row.id === alert.id); if (item) { item.status = "sent"; item.sentAt = new Date(); } }
          else await db.update(inventoryAlerts).set({ status: "sent", sentAt: new Date() }).where(eq(inventoryAlerts.id, alert.id));
          sent += 1;
        } catch (error) {
          const db = await getDb();
          if (!db) { const item = memoryAlerts.find(row => row.id === alert.id); if (item) item.status = "failed"; }
          else await db.update(inventoryAlerts).set({ status: "failed" }).where(eq(inventoryAlerts.id, alert.id));
          failed += 1;
          console.error("[Telegram] Failed to send alert", error);
        }
      }
    } else {
      const open = await getOpenAlert(product.id);
      if (open) { await resolveAlerts(product.id); resolved += 1; }
    }
  }

  const now = new Date();
  const db = await getDb();
  if (!db) memorySettings.lastCheckAt = now;
  else if (settings) await db.update(notificationSettings).set({ lastCheckAt: now }).where(eq(notificationSettings.id, settings.id));
  return { checked: currentProducts.length, created, sent, resolved, failed, checkedAt: now.toISOString() };
}

export async function listRecentAlerts(limit = 8) {
  const db = await getDb();
  if (!db) {
    return memoryAlerts.filter(alert => !alert.resolvedAt).slice(0, limit).map(alert => {
      const product = memoryProducts.find(item => item.id === alert.productId);
      return { ...alert, productName: product?.name ?? "Produto removido", sku: product?.sku ?? "—", stock: product?.stock ?? 0, minimumStock: product?.minimumStock ?? 0, createdAt: alert.createdAt.toISOString() };
    });
  }
  const rows = await db.select({ alert: inventoryAlerts, product: products }).from(inventoryAlerts).leftJoin(products, eq(inventoryAlerts.productId, products.id)).where(isNull(inventoryAlerts.resolvedAt)).orderBy(desc(inventoryAlerts.createdAt)).limit(limit);
  return rows.map(({ alert, product }) => ({ ...alert, productName: product?.name ?? "Produto removido", sku: product?.sku ?? "—", stock: product?.stock ?? 0, minimumStock: product?.minimumStock ?? 0, createdAt: alert.createdAt.toISOString() }));
}

export async function getDashboardData(): Promise<DashboardData> {
  const currentProducts = await listProducts();
  const alerts = await listRecentAlerts();
  const criticalProducts = currentProducts.filter(product => product.status === "active" && product.stock <= product.minimumStock).length;
  const outOfStock = currentProducts.filter(product => product.stock === 0).length;
  return {
    products: currentProducts,
    alerts: alerts.map(alert => ({ ...alert, status: alert.status, alertStatus: alert.status, severity: alert.severity })),
    stats: { totalProducts: currentProducts.length, criticalProducts, outOfStock, healthyProducts: currentProducts.length - criticalProducts },
    settings: await getNotificationSettings(),
  };
}

export async function listMovements(productId?: number) {
  const db = await getDb();
  if (!db) {
    return memoryMovements.filter(item => productId ? item.productId === productId : true).slice(0, 50);
  }
  return db.select().from(stockMovements).where(productId ? eq(stockMovements.productId, productId) : undefined).orderBy(desc(stockMovements.createdAt)).limit(50);
}
