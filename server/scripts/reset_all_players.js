const fs = require('fs');
const https = require('https');

// Read access token from firebase-tools config
const conf = JSON.parse(fs.readFileSync('C:\\Users\\User\\.config\\configstore\\firebase-tools.json', 'utf8'));
const token = conf.tokens.access_token;
const projectId = 'flowa-4fca9';

function makeRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path: path,
      method: method,
      headers: {
        'Authorization': 'Bearer ' + token,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : {};
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function getAllDocuments(collectionName) {
  let docs = [];
  let pageToken = '';
  do {
    let url = `/v1/projects/${projectId}/databases/(default)/documents/${collectionName}?pageSize=300`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const res = await makeRequest('GET', url);
    if (res.data.documents) {
      docs = docs.concat(res.data.documents);
    }
    pageToken = res.data.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function resetUsers() {
  console.log('🔄 Barcha o‘yinchilar ro‘yxati olinmoqda...');
  const users = await getAllDocuments('users');
  console.log(`📊 Jami ${users.length} ta foydalanuvchi topildi.`);

  let updated = 0;
  for (const doc of users) {
    const docPath = doc.name; // e.g. projects/flowa-4fca9/databases/(default)/documents/users/UID
    const fieldsToUpdate = {
      totalPoints: { integerValue: "0" },
      weeklyPoints: { integerValue: "0" },
      monthlyPoints: { integerValue: "0" },
      totalFocusMinutes: { integerValue: "0" },
      weeklyFocusMinutes: { integerValue: "0" },
      monthlyFocusMinutes: { integerValue: "0" },
      totalDeepSessions: { integerValue: "0" },
      streak: { integerValue: "0" },
      longestStreak: { integerValue: "0" },
      fenixCoins: { integerValue: "0" },
      freezes: { integerValue: "0" },
      battleWins: { integerValue: "0" },
      battleLosses: { integerValue: "0" },
      totalRunningKm: { doubleValue: 0.0 },
      likesCount: { integerValue: "0" },
      earnedBadges: { arrayValue: { values: [] } },
      claimedBadges: { arrayValue: { values: [] } }
    };

    const updateMask = Object.keys(fieldsToUpdate).map(f => `updateMask.fieldPaths=${f}`).join('&');
    const updateUrl = `/v1/${docPath}?${updateMask}`;

    const res = await makeRequest('PATCH', updateUrl, { fields: fieldsToUpdate });
    if (res.status === 200) {
      updated++;
      const name = doc.fields?.name?.stringValue || doc.fields?.displayName?.stringValue || 'User';
      console.log(`✅ [${updated}/${users.length}] Nollashtirildi: ${name}`);
    } else {
      console.error(`❌ Xatolik (${docPath}):`, res.status, res.data);
    }
  }
  console.log(`\n🎉 Muvaffaqiyatli: ${updated} ta o‘yinchi ma'lumotlari 0 ga tushirildi!`);
}

async function resetClans() {
  console.log('\n🔄 Klanlar statistikasi nollashtirilmoqda...');
  const clans = await getAllDocuments('clans');
  console.log(`🏰 Jami ${clans.length} ta klan topildi.`);
  for (const clan of clans) {
    const docPath = clan.name;
    const fieldsToUpdate = {
      totalPoints: { integerValue: "0" },
      weeklyPoints: { integerValue: "0" },
      totalFocusMinutes: { integerValue: "0" },
      territoriesCount: { integerValue: "0" }
    };
    const updateMask = Object.keys(fieldsToUpdate).map(f => `updateMask.fieldPaths=${f}`).join('&');
    await makeRequest('PATCH', `/v1/${docPath}?${updateMask}`, { fields: fieldsToUpdate });
    console.log(`✅ Klan nollashtirildi: ${clan.fields?.name?.stringValue || 'Clan'}`);
  }
}

async function main() {
  try {
    await resetUsers();
    await resetClans();
    console.log('\n🚀 Barcha o‘yinchilar va klanlar 0 dan boshlashga tayyor!');
  } catch (err) {
    console.error('Xatolik yuz berdi:', err);
  }
}

main();
