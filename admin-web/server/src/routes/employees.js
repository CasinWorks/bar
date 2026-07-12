import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';
import { isSuperAdminEmail } from '../lib/superAdmin.js';

const router = Router();

function randomTempPassword() {
  const chunk = Math.random().toString(36).slice(2, 8);
  return `Tiger-${chunk}!9`;
}

router.get('/', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('employees')
    .select('*, profile:profiles(id, name, email, role)')
    .order('full_name', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ employees: data ?? [] });
});

/**
 * Create a staff login for the mobile app + HR roster row.
 * Returns a one-time temp password for demo handoff.
 */
router.post('/invite', requireAdmin, async (req, res) => {
  const {
    email,
    fullName,
    jobTitle,
    department = 'bar',
    phone,
    hourlyRatePeso,
    role = 'staff',
  } = req.body;

  const normalizedEmail = String(email || '').trim().toLowerCase();
  if (!normalizedEmail || !fullName || !jobTitle) {
    return res.status(400).json({ error: 'Email, full name, and job title are required.' });
  }
  if (isSuperAdminEmail(normalizedEmail)) {
    return res.status(400).json({ error: 'That email is reserved.' });
  }
  if (!['staff', 'hr', 'admin'].includes(role)) {
    return res.status(400).json({ error: 'Role must be staff, hr, or admin.' });
  }
  // Only true admins can mint another admin
  if (role === 'admin' && req.profile.role !== 'admin') {
    return res.status(403).json({ error: 'Only admins can create admin accounts.' });
  }

  const tempPassword = randomTempPassword();

  const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
    email: normalizedEmail,
    password: tempPassword,
    email_confirm: true,
    user_metadata: {
      name: fullName,
      role,
    },
  });

  let userId = created?.user?.id;

  if (createError) {
    // If auth user already exists, look up and upgrade profile + employee row
    const { data: listed } = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 200 });
    const existing = listed?.users?.find(
      (u) => (u.email || '').toLowerCase() === normalizedEmail,
    );
    if (!existing) {
      return res.status(400).json({ error: createError.message });
    }
    userId = existing.id;

    await supabaseAdmin.auth.admin.updateUserById(userId, {
      password: tempPassword,
      user_metadata: { name: fullName, role },
    });
  }

  const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
    id: userId,
    email: normalizedEmail,
    name: fullName,
    role,
  });

  if (profileError) {
    return res.status(500).json({ error: profileError.message });
  }

  const { data: employee, error: empError } = await supabaseAdmin
    .from('employees')
    .upsert(
      {
        profile_id: userId,
        full_name: fullName,
        email: normalizedEmail,
        phone: phone || null,
        job_title: jobTitle,
        department: department || 'floor',
        employment_status: 'active',
        hire_date: new Date().toISOString().slice(0, 10),
        hourly_rate_peso: hourlyRatePeso ? Number(hourlyRatePeso) : null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'profile_id' },
    )
    .select()
    .single();

  // profile_id unique — if upsert unsupported on conflict, insert fallback
  if (empError) {
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('employees')
      .insert({
        profile_id: userId,
        full_name: fullName,
        email: normalizedEmail,
        phone: phone || null,
        job_title: jobTitle,
        department: department || 'floor',
        employment_status: 'active',
        hire_date: new Date().toISOString().slice(0, 10),
        hourly_rate_peso: hourlyRatePeso ? Number(hourlyRatePeso) : null,
      })
      .select()
      .single();

    if (insertError) {
      // Employee row may already exist — still return credentials
      return res.json({
        ok: true,
        userId,
        email: normalizedEmail,
        role,
        tempPassword,
        warning: insertError.message,
      });
    }

    return res.json({
      ok: true,
      userId,
      email: normalizedEmail,
      role,
      tempPassword,
      employee: inserted,
    });
  }

  res.json({
    ok: true,
    userId,
    email: normalizedEmail,
    role,
    tempPassword,
    employee,
  });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    fullName, email, phone, jobTitle, department, employmentStatus,
    hireDate, hourlyRatePeso, emergencyContact, notes, profileId,
  } = req.body;

  if (!fullName || !jobTitle) {
    return res.status(400).json({ error: 'Name and job title required.' });
  }
  if (isSuperAdminEmail(email)) {
    return res.status(400).json({ error: 'That email is reserved.' });
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
