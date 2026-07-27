const { db } = require('../utils/firebase');

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
  res.status(200).json({ success: true, message: 'No-op: Storage proofs are disabled' });
};
