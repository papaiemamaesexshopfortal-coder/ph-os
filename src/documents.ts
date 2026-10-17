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

export async function receiptPdf(payment: Data, quote: Data | undefined, version: Data | undefined, client: Data, company?: Data): Promise<File> {
  type ReceiptRow = { label: string; value: string; kind?: 'section' | 'total' };
  const rows: ReceiptRow[] = [
    { label: 'Dados do recebimento', value: '', kind: 'section' },
    { label: 'Cliente', value: client?.name || '' },
    { label: 'Contato do cliente', value: client?.phone ? localPhone(client.phone) : '' },
    { label: 'Documento', value: client?.document || '' },
    { label: 'Referência', value: quote ? `ORC-${String(quote.quote_no).padStart(5, '0')}` : `Pagamento ${String(payment.id).slice(0, 8)}` },
    { label: 'Data do pagamento', value: payment.paid_at ? new Date(payment.paid_at).toLocaleString('pt-BR') : date(payment.due_at) },
    { label: 'Forma de pagamento', value: method(payment.method) },
    { label: 'Serviço relacionado', value: '', kind: 'section' },
  ];
  const items = (version?.items || []).map((item: Data) => `${item.description} (quantidade: ${item.quantity})`);
  rows.push({ label: 'Serviços e itens', value: items.join('; ') || payment.notes || 'Serviço não detalhado no lançamento.' });
  if (version?.description) rows.push({ label: 'Descrição do orçamento', value: String(version.description) });
  rows.push(
    { label: 'VALOR RECEBIDO', value: currency(payment.amount), kind: 'total' },
    { label: 'Observação do lançamento', value: payment.notes || '' },
    { label: 'Empresa', value: company?.name || 'PH SERVICE FORTAL' },
    { label: 'Contato', value: company?.phone || '(86) 99949-0316' },
  );

  // Render vector text directly. html2canvas is unreliable in Android WebView for
  // long/off-screen receipts and can fail before the native share sheet is opened.
  const left = 5;
  const width = 70;
  const prepared = rows.flatMap(row => {
    if (!row.value && row.kind !== 'section') return [];
    if (row.kind === 'section') return [{ row, lines: [row.label.toUpperCase()], font: 9, height: 8 }];
    if (row.kind === 'total') return [{ row, lines: [row.label, row.value], font: 10, height: 15 }];
    const font = 8.5;
    return [{ row, lines: [] as string[], font, height: 0 }];
  });
  const measure = new jsPDF({ unit: 'mm', format: [80, 100] });
  const layout = prepared.map(item => {
    if (item.row.kind === 'section' || item.row.kind === 'total') return item;
    const lines = measure.splitTextToSize(`${item.row.label}: ${item.row.value}`, width) as string[];
    return { ...item, lines, height: Math.max(4.5, lines.length * 4.2 + 1) };
  });
  const headerHeight = 33;
  const contentHeight = layout.reduce((sum, item) => sum + item.height + (item.row.kind === 'section' ? 2 : 1), 0);
  const pdfHeightMm = Math.max(70, headerHeight + contentHeight + 17);
  const pdf = new jsPDF({ unit: 'mm', format: [80, pdfHeightMm], compress: true });
  const brand = company?.name || 'PH SERVICE FORTAL';
  pdf.setProperties({ title: 'Recibo térmico 80 mm', subject: 'Recibo de pagamento', author: brand });
  pdf.setFillColor(17, 38, 73); pdf.rect(0, 0, 80, 25, 'F');
  pdf.setDrawColor(198, 161, 84); pdf.setLineWidth(1); pdf.line(0, 25, 80, 25);
  pdf.setTextColor(255, 255, 255); pdf.setFont('helvetica', 'bold'); pdf.setFontSize(11);
  pdf.text(pdf.splitTextToSize(brand, 70), 40, 9, { align: 'center' });
  pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8);
  const phone = company?.phone || '(86) 99949-0316';
  pdf.text(pdf.splitTextToSize(phone, 70), 40, 17, { align: 'center' });
  pdf.setTextColor(17, 38, 73); pdf.setFont('helvetica', 'bold'); pdf.setFontSize(9);
  pdf.text('RECIBO DE PAGAMENTO', 40, 31, { align: 'center' });
  pdf.setTextColor(105, 115, 134); pdf.setFont('helvetica', 'normal'); pdf.setFontSize(7.5);
  pdf.text(`Emitido em ${new Date().toLocaleDateString('pt-BR')}`, 40, 36, { align: 'center' });
  let y = 42;
  for (const item of layout) {
    const { row } = item;
    if (row.kind === 'section') {
      pdf.setTextColor(17, 38, 73); pdf.setFont('helvetica', 'bold'); pdf.setFontSize(item.font);
      pdf.text(row.label.toUpperCase(), left, y);
      y += 4;
      pdf.setDrawColor(137, 146, 162); pdf.setLineDashPattern([1, 1], 0); pdf.line(left, y, 75, y); pdf.setLineDashPattern([], 0);
      y += 4;
    } else if (row.kind === 'total') {
      pdf.setFillColor(17, 38, 73); pdf.roundedRect(left, y - 2, width, item.height - 1, 1.5, 1.5, 'F');
      pdf.setTextColor(255, 255, 255); pdf.setFont('helvetica', 'bold'); pdf.setFontSize(8.5);
      pdf.text(row.label, 40, y + 3, { align: 'center' });
      pdf.setFontSize(11); pdf.text(row.value, 40, y + 9, { align: 'center' });
      y += item.height;
    } else {
      pdf.setTextColor(45, 55, 72); pdf.setFont('helvetica', 'normal'); pdf.setFontSize(item.font);
      pdf.text(item.lines, left, y);
      y += item.height;
    }
  }
  y += 2;
  pdf.setDrawColor(137, 146, 162); pdf.setLineDashPattern([1, 1], 0); pdf.line(left, y, 75, y); pdf.setLineDashPattern([], 0);
  y += 5; pdf.setTextColor(105, 115, 134); pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8);
  pdf.text('Obrigado pela preferência!', 40, y, { align: 'center' });
  const blob = pdf.output('blob');
  return new File([blob], `recibo-80mm-${String(payment.id).slice(0, 8)}.pdf`, { type: 'application/pdf' });
}
