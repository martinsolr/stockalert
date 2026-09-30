import { relations } from "drizzle-orm";
import { inventoryAlerts, products, stockMovements } from "./schema";

export const productsRelations = relations(products, ({ many }) => ({
  movements: many(stockMovements),
  alerts: many(inventoryAlerts),
}));

export const stockMovementsRelations = relations(stockMovements, ({ one }) => ({
  product: one(products, {
    fields: [stockMovements.productId],
    references: [products.id],
  }),
}));

export const inventoryAlertsRelations = relations(inventoryAlerts, ({ one }) => ({
  product: one(products, {
    fields: [inventoryAlerts.productId],
    references: [products.id],
  }),
}));
