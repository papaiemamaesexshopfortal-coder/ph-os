import { jsPDF } from 'jspdf';

type Data = Record<string, any>;
const currency = (value: unknown) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(Number(value || 0));
const date = (value: unknown) => {
  if (!value) return '—';
  const raw = String(value);
  const onlyDate = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
  return onlyDate ? `${onlyDate[3]}/${onlyDate[2]}/${onlyDate[1]}` : new Date(raw).toLocaleDateString('pt-BR');
};
const method = (value: string) => ({ pix: 'Pix', cash: 'Dinheiro', debit: 'Cartão de débito', credit: 'Cartão de crédito', transfer: 'Transferência bancária', installment: 'Parcelado', entry_balance: 'Entrada + saldo', other: 'Outro' } as Record<string, string>)[value] || 'A combinar';
const localPhone = (value: unknown) => {
  let digits = String(value || '').replace(/\D/g, '');
  if (digits.startsWith('55') && (digits.length === 12 || digits.length === 13)) digits = digits.slice(2);
  if (digits.length === 11) return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
  if (digits.length === 10) return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`;
  return digits;
};


class DocumentPage {
  doc = new jsPDF({ unit: 'mm', format: 'a4' });
  y = 19;
  constructor(private title: string, private subtitle: string) {
    this.doc.setProperties({ title, subject: 'PH O.S. - PH SERVICE FORTAL', author: 'PH SERVICE FORTAL' });
    this.header(true);
  }
  private header(first = false) {
    if (!first) { this.doc.addPage(); this.y = 19; }
    this.doc.setFillColor(17, 38, 73); this.doc.rect(0, 0, 210, 31, 'F');
    this.doc.setTextColor(255, 255, 255); this.doc.setFont('helvetica', 'bold'); this.doc.setFontSize(16); this.doc.text('PH SERVICE FORTAL', 17, 14);
    this.doc.setFont('helvetica', 'normal'); this.doc.setFontSize(9); this.doc.text('(86) 99949-0316  |  Fortaleza - CE', 17, 22);
    this.doc.setDrawColor(198, 161, 84); this.doc.setLineWidth(1.4); this.doc.line(17, 32, 193, 32);
    this.y = 43; this.doc.setTextColor(23, 32, 51); this.doc.setFont('helvetica', 'bold'); this.doc.setFontSize(15); this.doc.text(this.title, 17, this.y); this.y += 7;
    this.doc.setFont('helvetica', 'normal'); this.doc.setFontSize(9); this.doc.text(this.subtitle, 17, this.y); this.y += 8;
  }
  ensure(height: number) { if (this.y + height > 276) this.header(); }
  section(title: string) { this.ensure(12); this.y += 2; this.doc.setTextColor(17, 38, 73); this.doc.setFont('helvetica', 'bold'); this.doc.setFontSize(10); this.doc.text(title, 17, this.y); this.y += 5; }
  line(label: string, value: unknown) {
    if (value == null || value === '') return;
    const content = `${label}: ${String(value)}`;
    const lines = this.doc.splitTextToSize(content, 176) as string[];
    this.ensure(lines.length * 4.6 + 1); this.doc.setFont('helvetica', 'normal'); this.doc.setTextColor(45, 55, 72); this.doc.setFontSize(9);
    this.doc.text(lines, 17, this.y); this.y += lines.length * 4.6 + 1;
  }
  item(description: string, quantity: unknown, unitPrice: unknown, total: unknown) {
    const lines = this.doc.splitTextToSize(description || 'Item', 89) as string[];
    const height = Math.max(8, lines.length * 4.5 + 3); this.ensure(height + 5);
    this.doc.setFillColor(244, 246, 249); this.doc.rect(17, this.y - 4, 176, height, 'F');
    this.doc.setFont('helvetica', 'normal'); this.doc.setFontSize(8.5); this.doc.setTextColor(45, 55, 72);
    this.doc.text(lines, 19, this.y); this.doc.text(String(quantity ?? ''), 113, this.y); this.doc.text(currency(unitPrice), 135, this.y); this.doc.text(currency(total), 191, this.y, { align: 'right' });
    this.y += height + 1;
  }
  total(label: string, value: unknown) {
    this.ensure(13); this.doc.setFillColor(17, 38, 73); this.doc.roundedRect(17, this.y - 5, 176, 12, 2, 2, 'F');
    this.doc.setTextColor(255, 255, 255); this.doc.setFont('helvetica', 'bold'); this.doc.setFontSize(11);
    this.doc.text(label, 21, this.y + 2.5); this.doc.text(currency(value), 189, this.y + 2.5, { align: 'right' }); this.y += 13;
  }
  finish(filename: string) {
    const totalPages = this.doc.getNumberOfPages();
    for (let page = 1; page <= totalPages; page++) {
      this.doc.setPage(page); this.doc.setDrawColor(223, 226, 231); this.doc.line(17, 284, 193, 284);
      this.doc.setFont('helvetica', 'normal'); this.doc.setFontSize(8); this.doc.setTextColor(100, 110, 125);
      this.doc.text('PH SERVICE FORTAL  |  Atendimento: (86) 99949-0316', 17, 290);
      this.doc.text(`${page}/${totalPages}`, 193, 290, { align: 'right' });
    }
    return new File([this.doc.output('blob')], filename, { type: 'application/pdf' });
  }
}

export function quotePdf(quote: Data, version: Data, client: Data, company?: Data): File {
  const number = `ORC-${String(quote.quote_no).padStart(5, '0')}`;
  const page = new DocumentPage(`Orçamento ${number}`, `Versão ${quote.current_version}  |  Emitido em ${date(quote.created_at)}  |  Válido até ${date(quote.valid_until)}`);
  page.section('Cliente e serviço'); page.line('Cliente', client?.name); page.line('Telefone', client?.phone); page.line('E-mail', client?.email);
  const addr = version?.service_address || client?.address || {};
  page.line('Local de execução', [addr.street, addr.number, addr.neighborhood, addr.city, addr.state, addr.zip].filter(Boolean).join(', ') || 'A combinar');
  page.line('Descrição', version?.description);
  page.section('Itens do orçamento');
  (version?.items || []).forEach((item: Data) => page.item(item.description, item.quantity, item.unit_price, Number(item.quantity || 0) * Number(item.unit_price || 0)));
  page.section('Resumo financeiro'); page.line('Subtotal', currency(version?.subtotal)); page.line('Acréscimos', currency(version?.additions)); page.line('Despesas e deslocamento', currency(version?.expenses));
  if (Number(version?.discount) > 0) page.line('Desconto', `- ${currency(version.discount)}`);
  if (Number(version?.card_fee_amount) > 0) page.line('Taxa da operadora informada', currency(version.card_fee_amount));
  page.total('VALOR TOTAL', version?.total);
  page.section('Prazo, pagamento e condições'); page.line('Prazo estimado', version?.estimated_duration || 'A combinar'); page.line('Forma de pagamento', method(version?.payment_method));
  if (Number(version?.entry_amount) > 0) page.line('Entrada', currency(version.entry_amount));
  if (Number(version?.installments_count) > 1) page.line('Parcelamento', `${version.installments_count} parcelas`);
  page.line('Condições', version?.payment_terms); page.line('Garantia', version?.warranty); page.line('Observações', version?.notes);
  page.line('Contato comercial', company?.phone || '(86) 99949-0316'); page.line('Site', company?.website || 'https://ph-service-fortal.vercel.app/');
  return page.finish(`${number}-v${quote.current_version}.pdf`);
}

export function receiptPdf(payment: Data, quote: Data | undefined, version: Data | undefined, client: Data, company?: Data): File {
  const page = new DocumentPage(`Recibo de pagamento`, `Emitido em ${new Date().toLocaleDateString('pt-BR')}`);
  page.section('Dados do recebimento'); page.line('Cliente', client?.name); page.line('Contato do cliente', client?.phone ? localPhone(client.phone) : ''); page.line('Documento', client?.document); page.line('Referência', quote ? `ORC-${String(quote.quote_no).padStart(5, '0')}` : `Pagamento ${String(payment.id).slice(0, 8)}`);
  page.line('Data do pagamento', payment.paid_at ? new Date(payment.paid_at).toLocaleString('pt-BR') : date(payment.due_at)); page.line('Forma de pagamento', method(payment.method));
  page.section('Serviço relacionado');
  const descriptions = (version?.items || []).map((item: Data) => `${item.description} (qtd. ${item.quantity})`);
  page.line('Serviços e itens', descriptions.join('; ') || payment.notes || 'Serviço não detalhado no lançamento.');
  if (version?.description) page.line('Descrição do orçamento', version.description);
  page.total('VALOR RECEBIDO', payment.amount);
  page.line('Observação do lançamento', payment.notes); page.line('Empresa', company?.name || 'PH SERVICE FORTAL'); page.line('Contato', company?.phone || '(86) 99949-0316');
  return page.finish(`recibo-${String(payment.id).slice(0, 8)}.pdf`);
}
