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

async function addSha() {
  const appsRes = await makeRequest('GET', '/v1beta1/projects/' + projectId + '/androidApps');
  console.log('Apps:', JSON.stringify(appsRes.data, null, 2));
  if (!appsRes.data.apps || appsRes.data.apps.length === 0) {
    console.log('No apps found');
    return;
  }
  const app = appsRes.data.apps.find(a => a.packageName === 'com.company.flova') || appsRes.data.apps[0];
  const appName = app.name; // projects/flowa-4fca9/androidApps/APP_ID
  console.log('Target app:', appName, app.packageName);

  const shaCertificate = {
    shaHash: '77:4E:0D:8F:45:F0:C3:B7:FA:CF:EB:E5:86:80:57:86:E1:2C:77:D9',
    certType: 'SHA_1'
  };

  const addRes = await makeRequest('POST', '/v1beta1/' + appName + '/sha', shaCertificate);
  console.log('Add SHA result:', addRes.status, JSON.stringify(addRes.data, null, 2));
}

addSha();
