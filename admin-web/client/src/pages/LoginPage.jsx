import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function LoginPage() {
  const { signIn, profile, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  if (!loading && profile) return <Navigate to="/app" replace />;

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await signIn(email, password);
    } catch (err) {
      setError(err.message || 'Sign in failed');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-page">
      <div className="card login-card">
        <h2 className="page-title">Admin Console</h2>
        <p className="page-sub">Cash desk · time loads · guest list · HR</p>
        {error && <p className="error">{error}</p>}
        <form onSubmit={handleSubmit}>
          <label>Email</label>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          <label>Password</label>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          <button className="btn" type="submit" disabled={busy} style={{ width: '100%' }}>
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
        <p className="page-sub" style={{ marginTop: 16, marginBottom: 0 }}>
          <Link to="/" style={{ color: 'var(--gold, #c5a059)' }}>
            ← Back to welcome
          </Link>
        </p>
      </div>
    </div>
  );
}
