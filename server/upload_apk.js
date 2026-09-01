const fs = require('fs');
const path = require('path');

async function uploadApk() {
  const apkPath = path.join(__dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
  if (!fs.existsSync(apkPath)) {
    console.error('APK file not found at:', apkPath);
    process.exit(1);
  }

  const stat = fs.statSync(apkPath);
  console.log(`Uploading APK (${(stat.size / 1024 / 1024).toFixed(2)} MB)...`);

  const fileBuffer = fs.readFileSync(apkPath);
  const fileName = `Flowa-v1.0-release.apk`;
  const folder = 'releases';

  const buckets = ['flowa-4fca9.firebasestorage.app', 'flowa-4fca9.appspot.com'];

  for (const storageBucket of buckets) {
    try {
      console.log(`Trying bucket: ${storageBucket}...`);
      const uploadUrl = `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o?uploadType=media&name=${encodeURIComponent(folder + '/' + fileName)}`;
      
      const uploadRes = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/vnd.android.package-archive',
        },
        body: fileBuffer,
      });

      const uploadData = await uploadRes.json();
      console.log('Upload response:', uploadData);

      if (uploadData.downloadTokens) {
        const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/${encodeURIComponent(folder + '/' + fileName)}?alt=media&token=${uploadData.downloadTokens}`;
        console.log('\n=============================================');
        console.log('SUCCESS! Firebase Storage Download URL:');
        console.log(downloadUrl);
        console.log('=============================================\n');
        return downloadUrl;
      }

      if (uploadData.name) {
        const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/${encodeURIComponent(folder + '/' + fileName)}?alt=media`;
        console.log('\n=============================================');
        console.log('SUCCESS! Firebase Storage Download URL:');
        console.log(downloadUrl);
        console.log('=============================================\n');
        return downloadUrl;
      }
    } catch (err) {
      console.error(`Error with bucket ${storageBucket}:`, err.message);
    }
  }
}

uploadApk();
