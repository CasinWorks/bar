import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { api } from '../lib/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [accessError, setAccessError] = useState('');

  async function loadProfile(token) {
    try {
      const data = await api('/api/dashboard/me', { token });
      setProfile(data.profile);
      setAccessError('');
      return data.profile;
    } catch (e) {
      setProfile(null);
      setAccessError(e.message || 'Admin or HR role required.');
      return null;
    }
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (data.session) loadProfile(data.session.access_token).finally(() => setLoading(false));
      else setLoading(false);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
      if (s) loadProfile(s.access_token);
      else {
        setProfile(null);
        setAccessError('');
      }
    });

    return () => sub.subscription.unsubscribe();
  }, []);

  const value = {
    session,
    profile,
    loading,
    accessError,
    token: session?.access_token,
    async signIn(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      const nextProfile = await loadProfile(data.session.access_token);
      if (!nextProfile) {
        // Re-read last error from a direct call for a precise message
        try {
          await api('/api/dashboard/me', { token: data.session.access_token });
        } catch (apiErr) {
          throw new Error(apiErr.message || 'Admin or HR role required.');
        }
        throw new Error('Admin or HR role required.');
      }
      return data;
    },
    async signOut() {
      await supabase.auth.signOut();
      setProfile(null);
      setAccessError('');
    },
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
