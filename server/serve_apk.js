const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const APK_PATH = path.join(__dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'Odat.apk');

const server = http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  
  if (req.url === '/' || req.url === '/Odat.apk' || req.url === '/app-release.apk' || req.url === '/download') {
    if (!fs.existsSync(APK_PATH)) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('APK topilmadi');
    }

    const stat = fs.statSync(APK_PATH);
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': stat.size,
      'Content-Disposition': 'attachment; filename="Odat.apk"',
      'Access-Control-Allow-Origin': '*',
    });

    const readStream = fs.createReadStream(APK_PATH);
    readStream.pipe(res);
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>ODAT APK Yuklab Olish</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #07090E; color: white; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
          .card { background: #101624; border: 1px solid #00F3FF; padding: 32px; border-radius: 24px; box-shadow: 0 10px 40px rgba(0,243,255,0.2); max-width: 90%; width: 400px; }
          h1 { color: #00F3FF; margin-top: 0; }
          .btn { display: inline-block; background: #39FF14; color: black; font-weight: 900; font-size: 18px; padding: 16px 28px; border-radius: 14px; text-decoration: none; margin-top: 20px; box-shadow: 0 4px 20px rgba(57,255,20,0.4); }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>🔥 ODAT (ARM64)</h1>
          <p>Yangi versiya tayyor!</p>
          <a class="btn" href="/Odat.apk">Yuklab Olish (APK)</a>
        </div>
      </body>
      </html>
    `);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`APK Server running at http://0.0.0.0:${PORT}/`);
});
