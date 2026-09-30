import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { trpc } from "@/lib/trpc";
import { toast } from "sonner";
import {
  AlertTriangle,
  Bell,
  Boxes,
  Check,
  ChevronRight,
  CircleHelp,
  Clock3,
  LayoutDashboard,
  Menu,
  Package,
  Pencil,
  Plus,
  RefreshCw,
  Settings,
  Send,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  TrendingDown,
  X,
  Zap,
} from "lucide-react";
import { useMemo, useState } from "react";

type Product = {
  id: number;
  name: string;
  sku: string;
  category: string;
  stock: number;
  minimumStock: number;
  status: "active" | "paused";
};

type ProductForm = Omit<Product, "id">;
const emptyForm: ProductForm = { name: "", sku: "", category: "Mercearia", stock: 0, minimumStock: 5, status: "active" };

const formatTime = (value?: string | Date | null) => value ? new Intl.DateTimeFormat("pt-BR", { hour: "2-digit", minute: "2-digit" }).format(new Date(value)) : "—";
const formatDate = (value?: string | Date | null) => value ? new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(value)).replace(" de ", " ") : "—";

function StatusChip({ product }: { product: Product }) {
  const critical = product.stock <= product.minimumStock;
  if (product.status === "paused") return <Badge className="status-chip paused"><CircleHelp size={12} /> Pausado</Badge>;
  if (product.stock === 0) return <Badge className="status-chip danger"><AlertTriangle size={12} /> Sem estoque</Badge>;
  if (critical) return <Badge className="status-chip warning"><TrendingDown size={12} /> Repor agora</Badge>;
  return <Badge className="status-chip success"><Check size={12} /> Saudável</Badge>;
}

function ProductDialog({ open, onOpenChange, product, onSaved }: { open: boolean; onOpenChange: (open: boolean) => void; product: Product | null; onSaved: () => void }) {
  const [form, setForm] = useState<ProductForm>(product ? { ...product } : emptyForm);
  const create = trpc.products.create.useMutation();
  const update = trpc.products.update.useMutation();
  const isEditing = Boolean(product);

  useMemo(() => { setForm(product ? { ...product } : emptyForm); }, [product, open]);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      if (isEditing && product) await update.mutateAsync({ id: product.id, data: form });
      else await create.mutateAsync(form);
      toast.success(isEditing ? "Produto atualizado." : "Produto criado.");
      onOpenChange(false);
      onSaved();
    } catch (error) { toast.error(error instanceof Error ? error.message : "Não foi possível salvar o produto."); }
  };

  const set = (key: keyof ProductForm, value: string | number) => setForm(prev => ({ ...prev, [key]: value }));
  return <Dialog open={open} onOpenChange={onOpenChange}>
    <DialogContent className="stock-dialog">
      <DialogHeader><DialogTitle>{isEditing ? "Editar produto" : "Adicionar produto"}</DialogTitle><DialogDescription>Defina o nível mínimo para receber alertas de reposição.</DialogDescription></DialogHeader>
      <form onSubmit={submit} className="form-grid">
        <label>Nome do produto<Input required value={form.name} onChange={e => set("name", e.target.value)} placeholder="Ex.: Café especial 250g" /></label>
        <label>SKU<Input required value={form.sku} onChange={e => set("sku", e.target.value.toUpperCase())} placeholder="Ex.: CAF-250" /></label>
        <label>Categoria<Input required value={form.category} onChange={e => set("category", e.target.value)} placeholder="Ex.: Mercearia" /></label>
        <div className="form-row"><label>Estoque atual<Input required type="number" min="0" value={form.stock} onChange={e => set("stock", Number(e.target.value))} /></label><label>Estoque mínimo<Input required type="number" min="0" value={form.minimumStock} onChange={e => set("minimumStock", Number(e.target.value))} /></label></div>
        <label>Status<select value={form.status} onChange={e => setForm(prev => ({ ...prev, status: e.target.value as Product["status"] }))}><option value="active">Ativo</option><option value="paused">Pausado</option></select></label>
        <DialogFooter><Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button><Button type="submit" disabled={create.isPending || update.isPending}>{create.isPending || update.isPending ? "Salvando…" : isEditing ? "Salvar alterações" : "Adicionar produto"}</Button></DialogFooter>
      </form>
    </DialogContent>
  </Dialog>;
}

