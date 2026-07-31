import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import QRCode from 'qrcode';
import { api } from '../lib/api';
import './landing.css';
import './download.css';

export default function DownloadPage() {
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [links, setLinks] = useState(null);
  const [iosQr, setIosQr] = useState('');
  const [androidQr, setAndroidQr] = useState('');

  useEffect(() => {
    document.documentElement.classList.add('lp-scroll-lock');
    return () => document.documentElement.classList.remove('lp-scroll-lock');
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function buildQrs() {
      if (!links?.iosUrl || !links?.androidUrl) {
        setIosQr('');
        setAndroidQr('');
        return;
      }
      try {
        const [ios, android] = await Promise.all([
          QRCode.toDataURL(links.iosUrl, {
            width: 280,
            margin: 2,
            color: { dark: '#0e0e0e', light: '#ffffff' },
          }),
          QRCode.toDataURL(links.androidUrl, {
            width: 280,
            margin: 2,
            color: { dark: '#0e0e0e', light: '#ffffff' },
          }),
        ]);
        if (!cancelled) {
          setIosQr(ios);
          setAndroidQr(android);
        }
      } catch (err) {
        if (!cancelled) setError(err.message || 'Could not generate QR codes.');
      }
    }
    buildQrs();
    return () => {
      cancelled = true;
    };
  }, [links]);

  async function handleUnlock(event) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const data = await api('/api/download/unlock', {
        method: 'POST',
        body: { code },
      });
      setLinks({
        iosUrl: data.iosUrl,
        androidUrl: data.androidUrl,
        androidAbi: data.androidAbi,
        code: data.code,
      });
    } catch (err) {
      setLinks(null);
      setError(err.message || 'Could not unlock downloads.');
    } finally {
      setBusy(false);
    }
  }

  function resetGate() {
    setLinks(null);
    setIosQr('');
    setAndroidQr('');
    setError('');
    setCode('');
  }

  return (
    <div className="lp dl">
      <div className="lp-glow lp-glow-a" aria-hidden />
      <div className="lp-glow lp-glow-b" aria-hidden />

      <header className="lp-nav dl-nav">
        <Link to="/" className="lp-brand" style={{ textDecoration: 'none', color: 'inherit' }}>
          <img className="lp-mark" src="/app-icon.png" alt="" aria-hidden />
          <span>BLIND TIGER</span>
        </Link>
        <Link to="/" className="dl-back">
          ← Welcome
        </Link>
      </header>

      <main className="dl-main">
        {!links ? (
          <section className="dl-gate">
            <img className="dl-app-icon" src="/app-icon.png" alt="Blind Tiger app icon" />
            <p className="lp-eyebrow">INVITE ONLY</p>
            <h1 className="dl-title">Download for free</h1>
            <p className="dl-lede">
              Enter your Blind Tiger invite code to unlock the iOS and Android install QR codes.
            </p>
            {error && <p className="dl-error" role="alert">{error}</p>}
            <form className="dl-form" onSubmit={handleUnlock}>
              <label htmlFor="download-invite-code">Invite code</label>
              <input
                id="download-invite-code"
                type="text"
                autoComplete="off"
                autoCapitalize="characters"
                spellCheck={false}
                placeholder="BT-XXXXXXXX"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                required
              />
              <button className="lp-btn lp-btn-primary" type="submit" disabled={busy}>
                {busy ? 'Checking…' : 'Unlock downloads'}
              </button>
            </form>
            <p className="dl-hint">
              Codes are issued by Blind Tiger staff. If you don’t have one, ask at the desk.
            </p>
          </section>
        ) : (
          <section className="dl-reveal">
            <img className="dl-app-icon" src="/app-icon.png" alt="Blind Tiger app icon" />
            <p className="lp-eyebrow">READY TO INSTALL</p>
            <h1 className="dl-title">Scan your platform</h1>
            <p className="dl-lede">
              Code <strong>{links.code}</strong> unlocked. Scan with your phone camera, or open the
              link on this device.
            </p>
            {error && <p className="dl-error" role="alert">{error}</p>}

            <div className="dl-platforms">
              <article className="dl-platform">
                <h2>iOS</h2>
                <p>TestFlight beta</p>
                <div className="dl-qr-frame">
                  {iosQr ? (
                    <img src={iosQr} alt="QR code for Blind Tiger iOS TestFlight" />
                  ) : (
                    <span className="dl-qr-loading">Preparing QR…</span>
                  )}
                </div>
                <a
                  className="lp-btn lp-btn-primary"
                  href={links.iosUrl}
                  target="_blank"
                  rel="noreferrer"
                >
                  Open TestFlight
                </a>
              </article>

              <article className="dl-platform">
                <h2>Android</h2>
                <p>
                  {links.androidAbi && links.androidAbi !== 'universal'
                    ? `Direct APK · ${links.androidAbi}`
                    : 'Direct APK install'}
                </p>
                <div className="dl-qr-frame">
                  {androidQr ? (
                    <img src={androidQr} alt="QR code for Blind Tiger Android APK" />
                  ) : (
                    <span className="dl-qr-loading">Preparing QR…</span>
                  )}
                </div>
                <a
                  className="lp-btn lp-btn-primary"
                  href={links.androidUrl}
                  target="_blank"
                  rel="noreferrer"
                >
                  Download APK
                </a>
              </article>
            </div>

            <p className="dl-hint">
              iOS: install TestFlight first, then accept the Blind Tiger beta. Android: allow
              installs from this source if prompted.
            </p>
            <button type="button" className="lp-btn lp-btn-ghost" onClick={resetGate}>
              Use a different code
            </button>
          </section>
        )}
      </main>
    </div>
  );
}
