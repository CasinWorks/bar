import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import TimeLoadPage from './pages/TimeLoadPage';
import UsersPage from './pages/UsersPage';
import EventsPage from './pages/EventsPage';
import GuestsPage from './pages/GuestsPage';
import HrPage from './pages/HrPage';

function Protected({ children }) {
  const { session, profile, loading } = useAuth();
  if (loading) return <div className="login-page">Loading…</div>;
  if (!session) return <Navigate to="/login" replace />;
  if (!profile) return <div className="login-page"><p className="error">Access denied — admin or HR role required.</p></div>;
  return children;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/"
            element={
              <Protected>
                <Layout />
              </Protected>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="time-load" element={<TimeLoadPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="events" element={<EventsPage />} />
            <Route path="guests" element={<GuestsPage />} />
            <Route path="hr" element={<HrPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
