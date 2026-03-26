const fs = require('fs');
const sizes = [72, 96, 128, 144, 152, 192, 384, 512];

function makeSVG(size) {
  const rx = Math.round(size * 0.2);
  const fontSize = Math.round(size * 0.55);
  return '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '">' +
    '<rect width="' + size + '" height="' + size + '" rx="' + rx + '" fill="#1a7a4a"/>' +
    '<text x="50%" y="55%" font-size="' + fontSize + '" text-anchor="middle" dominant-baseline="middle" fill="white">🌿</text>' +
    '</svg>';
}

sizes.forEach(function(s) {
  fs.writeFileSync('icon-' + s + 'x' + s + '.svg', makeSVG(s));
  console.log('icon-' + s + 'x' + s + '.svg');
});

fs.copyFileSync('icon-192x192.svg', 'maskable-192x192.svg');
fs.copyFileSync('icon-512x512.svg', 'maskable-512x512.svg');
console.log('Listo');
