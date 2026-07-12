import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../lib/api';

export default function HrPage() {
  const { token } = useAuth();
  const [employees, setEmployees] = useState([]);
  const [fullName, setFullName] = useState('');
  const [jobTitle, setJobTitle] = useState('');
  const [department, setDepartment] = useState('bar');
  const [email, setEmail] = useState('');
  const [hourlyRatePeso, setHourlyRatePeso] = useState('');
  const [err, setErr] = useState('');

  async function load() {
    const data = await api('/api/employees', { token });
    setEmployees(data.employees);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [token]);

  async function addEmployee(e) {
    e.preventDefault();
    try {
      await api('/api/employees', {
        method: 'POST',
        token,
        body: { fullName, jobTitle, department, email, hourlyRatePeso: Number(hourlyRatePeso) || null },
      });
      setFullName('');
      setJobTitle('');
      setEmail('');
      setHourlyRatePeso('');
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  async function setStatus(id, employmentStatus) {
    await api(`/api/employees/${id}`, { method: 'PATCH', token, body: { employmentStatus } });
    await load();
  }

  return (
    <>
      <h2 className="page-title">HR & Employment</h2>
      <p className="page-sub">Staff roster — door, bar, floor, management</p>
      {err && <p className="error">{err}</p>}

      <div className="card">
        <h3 style={{ marginTop: 0 }}>Add employee</h3>
        <form onSubmit={addEmployee}>
          <div className="form-row">
            <div><label>Full name</label><input value={fullName} onChange={(e) => setFullName(e.target.value)} required /></div>
            <div><label>Job title</label><input value={jobTitle} onChange={(e) => setJobTitle(e.target.value)} required /></div>
          </div>
          <div className="form-row">
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
            <div><label>Hourly rate (₱)</label><input type="number" value={hourlyRatePeso} onChange={(e) => setHourlyRatePeso(e.target.value)} /></div>
          </div>
          <label>Email</label>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <button className="btn" type="submit">Add employee</button>
        </form>
      </div>

      <div className="card">
        <table>
          <thead><tr><th>Name</th><th>Title</th><th>Dept</th><th>Status</th><th>Rate</th><th>Actions</th></tr></thead>
          <tbody>
            {employees.map((emp) => (
              <tr key={emp.id}>
                <td>{emp.full_name}</td>
                <td>{emp.job_title}</td>
                <td>{emp.department}</td>
                <td><span className="badge badge-gold">{emp.employment_status}</span></td>
                <td>{emp.hourly_rate_peso ? `₱${emp.hourly_rate_peso}/hr` : '—'}</td>
                <td>
                  {emp.employment_status !== 'terminated' && (
                    <button className="btn btn-sm btn-danger" onClick={() => setStatus(emp.id, 'terminated')}>Terminate</button>
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