function StockAdjustDialog({ open, onOpenChange, product, onSaved }: { open: boolean; onOpenChange: (open: boolean) => void; product: Product | null; onSaved: () => void }) {
  const [amount, setAmount] = useState(1);
  const [reason, setReason] = useState("Reposição");
  const adjust = trpc.products.adjust.useMutation();
  if (!product) return null;
  const submit = async (change: number) => {
    try { await adjust.mutateAsync({ id: product.id, change, reason }); toast.success("Estoque atualizado."); onOpenChange(false); onSaved(); }
    catch (error) { toast.error(error instanceof Error ? error.message : "Não foi possível ajustar o estoque."); }
  };
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="stock-dialog compact-dialog"><DialogHeader><DialogTitle>Ajustar estoque</DialogTitle><DialogDescription>{product.name} · estoque atual <strong>{product.stock}</strong></DialogDescription></DialogHeader><div className="adjust-preview"><span>Quantidade</span><div className="stepper"><Button type="button" variant="outline" size="icon" onClick={() => setAmount(Math.max(1, amount - 1))}>−</Button><strong>{amount}</strong><Button type="button" variant="outline" size="icon" onClick={() => setAmount(amount + 1)}>+</Button></div></div><label>Motivo<Input value={reason} onChange={e => setReason(e.target.value)} placeholder="Ex.: Reposição do fornecedor" /></label><DialogFooter><Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button><Button type="button" className="button-coral" disabled={adjust.isPending} onClick={() => submit(-amount)}>− Remover</Button><Button type="button" disabled={adjust.isPending} onClick={() => submit(amount)}>+ Adicionar</Button></DialogFooter></DialogContent></Dialog>;
}

function SettingsPanel({ open, onOpenChange, current, onSaved }: { open: boolean; onOpenChange: (open: boolean) => void; current?: { enabled: boolean; frequencyMinutes: number; chatId: string | null; tokenConfigured: boolean; maskedToken: string | null }; onSaved: () => void }) {
  const [token, setToken] = useState("");
  const [chatId, setChatId] = useState(current?.chatId ?? "");
  const [enabled, setEnabled] = useState(current?.enabled ?? false);
  const [frequency, setFrequency] = useState(current?.frequencyMinutes ?? 5);
  const save = trpc.settings.save.useMutation();
  const test = trpc.settings.test.useMutation();
  useMemo(() => { setChatId(current?.chatId ?? ""); setEnabled(current?.enabled ?? false); setFrequency(current?.frequencyMinutes ?? 5); setToken(""); }, [current, open]);
  const saveSettings = async () => { try { await save.mutateAsync({ botToken: token || undefined, chatId, enabled, frequencyMinutes: frequency }); toast.success("Configurações salvas."); onOpenChange(false); onSaved(); } catch (error) { toast.error(error instanceof Error ? error.message : "Não foi possível salvar."); } };
  const testConnection = async () => { try { await test.mutateAsync({ botToken: token || undefined, chatId }); toast.success("Mensagem de teste enviada no Telegram."); } catch (error) { toast.error(error instanceof Error ? error.message : "Falha na conexão com o Telegram."); } };
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="stock-dialog"><DialogHeader><DialogTitle>Alertas no Telegram</DialogTitle><DialogDescription>As credenciais ficam somente no servidor. O app nunca exibe o token completo.</DialogDescription></DialogHeader><div className="settings-callout"><Send size={17} /><div><strong>Canal atual: Telegram Bot API</strong><span>{current?.tokenConfigured ? `Token configurado ${current.maskedToken ?? ""}` : "Ainda não configurado"}</span></div></div><div className="form-grid"><label>Token do bot{current?.tokenConfigured && <small>Deixe em branco para manter o token atual.</small>}<Input type="password" value={token} onChange={e => setToken(e.target.value)} placeholder="123456:ABC…" autoComplete="off" /></label><label>Chat ID<Input value={chatId} onChange={e => setChatId(e.target.value)} placeholder="Ex.: -1001234567890" /></label><div className="form-row"><label>Frequência de verificação<select value={frequency} onChange={e => setFrequency(Number(e.target.value))}><option value={1}>A cada 1 minuto</option><option value={5}>A cada 5 minutos</option><option value={15}>A cada 15 minutos</option><option value={60}>A cada 1 hora</option></select></label><label className="switch-label">Alertas ativos<button type="button" className={`toggle ${enabled ? "on" : ""}`} onClick={() => setEnabled(!enabled)} aria-pressed={enabled}><span /></button></label></div></div><DialogFooter><Button type="button" variant="outline" onClick={testConnection} disabled={test.isPending || !token || !chatId}><Send size={15} /> {test.isPending ? "Testando…" : "Testar conexão"}</Button><Button type="button" onClick={saveSettings} disabled={save.isPending || !chatId}>{save.isPending ? "Salvando…" : "Salvar configurações"}</Button></DialogFooter></DialogContent></Dialog>;
}

