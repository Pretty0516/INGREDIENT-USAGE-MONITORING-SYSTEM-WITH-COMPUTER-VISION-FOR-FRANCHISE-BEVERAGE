import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import nodemailer from 'nodemailer';

admin.initializeApp();
const db = admin.firestore();

function hash(s: string) {
  return crypto.createHash('sha256').update(s).digest('hex');
}

function cors(res: functions.Response) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

export const sendOtp = functions.region('asia-southeast1').https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ message: 'method not allowed' });
  const { channel, email, phone, context } = req.body || {};
  if (!channel || (channel === 'email' && !email) || (channel === 'sms' && !phone)) {
    return res.status(400).json({ message: 'invalid input' });
  }
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 60 * 1000));
  const target = channel === 'email' ? String(email).toLowerCase().trim() : String(phone);
  const doc = await db.collection('otp_requests').add({
    channel,
    target,
    context: context || 'login',
    codeHash: hash(code),
    expiresAt,
    attempts: 0,
    used: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  if (channel === 'email') {
    const user = functions.config().mail?.user;
    const pass = functions.config().mail?.pass;
    if (!user || !pass) return res.status(500).json({ message: 'mail config missing' });
    const transporter = nodemailer.createTransport({ service: 'gmail', auth: { user, pass } });
    const html = `<p>Your OTP is <b>${code}</b>. It expires in 5 minutes.</p>`;
    await transporter.sendMail({ from: user, to: target, subject: 'Your verification code', html });
  }
  return res.status(200).json({ requestId: doc.id, message: 'sent' });
});

export const verifyOtp = functions.region('asia-southeast1').https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ message: 'method not allowed' });
  const { requestId, code } = req.body || {};
  if (!requestId || !code) return res.status(400).json({ valid: false, message: 'invalid input' });
  const ref = db.collection('otp_requests').doc(String(requestId));
  const snap = await ref.get();
  if (!snap.exists) return res.status(404).json({ valid: false, message: 'not found' });
  const d = snap.data()!;
  if (d.used) return res.status(400).json({ valid: false, message: 'already used' });
  if (d.expiresAt.toDate() < new Date()) return res.status(400).json({ valid: false, message: 'expired' });
  const attempts = (d.attempts || 0) + 1;
  if (attempts > 5) return res.status(429).json({ valid: false, message: 'too many attempts' });
  const ok = d.codeHash === hash(String(code));
  await ref.update({ attempts, used: ok });
  return res.status(200).json({ valid: ok, message: ok ? 'ok' : 'invalid' });
});

export const resetPasswordViaEmailOtp = functions.region('asia-southeast1').https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ message: 'method not allowed' });
  const { email, newPassword } = req.body || {};
  if (!email || !newPassword) return res.status(400).json({ message: 'invalid input' });
  const e = String(email).toLowerCase().trim();
  try {
    const vref = db.collection('email_verifications').doc(e);
    const vsnap = await vref.get();
    if (!vsnap.exists) return res.status(404).json({ message: 'verification not found' });
    const v = vsnap.data()!;
    if (v.status !== 'verified') return res.status(400).json({ message: 'not verified' });
    const exp = v.expiresAt?.toDate?.() ?? new Date(0);
    if (exp < new Date()) return res.status(400).json({ message: 'code expired' });
    const user = await admin.auth().getUserByEmail(e);
    const hashedNew = crypto.createHash('sha256').update(String(newPassword)).digest('hex');
    await admin.auth().updateUser(user.uid, { password: String(newPassword) });
    await db.collection('users').doc(user.uid).update({
      status: 'active',
      isTemporaryPassword: false,
      'metadata.hashedPassword': hashedNew,
      'metadata.lastPasswordUpdatedAt': admin.firestore.FieldValue.serverTimestamp(),
      'metadata.hashedTempPassword': admin.firestore.FieldValue.delete(),
    });
    await vref.update({ status: 'used' });
    return res.status(200).json({ message: 'password updated' });
  } catch (err) {
    return res.status(500).json({ message: 'failed', error: String(err) });
  }
});
