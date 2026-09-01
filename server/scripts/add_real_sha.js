const fs = require('fs');
const https = require('https');

const conf = JSON.parse(fs.readFileSync('C:\\Users\\User\\.config\\configstore\\firebase-tools.json', 'utf8'));
const token = conf.tokens.access_token;
const projectId = 'flowa-4fca9';

function makeRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firebase.googleapis.com',
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
          resolve({ status: res.statusCode, data: JSON.parse(data) });
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

async function addShaKeys() {
  const appsRes = await makeRequest('GET', '/v1beta1/projects/' + projectId + '/androidApps');
  const app = appsRes.data.apps.find(a => a.packageName === 'com.company.flova') || appsRes.data.apps[0];
  const appName = app.name;
  console.log('Target app:', appName, app.packageName);

  const keysToAdd = [
    { shaHash: '5A:C2:BC:A3:8D:CB:C3:45:2E:E5:E5:B7:7F:AC:50:A2:CC:1C:47:42', certType: 'SHA_1' },
    { shaHash: '55:69:2F:70:95:72:9D:BA:E2:DF:A0:1E:82:F5:DD:A2:5F:C3:E7:EB', certType: 'SHA_1' },
    { shaHash: 'C8:DF:B6:DF:DB:A7:95:FE:7C:6D:74:0A:E5:FD:6C:B5:D6:B3:13:CE:14:41:DE:C7:61:D4:96:73:66:6D:D8:CA', certType: 'SHA_256' },
    { shaHash: '11:70:3E:03:64:19:E3:E4:21:17:52:25:B3:C9:37:2E:AC:CC:41:E7:0A:AA:05:BF:83:FB:DE:82:51:C4:68:DB', certType: 'SHA_256' }
  ];

  for (const k of keysToAdd) {
    const res = await makeRequest('POST', '/v1beta1/' + appName + '/sha', k);
    console.log(`Add ${k.certType} (${k.shaHash}): Status ${res.status}`);
  }
}

addShaKeys();