export default function Home() {
  const [section, setSection] = useState<"overview" | "products" | "settings">("overview");
  const [mobileNav, setMobileNav] = useState(false);
  const [productDialog, setProductDialog] = useState<{ open: boolean; product: Product | null }>({ open: false, product: null });
  const [adjustDialog, setAdjustDialog] = useState<{ open: boolean; product: Product | null }>({ open: false, product: null });
  const [settingsOpen, setSettingsOpen] = useState(false);
  const query = trpc.dashboard.summary.useQuery(undefined, { refetchInterval: 30_000 });
  const check = trpc.alerts.check.useMutation();
  const remove = trpc.products.remove.useMutation();
  const data = query.data;
  const products = (data?.products ?? []) as Product[];
  const critical = useMemo(() => products.filter(product => product.status === "active" && product.stock <= product.minimumStock), [products]);
  const refresh = () => { void query.refetch(); };

  const deleteProduct = async (product: Product) => { if (!window.confirm(`Excluir ${product.name}? O histórico deste produto também será removido.`)) return; try { await remove.mutateAsync({ id: product.id }); toast.success("Produto excluído."); refresh(); } catch (error) { toast.error(error instanceof Error ? error.message : "Não foi possível excluir."); } };
  const runCheck = async () => { try { const result = await check.mutateAsync(); toast.success(`${result.checked} produtos verificados.`); refresh(); } catch (error) { toast.error(error instanceof Error ? error.message : "Falha na verificação."); } };
  const nav = (next: typeof section) => { setSection(next); setMobileNav(false); };

  return <div className="app-shell">
    <aside className={`sidebar ${mobileNav ? "mobile-open" : ""}`}><div className="brand"><img src="/stockalert-icon.png" alt="" /><div><strong>Stock<span>Alert</span></strong><small>MONITOR DE ESTOQUE</small></div><Button className="mobile-close" variant="ghost" size="icon" onClick={() => setMobileNav(false)}><X size={18} /></Button></div><div className="workspace"><span className="eyebrow">Workspace</span><button className="workspace-button"><span className="workspace-dot" /> Minha operação <ChevronRight size={15} /></button></div><nav className="main-nav"><span className="eyebrow">Menu principal</span><button className={section === "overview" ? "active" : ""} onClick={() => nav("overview")}><LayoutDashboard size={17} /> Visão geral</button><button className={section === "products" ? "active" : ""} onClick={() => nav("products")}><Package size={17} /> Produtos <span className="nav-count">{products.length}</span></button><button onClick={() => { setSettingsOpen(true); setMobileNav(false); }}><Settings size={17} /> Configurações</button></nav><div className="sidebar-bottom"><div className="help-card"><CircleHelp size={16} /><div><strong>Precisa de ajuda?</strong><span>Veja como configurar o Telegram.</span></div></div><div className="user-card"><div className="avatar">OP</div><div><strong>Operação</strong><span>Administrador</span></div><button aria-label="Abrir menu"><ChevronRight size={15} /></button></div></div></aside>
    <main className="main-content"><header className="topbar"><Button variant="ghost" size="icon" className="mobile-menu" onClick={() => setMobileNav(true)}><Menu size={20} /></Button><div className="breadcrumbs"><span>StockAlert</span><ChevronRight size={14} /><strong>{section === "overview" ? "Visão geral" : "Produtos"}</strong></div><div className="topbar-actions"><div className={`live-indicator ${data?.settings.enabled ? "configured" : ""}`}><span /> {data?.settings.enabled ? "Alertas ativos" : "Alertas não configurados"}</div><Button variant="outline" size="sm" onClick={() => setSettingsOpen(true)}><Settings size={15} /> Configurar alertas</Button><Button size="sm" onClick={() => setProductDialog({ open: true, product: null })}><Plus size={16} /> Novo produto</Button></div></header>
      {section === "overview" ? <>
        <section className="page-heading"><div><span className="eyebrow">{new Intl.DateTimeFormat("pt-BR", { weekday: "long", day: "2-digit", month: "long" }).format(new Date())}</span><h1>Estoque sob controle<span className="heading-dot">.</span></h1><p>Uma visão rápida do que precisa da sua atenção hoje.</p></div><div className="heading-actions"><Button variant="outline" onClick={runCheck} disabled={check.isPending}><RefreshCw size={16} className={check.isPending ? "spin" : ""} /> {check.isPending ? "Verificando…" : "Verificar agora"}</Button></div></section>
        <section className="kpi-grid"><div className="kpi-card kpi-primary"><div className="kpi-top"><span>Total de produtos</span><span className="kpi-icon"><Boxes size={18} /></span></div><strong>{data?.stats.totalProducts ?? "—"}</strong><small><span className="pulse-line" /> Catálogo ativo</small></div><div className="kpi-card kpi-critical"><div className="kpi-top"><span>Estoque crítico</span><span className="kpi-icon"><TrendingDown size={18} /></span></div><strong>{data?.stats.criticalProducts ?? "—"}</strong><small>{critical.length ? "Requer atenção hoje" : "Tudo dentro do limite"}</small></div><div className="kpi-card"><div className="kpi-top"><span>Sem estoque</span><span className="kpi-icon coral"><AlertTriangle size={18} /></span></div><strong>{data?.stats.outOfStock ?? "—"}</strong><small>{data?.stats.outOfStock ? "Itens parados" : "Nenhuma ruptura"}</small></div><div className="kpi-card"><div className="kpi-top"><span>Última verificação</span><span className="kpi-icon lime"><Clock3 size={18} /></span></div><strong className="time-kpi">{formatTime(data?.settings.lastCheckAt)}</strong><small>{data?.settings.lastCheckAt ? "Atualização automática" : "Verificação manual disponível"}</small></div></section>
        <section className="content-grid"><div className="panel products-panel"><div className="panel-header"><div><span className="eyebrow">Acompanhamento</span><h2>Produtos que pedem atenção</h2></div><Button variant="ghost" size="sm" onClick={() => nav("products")}>Ver todos <ChevronRight size={15} /></Button></div>{critical.length === 0 ? <div className="empty-state"><ShieldCheck size={28} /><strong>Operação saudável</strong><span>Nenhum produto está abaixo do estoque mínimo.</span></div> : <div className="critical-list">{critical.slice(0, 5).map(product => <div className="critical-row" key={product.id}><div className="product-mark"><Package size={17} /></div><div className="product-copy"><strong>{product.name}</strong><span>{product.sku} · {product.category}</span></div><div className="stock-reading"><strong className={product.stock === 0 ? "danger-text" : "warning-text"}>{product.stock}</strong><span>mín. {product.minimumStock}</span></div><StatusChip product={product} /><Button variant="outline" size="sm" onClick={() => setAdjustDialog({ open: true, product })}>Ajustar</Button></div>)}</div>}</div><div className="panel alerts-panel"><div className="panel-header"><div><span className="eyebrow">Central de alertas</span><h2>Atividade recente</h2></div><Bell size={18} className="panel-icon" /></div>{(data?.alerts ?? []).length === 0 ? <div className="empty-state small"><Check size={24} /><strong>Sem alertas abertos</strong><span>Você está em dia.</span></div> : <div className="alert-feed">{data?.alerts.slice(0, 5).map(alert => <div className="alert-item" key={alert.id}><span className="alert-marker" /><div><strong>{alert.productName}</strong><p>{alert.stock === 0 ? "Sem estoque disponível" : `${alert.stock} un. disponíveis · mínimo ${alert.minimumStock}`}</p><small>{formatDate(alert.createdAt)}</small></div></div>)}</div>}</div></section>
        <section className="insight-banner"><div className="insight-icon"><Zap size={20} /></div><div><strong>Dica de operação</strong><span>Configure o Telegram para receber alertas no celular antes que uma ruptura afete suas vendas.</span></div><Button variant="outline" size="sm" onClick={() => setSettingsOpen(true)}>Configurar agora <ChevronRight size={15} /></Button></section>
      </> : <section className="products-page"><div className="page-heading compact"><div><span className="eyebrow">Catálogo operacional</span><h1>Produtos<span className="heading-dot">.</span></h1><p>Cadastre itens e acompanhe os níveis mínimos de reposição.</p></div><Button onClick={() => setProductDialog({ open: true, product: null })}><Plus size={16} /> Novo produto</Button></div><div className="panel table-panel"><div className="table-toolbar"><div className="search-faux"><SlidersHorizontal size={16} /> Todos os produtos <span>{products.length}</span></div><span className="table-note">{data?.settings.lastCheckAt ? `Atualizado às ${formatTime(data.settings.lastCheckAt)}` : "Dados de demonstração"}</span></div><div className="table-wrap"><table><thead><tr><th>Produto</th><th>SKU</th><th>Categoria</th><th>Disponível</th><th>Estoque mínimo</th><th>Status</th><th className="actions-col">Ações</th></tr></thead><tbody>{products.map(product => <tr key={product.id}><td><div className="table-product"><div className="product-mark"><Package size={16} /></div><strong>{product.name}</strong></div></td><td><code>{product.sku}</code></td><td>{product.category}</td><td><strong className={product.stock <= product.minimumStock ? product.stock === 0 ? "danger-text" : "warning-text" : ""}>{product.stock} un.</strong></td><td>{product.minimumStock} un.</td><td><StatusChip product={product} /></td><td className="row-actions"><Button variant="ghost" size="icon-sm" aria-label="Ajustar estoque" onClick={() => setAdjustDialog({ open: true, product })}><TrendingDown size={15} /></Button><Button variant="ghost" size="icon-sm" aria-label="Editar produto" onClick={() => setProductDialog({ open: true, product })}><Pencil size={15} /></Button><Button variant="ghost" size="icon-sm" aria-label="Excluir produto" className="delete-action" onClick={() => deleteProduct(product)}><Trash2 size={15} /></Button></td></tr>)}</tbody></table></div></div></section>}
    </main>
    <ProductDialog open={productDialog.open} product={productDialog.product} onOpenChange={open => setProductDialog(prev => ({ ...prev, open }))} onSaved={refresh} />
    <StockAdjustDialog open={adjustDialog.open} product={adjustDialog.product} onOpenChange={open => setAdjustDialog(prev => ({ ...prev, open }))} onSaved={refresh} />
    <SettingsPanel open={settingsOpen} current={data?.settings} onOpenChange={setSettingsOpen} onSaved={refresh} />
  </div>;
}
