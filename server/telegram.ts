export type TelegramResult = {
  ok: boolean;
  description?: string;
};

const telegramUrl = (token: string, method: string) =>
  `https://api.telegram.org/bot${token}/${method}`;

async function callTelegram<T>(token: string, method: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(telegramUrl(token, method), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

  const payload = (await response.json().catch(() => ({}))) as TelegramResult & { result?: T };
  if (!response.ok || !payload.ok) {
    throw new Error(payload.description || `Telegram API error (${response.status})`);
  }
  return payload.result as T;
}

export async function sendTelegramMessage(token: string, chatId: string, text: string) {
  return callTelegram(token, "sendMessage", {
    chat_id: chatId,
    text,
    disable_web_page_preview: true,
  });
}

export async function testTelegramConnection(token: string, chatId: string) {
  await sendTelegramMessage(
    token,
    chatId,
    "✅ StockAlert conectado. Você receberá aqui os avisos de estoque crítico."
  );
  return { ok: true };
}

export function maskTelegramToken(token: string | null | undefined) {
  if (!token) return null;
  if (token.length <= 8) return "••••••••";
  return `${token.slice(0, 4)}••••••••${token.slice(-4)}`;
}
