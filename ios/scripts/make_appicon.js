// Generates a 1024x1024 RGB PNG (no alpha) AppIcon.
// Design: warm orange background, centered dark-red bite/paw wedge, white accent ring.
// Run: node ios/scripts/make_appicon.js <out.png>
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const SIZE = 1024;
const outPath = process.argv[2] || path.join(__dirname, "..", "BiteDefense", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png");

// Colors (sRGB, no alpha)
const BG_TOP = [0xf9, 0x73, 0x16];    // orange-500
const BG_BOT = [0x99, 0x1b, 0x1b];    // red-900
const RING   = [0xff, 0xff, 0xff];    // white
const BITE   = [0x7f, 0x1d, 0x1d];    // red-800

function lerp(a, b, t) { return Math.round(a + (b - a) * t); }
function mix(c1, c2, t) { return [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)]; }

// Each row: filter byte (0) + SIZE * 3 bytes RGB
const row = SIZE * 3 + 1;
const raw = Buffer.alloc(row * SIZE);

const cx = SIZE / 2, cy = SIZE / 2;
const ringOuter = 430;
const ringInner = 380;
// Bite = a circle subtracted from the top-right of the ring
const biteCx = cx + 300;
const biteCy = cy - 260;
const biteR = 230;

for (let y = 0; y < SIZE; y++) {
  raw[y * row] = 0; // filter: None
  const t = y / (SIZE - 1);
  const bg = mix(BG_TOP, BG_BOT, t);
  for (let x = 0; x < SIZE; x++) {
    const dx = x - cx, dy = y - cy;
    const d = Math.sqrt(dx * dx + dy * dy);
    const bdx = x - biteCx, bdy = y - biteCy;
    const bd = Math.sqrt(bdx * bdx + bdy * bdy);

    let c = bg;
    if (d <= ringOuter && d >= ringInner && bd > biteR) {
      c = RING;
    } else if (d < ringInner && bd > biteR + 6) {
      // inner disk (slight tint for depth)
      c = mix(bg, [0, 0, 0], 0.25);
    } else if (bd <= biteR && d <= ringOuter) {
      c = BITE;
    }

    const off = y * row + 1 + x * 3;
    raw[off] = c[0];
    raw[off + 1] = c[1];
    raw[off + 2] = c[2];
  }
}

// ---- PNG assembly ----
function crc32(buf) {
  let c;
  const table = crc32.table || (crc32.table = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      t[n] = c >>> 0;
    }
    return t;
  })());
  c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);      // width
ihdr.writeUInt32BE(SIZE, 4);      // height
ihdr[8] = 8;                      // bit depth
ihdr[9] = 2;                      // color type RGB
ihdr[10] = 0;                     // compression
ihdr[11] = 0;                     // filter
ihdr[12] = 0;                     // interlace

const idat = zlib.deflateSync(raw, { level: 9 });

const png = Buffer.concat([
  sig,
  chunk("IHDR", ihdr),
  chunk("IDAT", idat),
  chunk("IEND", Buffer.alloc(0)),
]);

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, png);
console.log(`Wrote ${outPath} (${png.length} bytes)`);
