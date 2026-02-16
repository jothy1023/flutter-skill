var http = require('http');
var fs = require('fs');
var path = require('path');

var PORT = process.env.PORT || 3000;
var MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon'
};

http.createServer(function (req, res) {
  var url = req.url.split('?')[0];
  if (url === '/') url = '/index.html';

  // Serve SDK files from sdks/web/
  var filePath;
  if (url.indexOf('/sdks/') === 0) {
    filePath = path.join(__dirname, '..', '..', '..', url);
  } else {
    filePath = path.join(__dirname, url);
  }

  var ext = path.extname(filePath);
  fs.readFile(filePath, function (err, data) {
    if (err) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    res.end(data);
  });
}).listen(PORT, function () {
  console.log('Web test app running at http://localhost:' + PORT);
});
