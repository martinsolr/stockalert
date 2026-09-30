import { z } from "zod";
import { getSessionCookieOptions } from "./_core/cookies";
import { COOKIE_NAME } from "@shared/const";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, router } from "./_core/trpc";
import {
  adjustStock,
  checkStockAndNotify,
  createProduct,
  deleteProduct,
  getDashboardData,
  getNotificationSettings,
  listMovements,
  listProducts,
  saveNotificationSettings,
  updateProduct,
} from "./inventory";
import { testTelegramConnection } from "./telegram";

const productBase = z.object({
  name: z.string().trim().min(2).max(160),
  sku: z.string().trim().min(2).max(80),
  category: z.string().trim().min(2).max(100),
  stock: z.number().int().min(0).max(1_000_000),
  minimumStock: z.number().int().min(0).max(1_000_000),
  status: z.enum(["active", "paused"]),
});

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query(opts => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return { success: true } as const;
    }),
  }),
  dashboard: router({
    summary: publicProcedure.query(() => getDashboardData()),
  }),
  products: router({
    list: publicProcedure.query(() => listProducts()),
    create: publicProcedure.input(productBase).mutation(({ input }) => createProduct(input)),
    update: publicProcedure.input(z.object({ id: z.number().int().positive(), data: productBase.partial() })).mutation(({ input }) => updateProduct(input.id, input.data)),
    remove: publicProcedure.input(z.object({ id: z.number().int().positive() })).mutation(({ input }) => deleteProduct(input.id)),
    adjust: publicProcedure.input(z.object({ id: z.number().int().positive(), change: z.number().int().min(-1_000_000).max(1_000_000), reason: z.string().trim().min(2).max(255) })).mutation(({ input }) => adjustStock(input.id, input.change, input.reason)),
  }),
  movements: router({
    list: publicProcedure.input(z.object({ productId: z.number().int().positive().optional() }).optional()).query(({ input }) => listMovements(input?.productId)),
  }),
  alerts: router({
    check: publicProcedure.mutation(() => checkStockAndNotify()),
  }),
  settings: router({
    get: publicProcedure.query(() => getNotificationSettings()),
    save: publicProcedure.input(z.object({ botToken: z.string().trim().max(256).optional(), chatId: z.string().trim().max(100), enabled: z.boolean(), frequencyMinutes: z.number().int().min(1).max(1440) })).mutation(({ input }) => saveNotificationSettings(input)),
    test: publicProcedure.input(z.object({ botToken: z.string().trim().max(256).optional(), chatId: z.string().trim().min(1).max(100) })).mutation(async ({ input }) => {
      if (!input.botToken) throw new Error("Informe o token do bot para testar a conexão.");
      return testTelegramConnection(input.botToken, input.chatId);
    }),
  }),
});

export type AppRouter = typeof appRouter;
