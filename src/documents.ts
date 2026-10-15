import { jsPDF } from 'jspdf';
import html2canvas from 'html2canvas';

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

  const root = document.createElement('div');
  Object.assign(root.style, { position: 'fixed', left: '-10000px', top: '0', width: '302px', zIndex: '-1', background: '#fff' });
  document.body.append(root);

  const makeReceipt = () => {
    const sheet = document.createElement('div');
    Object.assign(sheet.style, { width: '302px', boxSizing: 'border-box', padding: '18px 18px 22px', background: '#fff', color: '#172033', fontFamily: 'Arial, sans-serif' });
    const header = document.createElement('div');
    Object.assign(header.style, { background: '#112649', color: '#fff', margin: '-18px -18px 18px', padding: '17px 18px 14px', borderBottom: '4px solid #c6a154', textAlign: 'center' });
    const brand = document.createElement('div'); brand.textContent = company?.name || 'PH SERVICE FORTAL';
    Object.assign(brand.style, { fontSize: '17px', lineHeight: '1.2', fontWeight: '700', letterSpacing: '.2px' });
    const contact = document.createElement('div'); contact.textContent = company?.phone || '(86) 99949-0316';
    Object.assign(contact.style, { fontSize: '11px', marginTop: '5px', color: '#e7ebf2' });
    const title = document.createElement('div'); title.textContent = 'RECIBO DE PAGAMENTO';
    Object.assign(title.style, { fontSize: '14px', fontWeight: '700', color: '#112649', marginTop: '0', textAlign: 'center' });
    const subtitle = document.createElement('div'); subtitle.textContent = `Emitido em ${new Date().toLocaleDateString('pt-BR')}`;
    Object.assign(subtitle.style, { fontSize: '10px', color: '#697386', marginTop: '5px', marginBottom: '15px', textAlign: 'center' });
    header.append(brand, contact); sheet.append(header, title, subtitle);
    const content = document.createElement('div'); Object.assign(content.style, { display: 'flex', flexDirection: 'column', gap: '8px' });
    sheet.append(content);
    const footer = document.createElement('div'); footer.textContent = 'Obrigado pela preferência!';
    Object.assign(footer.style, { marginTop: '18px', paddingTop: '10px', borderTop: '1px dashed #8992a2', color: '#697386', fontSize: '10px', textAlign: 'center' });
    sheet.append(footer); root.append(sheet); return { sheet, content };
  };

  try {
    const { sheet, content } = makeReceipt();
    for (const row of rows) {
      if (!row.value && row.kind !== 'section') continue;
      const block = document.createElement('div');
      if (row.kind === 'section') {
        block.textContent = row.label;
        Object.assign(block.style, { color: '#112649', fontSize: '11px', fontWeight: '700', borderBottom: '1px dashed #8992a2', paddingBottom: '5px', marginTop: '7px', textTransform: 'uppercase' });
      } else if (row.kind === 'total') {
        Object.assign(block.style, { background: '#112649', color: '#fff', padding: '10px 9px', display: 'flex', flexDirection: 'column', gap: '4px', fontWeight: '700', fontSize: '12px', textAlign: 'center', marginTop: '4px' });
        const label = document.createElement('span'); label.textContent = row.label;
        const value = document.createElement('span'); value.textContent = row.value; block.append(label, value);
      } else {
        Object.assign(block.style, { fontSize: '10px', lineHeight: '1.4', overflowWrap: 'anywhere', padding: '1px 0' });
        const label = document.createElement('strong'); label.textContent = `${row.label}: `;
        const value = document.createElement('span'); value.textContent = row.value; block.append(label, value);
      }
      content.append(block);
    }
    const canvas = await html2canvas(sheet, { scale: 2, backgroundColor: '#ffffff', logging: false, useCORS: true });
    const image = canvas.toDataURL('image/jpeg', 0.96);
    const pdfHeightMm = Math.max(60, (canvas.height / canvas.width) * 80);
    const pdf = new jsPDF({ unit: 'mm', format: [80, pdfHeightMm], compress: true });
    pdf.setProperties({ title: 'Recibo térmico 80 mm', subject: 'PH O.S. - PH SERVICE FORTAL', author: 'PH SERVICE FORTAL' });
    pdf.addImage(image, 'JPEG', 0, 0, 80, pdfHeightMm, undefined, 'FAST');
    const blob = pdf.output('blob');
    return new File([blob], `recibo-80mm-${String(payment.id).slice(0, 8)}.pdf`, { type: 'application/pdf' });
  } finally {
    root.remove();
  }
}
