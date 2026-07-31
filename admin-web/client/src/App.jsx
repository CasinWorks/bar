import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import AppLoader from './components/AppLoader';
import Layout from './components/Layout';
import LandingPage from './pages/LandingPage';
import DownloadPage from './pages/DownloadPage';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import PlatformPage from './pages/PlatformPage';
import TimeLoadPage from './pages/TimeLoadPage';
import PackagesPage from './pages/PackagesPage';
import UsersPage from './pages/UsersPage';
import EventsPage from './pages/EventsPage';
import GuestsPage from './pages/GuestsPage';
import HrPage from './pages/HrPage';
import SafetySocialPage from './pages/SafetySocialPage';
import BranchesPage from './pages/BranchesPage';
import DownloadInvitesPage from './pages/DownloadInvitesPage';
import DrinksPage from './pages/DrinksPage';

function Protected({ children }) {
  const { session, profile, loading, accessError, signOut } = useAuth();
  if (loading) return <AppLoader label="Opening admin suite…" />;
  if (!session) return <Navigate to="/login" replace />;
  if (!profile) {
    return (
      <div className="login-page">
        <div className="login-card card">
          <p className="error">{accessError || 'Access denied — admin or HR role required.'}</p>
          <p className="page-sub">Sign out and try again after your role is set to admin.</p>
          <button type="button" className="btn" onClick={() => signOut()}>
            Sign out
          </button>
        </div>
      </div>
    );
  }
  return children;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/download" element={<DownloadPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/app"
            element={
              <Protected>
                <Layout />
              </Protected>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="platform" element={<PlatformPage />} />
            <Route path="time-load" element={<TimeLoadPage />} />
            <Route path="packages" element={<PackagesPage />} />
            <Route path="drinks" element={<DrinksPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="events" element={<EventsPage />} />
            <Route path="guests" element={<GuestsPage />} />
            <Route path="branches" element={<BranchesPage />} />
            <Route path="download-invites" element={<DownloadInvitesPage />} />
            <Route path="safety-social" element={<SafetySocialPage />} />
            <Route path="hr" element={<HrPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
