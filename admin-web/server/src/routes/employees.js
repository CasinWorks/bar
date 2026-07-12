import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

router.get('/', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('employees')
    .select('*, profile:profiles(id, name, email, role)')
    .order('full_name', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ employees: data });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    fullName, email, phone, jobTitle, department, employmentStatus,
    hireDate, hourlyRatePeso, emergencyContact, notes, profileId,
  } = req.body;

  if (!fullName || !jobTitle) {
    return res.status(400).json({ error: 'Name and job title required.' });
  }

  const { data, error } = await supabaseAdmin
    .from('employees')
    .insert({
      full_name: fullName,
      email: email || null,
      phone: phone || null,
      job_title: jobTitle,
      department: department || 'floor',
      employment_status: employmentStatus || 'active',
      hire_date: hireDate || null,
      hourly_rate_peso: hourlyRatePeso ? Number(hourlyRatePeso) : null,
      emergency_contact: emergencyContact || null,
      notes: notes || null,
      profile_id: profileId || null,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ employee: data });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const map = {
    fullName: 'full_name',
    email: 'email',
    phone: 'phone',
    jobTitle: 'job_title',
    department: 'department',
    employmentStatus: 'employment_status',
    hireDate: 'hire_date',
    hourlyRatePeso: 'hourly_rate_peso',
    emergencyContact: 'emergency_contact',
    notes: 'notes',
    profileId: 'profile_id',
  };
  const patch = { updated_at: new Date().toISOString() };
  for (const [k, col] of Object.entries(map)) {
    if (req.body[k] !== undefined) patch[col] = req.body[k];
  }

  const { data, error } = await supabaseAdmin
    .from('employees')
    .update(patch)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ employee: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabaseAdmin.from('employees').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
