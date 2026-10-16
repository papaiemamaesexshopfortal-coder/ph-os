import { useEffect, useState } from 'react';
import { Download, X } from 'lucide-react';

type InstallPrompt = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
};

export default function InstallApp() {
  const [prompt, setPrompt] = useState<InstallPrompt | null>(null);
  const [showHelp, setShowHelp] = useState(false);
  const [notice, setNotice] = useState('');
  const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const standalone = window.matchMedia('(display-mode: standalone)').matches ||
    Boolean((navigator as Navigator & { standalone?: boolean }).standalone);

  useEffect(() => {
    const capture = (event: Event) => {
      event.preventDefault();
      setPrompt(event as InstallPrompt);
    };
    window.addEventListener('beforeinstallprompt', capture);
    return () => window.removeEventListener('beforeinstallprompt', capture);
  }, []);

  const install = async () => {
    if (standalone) {
      setNotice('O PH O.S. já está instalado neste aparelho.');
      window.setTimeout(() => setNotice(''), 4000);
      return;
    }
    if (prompt) {
      await prompt.prompt();
      const result = await prompt.userChoice;
      if (result.outcome === 'accepted') setPrompt(null);
      return;
    }
    setShowHelp(true);
  };

  return <>
    <button className="install-app-button" onClick={() => void install()} aria-label="Instalar PH O.S.">
      <Download size={16} /> Instalar app
    </button>
    {notice && <div className="install-app-notice" role="status">{notice}</div>}
    {showHelp && <div className="install-app-backdrop" onClick={() => setShowHelp(false)}>
      <section className="install-app-dialog" role="dialog" aria-modal="true" aria-labelledby="install-app-title" onClick={event => event.stopPropagation()}>
        <button className="install-app-close" onClick={() => setShowHelp(false)} aria-label="Fechar"><X size={18}/></button>
        <div className="install-app-mark"><Download size={20}/></div>
        <h2 id="install-app-title">Instalar PH O.S.</h2>
        {ios ? <>
          <p>No iPhone ou iPad, abra esta página no <strong>Safari</strong>.</p>
          <ol><li>Toque em <strong>Compartilhar</strong> (quadrado com seta para cima).</li><li>Escolha <strong>Adicionar à Tela de Início</strong>.</li><li>Toque em <strong>Adicionar</strong>.</li></ol>
        </> : <>
          <p>No Android, use o <strong>Google Chrome</strong> para instalar o PH O.S.</p>
          <ol><li>Toque no menu <strong>⋮</strong> do Chrome.</li><li>Escolha <strong>Instalar app</strong> ou <strong>Adicionar à tela inicial</strong>.</li><li>Confirme em <strong>Instalar</strong>.</li></ol>
        </>}
        <p className="install-app-footnote">O app precisa de internet para acessar os dados da empresa.</p>
        <button className="install-app-done" onClick={() => setShowHelp(false)}>Entendi</button>
      </section>
    </div>}
  </>;
}
