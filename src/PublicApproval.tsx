import { useEffect, useState } from 'react';
import { Check, FileText, LoaderCircle, X } from 'lucide-react';
import { configured, supabase } from './supabase';

type Quote = Record<string, any>;
const money = (v: unknown) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(Number(v || 0));
const date = (v: string | null) => v ? new Date(`${v}T12:00:00`).toLocaleDateString('pt-BR') : 'Sem data';
const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]!));

export default function PublicApproval({ token }: { token: string }) {
  const [quote, setQuote] = useState<Quote | null>(null);
  const [name, setName] = useState('');
  const [accepted, setAccepted] = useState(false);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [result, setResult] = useState('');
  useEffect(() => {
    if (!configured || !supabase) { setError('Portal temporariamente indisponível.'); setLoading(false); return; }
    supabase.functions.invoke('quote-public', { body: { action: 'get', token } }).then(({ data, error }) => {
      if (error) setError('Este link é inválido, expirou ou já foi respondido. Entre em contato com a PH SERVICE FORTAL.');
      else setQuote(data as Quote);
      setLoading(false);
    });
  }, [token]);
  const decide = async (outcome: 'approved' | 'declined' | 'change_requested') => {
    if (!supabase || !quote || !name.trim() || (outcome === 'approved' && !accepted)) return;
    setBusy(true); setError('');
    const { error } = await supabase.functions.invoke('quote-public', { body: {
      action: 'decide', token, name: name.trim(), outcome, accepted: outcome === 'approved' && accepted
    } });
    setBusy(false);
    if (error) setError('Não foi possível registrar. O link pode ter expirado ou já ter sido usado.');
    else setResult(outcome === 'approved' ? 'Orçamento aprovado. A PH SERVICE FORTAL recebeu sua confirmação.' : outcome === 'declined' ? 'Recusa registrada. Obrigado por nos avisar.' : 'Solicitação de alteração registrada. A equipe entrará em contato.');
  };
  const printQuote = () => {
    if (!quote) return;
    const items = Array.isArray(quote.items) ? quote.items : [];
    const lines = items.map((x: any) => `<tr><td>${esc(x.description)}</td><td>${esc(x.quantity)}</td><td>${money(x.unit_price)}</td><td>${money(Number(x.quantity) * Number(x.unit_price))}</td></tr>`).join('');
    const w = window.open('', '_blank'); if (!w) return;
    w.document.write(`<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Orçamento ORC-${esc(quote.quote_no)}</title><style>body{font:14px Arial,sans-serif;color:#172033;max-width:820px;margin:40px auto;padding:0 24px}h1{color:#10264a}small{color:#667085}.total{text-align:right;font-size:24px;font-weight:bold;margin-top:20px}table{width:100%;border-collapse:collapse;margin-top:24px}th,td{text-align:left;padding:12px;border-bottom:1px solid #ddd}th{background:#f3f5f8}.brand{border-bottom:3px solid #c6a154;padding-bottom:18px}.conditions{white-space:pre-wrap}</style><div class="brand"><h1>${esc(quote.company_name)}</h1><div>Orçamento ORC-${esc(String(quote.quote_no).padStart(5,'0'))} · versão ${esc(quote.version)}</div><small>Cliente: ${esc(quote.client_name)} · Validade: ${date(quote.valid_until)}</small></div><h2>Serviços e condições</h2><p>${esc(quote.description)}</p><table><thead><tr><th>Descrição</th><th>Qtd.</th><th>Unitário</th><th>Total</th></tr></thead><tbody>${lines}</tbody></table><p>Subtotal: ${money(quote.subtotal)} · Acréscimos: ${money(quote.additions)} · Despesas: ${money(quote.expenses)} · Desconto: ${money(quote.discount)}</p><div class="total">Total: ${money(quote.total)}</div><p>Prazo: ${esc(quote.estimated_duration || 'A combinar')}<br>Pagamento: ${esc(quote.payment_terms || 'A combinar')}<br>Garantia: ${esc(quote.warranty || 'Conforme aplicável')}</p><p class="conditions">${esc(quote.notes)}</p><script>window.print()</script></html>`); w.document.close();
  };
  return <main className="public-page"><article className="public-card"><div className="public-brand"><img src="/logo-ph-service-fortal.webp" alt="PH SERVICE FORTAL"/><div><strong>PH SERVICE FORTAL</strong><small>ORÇAMENTO E ACEITE</small></div></div>
    {loading ? <div className="public-message"><LoaderCircle className="spin"/> Carregando orçamento…</div> : result ? <div className="public-result"><Check/><h1>Obrigado!</h1><p>{result}</p></div> : error ? <div className="public-message error"><X/><p>{error}</p><a href="https://wa.me/558699490316">Falar com atendimento</a></div> : quote && <>
      <div className="public-title"><div><small>ORÇAMENTO ORC-{String(quote.quote_no).padStart(5,'0')} · VERSÃO {quote.version}</small><h1>Confira sua proposta</h1></div><button className="secondary" onClick={printQuote}><FileText size={16}/> Salvar PDF</button></div>
      <p className="public-greeting">Olá, {quote.client_name}. Confira os serviços e as condições antes de responder.</p>
      <div className="public-facts"><div><small>Validade</small><b>{date(quote.valid_until)}</b></div><div><small>Prazo estimado</small><b>{quote.estimated_duration || 'A combinar'}</b></div><div><small>Pagamento</small><b>{quote.payment_terms || 'A combinar'}</b></div></div>
      <h2>Escopo</h2><p>{quote.description}</p><div className="public-items">{(quote.items || []).map((item: any, i: number) => <div className="public-item" key={i}><span>{item.description}<small>{item.quantity} × {money(item.unit_price)}</small></span><b>{money(Number(item.quantity) * Number(item.unit_price))}</b></div>)}</div>
      <div className="public-calculation"><span>Subtotal <b>{money(quote.subtotal)}</b></span>{Number(quote.additions)>0&&<span>Acréscimos <b>{money(quote.additions)}</b></span>}{Number(quote.expenses)>0&&<span>Despesas e deslocamento <b>{money(quote.expenses)}</b></span>}{Number(quote.discount)>0&&<span>Desconto <b>− {money(quote.discount)}</b></span>}<strong>Total <b>{money(quote.total)}</b></strong></div>
      {quote.warranty&&<p><b>Garantia:</b> {quote.warranty}</p>}{quote.notes&&<p><b>Observações:</b> {quote.notes}</p>}
      <label className="public-label">Seu nome completo<input value={name} onChange={e=>setName(e.target.value)} maxLength={160} autoComplete="name"/></label>
      <label className="public-check"><input type="checkbox" checked={accepted} onChange={e=>setAccepted(e.target.checked)}/> Li e aceito o escopo, os valores e as condições desta versão do orçamento.</label>
      {error&&<div className="error">{error}</div>}
      <div className="public-actions"><button disabled={busy||!name.trim()||!accepted} className="primary" onClick={()=>decide('approved')}><Check size={16}/> Aprovar orçamento</button><button disabled={busy||!name.trim()} className="secondary" onClick={()=>decide('change_requested')}>Solicitar alteração</button><button disabled={busy||!name.trim()} className="danger-outline" onClick={()=>decide('declined')}>Recusar</button></div>
      <small className="public-foot">Sua decisão registra o orçamento e a versão visualizada. Este aceite do orçamento não representa assinatura digital qualificada de contrato.</small>
    </>}
  </article></main>;
}
