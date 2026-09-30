import { int, mysqlEnum, mysqlTable, text, timestamp, varchar } from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export const products = mysqlTable("products", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 160 }).notNull(),
  sku: varchar("sku", { length: 80 }).notNull().unique(),
  category: varchar("category", { length: 100 }).notNull(),
  stock: int("stock").default(0).notNull(),
  minimumStock: int("minimumStock").default(0).notNull(),
  status: mysqlEnum("status", ["active", "paused"]).default("active").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export const stockMovements = mysqlTable("stockMovements", {
  id: int("id").autoincrement().primaryKey(),
  productId: int("productId").notNull(),
  change: int("change").notNull(),
  stockAfter: int("stockAfter").notNull(),
  reason: varchar("reason", { length: 255 }).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const inventoryAlerts = mysqlTable("inventoryAlerts", {
  id: int("id").autoincrement().primaryKey(),
  productId: int("productId").notNull(),
  severity: mysqlEnum("severity", ["critical", "warning"]).default("critical").notNull(),
  status: mysqlEnum("status", ["open", "sent", "failed", "resolved"]).default("open").notNull(),
  message: text("message").notNull(),
  sentAt: timestamp("sentAt"),
  resolvedAt: timestamp("resolvedAt"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const notificationSettings = mysqlTable("notificationSettings", {
  id: int("id").autoincrement().primaryKey(),
  botToken: text("botToken"),
  chatId: varchar("chatId", { length: 100 }),
  enabled: int("enabled").default(0).notNull(),
  frequencyMinutes: int("frequencyMinutes").default(5).notNull(),
  scheduleTaskUid: varchar("scheduleTaskUid", { length: 128 }),
  lastCheckAt: timestamp("lastCheckAt"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
export type Product = typeof products.$inferSelect;
export type InsertProduct = typeof products.$inferInsert;
export type StockMovement = typeof stockMovements.$inferSelect;
export type InventoryAlert = typeof inventoryAlerts.$inferSelect;
export type NotificationSettings = typeof notificationSettings.$inferSelect;
