const { db, FieldValue } = require('../utils/firebase');
const { createClient } = require('@supabase/supabase-js');

// Supabase client (server-side: service role key ishlatiladi)
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

function checkAuth(req, res) {
  const secret = req.headers['x-cron-secret'] || req.query['cron_secret'];
  if (secret !== process.env.CRON_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

module.exports = async function handler(req, res) {
  if (!checkAuth(req, res)) return;

  try {
    const now = new Date();
    const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const expiredSessions = await db.collection("proofSessions")
      .where("createdAt", "<", cutoff)
      .where("status", "in", ["completed", "missed"])
      .get();

    let cleaned = 0;

    for (const doc of expiredSessions.docs) {
      const data = doc.data();
      if (!data.rearPhotoUrl && !data.frontPhotoUrl) continue;

      const sessionId = doc.id;
      const filesToDelete = [
        `${sessionId}/rear.jpg`,
        `${sessionId}/front.jpg`,
      ];

      // Supabase storage dan o'chirish
      const { error } = await supabase.storage
        .from('proofs')
        .remove(filesToDelete);

      if (error) {
        console.error(`Storage o'chirish xatosi (${sessionId}):`, error.message);
      }

      await doc.ref.update({
        rearPhotoUrl: FieldValue.delete(),
        frontPhotoUrl: FieldValue.delete(),
        photosDeletedAt: now,
      });

      cleaned++;
    }

    res.status(200).json({ success: true, count: cleaned });
  } catch (error) {
    console.error('Error cleaning up proofs:', error);
    res.status(500).json({ error: error.message });
  }
};
