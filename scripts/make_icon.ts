import { createCanvas, Canvas } from "@napi-rs/canvas";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const resourcesDir = path.join(root, "Resources");
const iconsetDir = path.join(resourcesDir, "AppIcon.iconset");
const icnsPath = path.join(resourcesDir, "AppIcon.icns");

const sizes = [16, 32, 128, 256, 512];

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

export function drawIcon(size: number): Canvas {
  const scale = size / 1024;
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext("2d");

  const radius = Math.round(210 * scale);

  // Outer rounded rectangle clip
  ctx.save();
  ctx.beginPath();
  ctx.roundRect(0, 0, size, size, radius);
  ctx.clip();

  // Vertical gradient background
  const bgGrad = ctx.createLinearGradient(0, 0, 0, size);
  bgGrad.addColorStop(0, "rgb(56, 173, 240)");
  bgGrad.addColorStop(1, "rgb(156, 97, 228)");
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, size, size);

  // Glow ellipse 1
  ctx.beginPath();
  ctx.ellipse(
    220 * scale,
    225 * scale,
    370 * scale,
    335 * scale,
    0,
    0,
    Math.PI * 2
  );
  ctx.fillStyle = "rgba(108, 223, 255, 0.306)";
  ctx.fill();

  // Glow ellipse 2
  ctx.beginPath();
  ctx.ellipse(
    775 * scale,
    760 * scale,
    415 * scale,
    400 * scale,
    0,
    0,
    Math.PI * 2
  );
  ctx.fillStyle = "rgba(131, 82, 235, 0.373)";
  ctx.fill();

  // Center panel
  const inset = 150 * scale;
  const panelSize = size - 2 * inset;
  ctx.beginPath();
  ctx.roundRect(inset, inset, panelSize, panelSize, 150 * scale);
  ctx.fillStyle = "rgba(21, 28, 48, 0.961)";
  ctx.fill();

  // Panel inner border
  const borderOffset = inset + 24 * scale;
  const borderSize = size - 2 * borderOffset;
  ctx.beginPath();
  ctx.roundRect(borderOffset, borderOffset, borderSize, borderSize, 126 * scale);
  ctx.lineWidth = Math.max(1, 5 * scale);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.098)";
  ctx.stroke();

  // Letter "Q"
  const fontSize = Math.round(485 * scale);
  ctx.font = `bold ${fontSize}px "Arial Bold", Arial, -apple-system, sans-serif`;
  ctx.fillStyle = "rgba(250, 253, 255, 1.0)";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("Q", size / 2 - 7 * scale, size / 2 - 28 * scale);

  // Badge outer circle
  ctx.beginPath();
  ctx.arc(923.5 * scale, 923.5 * scale, 178.5 * scale, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(255, 202, 68, 1.0)";
  ctx.fill();

  // Badge inner circle
  ctx.beginPath();
  ctx.arc(893 * scale, 893 * scale, 39 * scale, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(255, 232, 142, 0.824)";
  ctx.fill();

  ctx.restore();

  return canvas;
}

export async function buildIcnsBinary(
  baseCanvas: Canvas,
  targetPath: string
): Promise<void> {
  const chunks: Array<{ type: string; size: number }> = [
    { type: "icp4", size: 16 },
    { type: "icp5", size: 32 },
    { type: "icp6", size: 64 },
    { type: "ic07", size: 128 },
    { type: "ic08", size: 256 },
    { type: "ic09", size: 512 },
    { type: "ic10", size: 1024 },
  ];

  const payloadChunks = await Promise.all(
    chunks.map(async (chunk) => {
      const resizedCanvas = createCanvas(chunk.size, chunk.size);
      const ctx = resizedCanvas.getContext("2d");
      ctx.drawImage(baseCanvas, 0, 0, chunk.size, chunk.size);
      const pngBuffer = await resizedCanvas.encode("png");

      const header = Buffer.alloc(8);
      header.write(chunk.type, 0, 4, "ascii");
      header.writeUInt32BE(pngBuffer.length + 8, 4);

      return Buffer.concat([header, pngBuffer]);
    })
  );

  const payload = Buffer.concat(payloadChunks);
  const fileHeader = Buffer.alloc(8);
  fileHeader.write("icns", 0, 4, "ascii");
  fileHeader.writeUInt32BE(payload.length + 8, 4);

  const finalBuffer = Buffer.concat([fileHeader, payload]);
  await fs.writeFile(targetPath, finalBuffer);
}

export async function generateIcons(): Promise<void> {
  console.log("Generating app icons...");
  await fs.mkdir(iconsetDir, { recursive: true });

  // Clear existing pngs in iconset asynchronously
  const files = await fs.readdir(iconsetDir);
  await Promise.all(
    files
      .filter((file) => file.endsWith(".png"))
      .map((file) => fs.unlink(path.join(iconsetDir, file)))
  );

  const baseCanvas = drawIcon(1024);

  // Generate multi-scale PNG icons concurrently
  await Promise.all(
    sizes.flatMap((size) => {
      // 1x
      const task1x = (async () => {
        const canvas1x = createCanvas(size, size);
        const ctx1x = canvas1x.getContext("2d");
        ctx1x.drawImage(baseCanvas, 0, 0, size, size);
        const buffer1x = await canvas1x.encode("png");
        await fs.writeFile(
          path.join(iconsetDir, `icon_${size}x${size}.png`),
          buffer1x
        );
      })();

      // 2x Retina
      const task2x = (async () => {
        const retinaSize = size * 2;
        const canvas2x = createCanvas(retinaSize, retinaSize);
        const ctx2x = canvas2x.getContext("2d");
        ctx2x.drawImage(baseCanvas, 0, 0, retinaSize, retinaSize);
        const buffer2x = await canvas2x.encode("png");
        await fs.writeFile(
          path.join(iconsetDir, `icon_${size}x${size}@2x.png`),
          buffer2x
        );
      })();

      return [task1x, task2x];
    })
  );

  // Generate ICNS using iconutil if available, otherwise pure async binary
  let generatedViaIconutil = false;
  try {
    await execFileAsync("iconutil", ["-c", "icns", iconsetDir, "-o", icnsPath]);
    generatedViaIconutil = true;
  } catch {
    generatedViaIconutil = false;
  }

  if (!generatedViaIconutil) {
    await buildIcnsBinary(baseCanvas, icnsPath);
  }

  console.log(`Icons successfully generated at ${icnsPath}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  await generateIcons();
}
