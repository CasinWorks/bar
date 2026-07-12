import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../lib/api';

export default function HrPage() {
  const { token, profile } = useAuth();
  const [employees, setEmployees] = useState([]);
  const [fullName, setFullName] = useState('');
  const [jobTitle, setJobTitle] = useState('');
  const [department, setDepartment] = useState('bar');
  const [email, setEmail] = useState('');
  const [hourlyRatePeso, setHourlyRatePeso] = useState('');
  const [role, setRole] = useState('staff');
  const [err, setErr] = useState('');
  const [msg, setMsg] = useState('');
  const [inviteResult, setInviteResult] = useState(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    const data = await api('/api/employees', { token });
    setEmployees(data.employees);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token]);

  async function inviteEmployee(e) {
    e.preventDefault();
    setErr('');
    setMsg('');
    setInviteResult(null);
    setBusy(true);
    try {
      const result = await api('/api/employees/invite', {
        method: 'POST',
        token,
        body: {
          fullName,
          jobTitle,
          department,
          email,
          hourlyRatePeso: Number(hourlyRatePeso) || null,
          role,
        },
      });
      setInviteResult(result);
      setMsg(`Created ${result.role} login for ${result.email}`);
      setFullName('');
      setJobTitle('');
      setEmail('');
      setHourlyRatePeso('');
      setRole('staff');
      await load();
    } catch (e) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function setStatus(id, employmentStatus) {
    await api(`/api/employees/${id}`, { method: 'PATCH', token, body: { employmentStatus } });
    await load();
  }

  return (
    <>
      <h2 className="page-title">HR & Employment</h2>
      <p className="page-sub">Create staff emails for the mobile app — door, bar, floor, management</p>
      {err && <p className="error">{err}</p>}
      {msg && <p className="success">{msg}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Add employee email</h3>
        <p className="page-sub" style={{ marginBottom: 12 }}>
          Creates a login for the Flutter app and adds them to the HR roster. Copy the temp password for your demo.
        </p>
        <form onSubmit={inviteEmployee}>
          <div className="form-row">
            <div>
              <label>Full name</label>
              <input value={fullName} onChange={(e) => setFullName(e.target.value)} required placeholder="Juan Dela Cruz" />
            </div>
            <div>
              <label>Work email</label>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required placeholder="bartender@blindtiger.ph" />
            </div>
          </div>
          <div className="form-row">
            <div>
              <label>Job title</label>
              <input value={jobTitle} onChange={(e) => setJobTitle(e.target.value)} required placeholder="Bartender" />
            </div>
            <div>
              <label>Department</label>
              <select value={department} onChange={(e) => setDepartment(e.target.value)}>
                <option value="door">Door</option>
                <option value="bar">Bar</option>
                <option value="floor">Floor</option>
                <option value="management">Management</option>
                <option value="hr">HR</option>
              </select>
            </div>
          </div>
          <div className="form-row">
            <div>
              <label>App role</label>
              <select value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="staff">Staff (mobile door / tip pad)</option>
                <option value="hr">HR (admin web)</option>
                {profile?.role === 'admin' && <option value="admin">Admin (full web)</option>}
              </select>
            </div>
            <div>
              <label>Hourly rate (₱)</label>
              <input type="number" value={hourlyRatePeso} onChange={(e) => setHourlyRatePeso(e.target.value)} placeholder="Optional" />
            </div>
          </div>
          <button className="btn" type="submit" disabled={busy}>
            {busy ? 'Creating…' : 'Create employee login'}
          </button>
        </form>

        {inviteResult?.tempPassword && (
          <div className="load-preview" style={{ marginTop: 16 }}>
            <div>
              <span className="stat-label">Email</span>
              <div className="stat-value" style={{ fontSize: 16 }}>{inviteResult.email}</div>
            </div>
            <div>
              <span className="stat-label">Temp password — share for demo</span>
              <div className="stat-value" style={{ fontSize: 16 }}>{inviteResult.tempPassword}</div>
            </div>
          </div>
        )}
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Roster</h3>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Title</th>
              <th>Dept</th>
              <th>Status</th>
              <th>Rate</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {employees.map((emp) => (
              <tr key={emp.id}>
                <td>{emp.full_name}</td>
                <td>{emp.email || '—'}</td>
                <td>{emp.job_title}</td>
                <td>{emp.department}</td>
                <td><span className="badge badge-gold">{emp.employment_status}</span></td>
                <td>{emp.hourly_rate_peso ? `₱${emp.hourly_rate_peso}/hr` : '—'}</td>
                <td>
                  {emp.employment_status !== 'terminated' && (
                    <button className="btn btn-sm btn-danger" onClick={() => setStatus(emp.id, 'terminated')}>
                      Terminate
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
