import { execFile, spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { generateIcons } from "./make_icon.ts";

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");

const buildDir = path.join(root, "build");
const appDir = path.join(buildDir, "QuickRightMenu.app");
const extDir = path.join(
  appDir,
  "Contents",
  "PlugIns",
  "QuickRightMenu Extension.appex"
);
const moduleCacheDir = path.join(buildDir, "ModuleCache");
const resourcesDir = path.join(root, "Resources");
const icnsPath = path.join(resourcesDir, "AppIcon.icns");

export interface BuildOptions {
  runAfterBuild?: boolean;
  forceIcon?: boolean;
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function runCommand(command: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: "inherit" });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(
          new Error(
            `Command failed with exit code ${code}: ${command} ${args.join(" ")}`
          )
        );
      }
    });
  });
}

export async function build(options: BuildOptions = {}): Promise<void> {
  const startTime = Date.now();
  console.log("=== Building QuickRightMenu ===");

  // 1. Icon generation check
  const iconExists = await pathExists(icnsPath);
  if (options.forceIcon || !iconExists) {
    console.log("[1/6] Icon not found or regeneration requested, creating icon...");
    await generateIcons();
  } else {
    console.log("[1/6] App icon found, skipping icon generation.");
  }

  // 2. Prepare build structure asynchronously
  console.log("[2/6] Preparing build directories...");
  await fs.rm(buildDir, { recursive: true, force: true });

  const dirsToCreate = [
    path.join(appDir, "Contents", "MacOS"),
    path.join(appDir, "Contents", "Resources"),
    path.join(appDir, "Contents", "PlugIns"),
    path.join(extDir, "Contents", "MacOS"),
    path.join(extDir, "Contents", "Resources"),
    moduleCacheDir,
  ];

  await Promise.all(
    dirsToCreate.map((dir) => fs.mkdir(dir, { recursive: true }))
  );

  // 3. Copy resources asynchronously
  console.log("[3/6] Copying plists and assets...");
  const copyTasks = [
    fs.copyFile(
      path.join(resourcesDir, "AppInfo.plist"),
      path.join(appDir, "Contents", "Info.plist")
    ),
    fs.copyFile(
      path.join(resourcesDir, "ExtensionInfo.plist"),
      path.join(extDir, "Contents", "Info.plist")
    ),
  ];

  if (await pathExists(icnsPath)) {
    copyTasks.push(
      fs.copyFile(
        icnsPath,
        path.join(appDir, "Contents", "Resources", "AppIcon.icns")
      )
    );
  }

  await Promise.all(copyTasks);

  // 4. Locate macOS SDK asynchronously
  const { stdout: sdkOutput } = await execFileAsync("xcrun", [
    "--sdk",
    "macosx",
    "--show-sdk-path",
  ]);
  const sdkPath = sdkOutput.trim();
  const arch = process.arch === "arm64" ? "arm64" : "x86_64";
  const target = `${arch}-apple-macos27.0`;

  // 5. Compile Swift sources asynchronously
  console.log(`[4/6] Compiling main application (Target: ${target})...`);
  const appExecutable = path.join(appDir, "Contents", "MacOS", "QuickRightMenu");
  await runCommand("swiftc", [
    "-sdk",
    sdkPath,
    "-target",
    target,
    "-O",
    path.join(root, "Sources", "App", "QuickRightMenuApp.swift"),
    path.join(root, "Sources", "App", "SettingsView.swift"),
    "-o",
    appExecutable,
  ]);

  console.log(`[5/6] Compiling Finder extension (Target: ${target})...`);
  const extExecutable = path.join(
    extDir,
    "Contents",
    "MacOS",
    "QuickRightMenu Extension"
  );
  await runCommand("swiftc", [
    "-sdk",
    sdkPath,
    "-target",
    target,
    "-O",
    path.join(root, "Sources", "FinderExtension", "main.swift"),
    path.join(root, "Sources", "FinderExtension", "FinderSync.swift"),
    "-o",
    extExecutable,
  ]);

  // Configure extension principal class asynchronously
  await runCommand("/usr/libexec/PlistBuddy", [
    "-c",
    "Set :NSExtension:NSExtensionPrincipalClass FinderSync",
    path.join(extDir, "Contents", "Info.plist"),
  ]);

  // 6. Code signing asynchronously
  console.log("[6/6] Code signing extension and app bundle...");
  await runCommand("codesign", [
    "--force",
    "--sign",
    "-",
    "--entitlements",
    path.join(resourcesDir, "Extension.entitlements"),
    extDir,
  ]);

  await runCommand("codesign", [
    "--force",
    "--sign",
    "-",
    "--entitlements",
    path.join(resourcesDir, "App.entitlements"),
    appDir,
  ]);

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\nBuild successfully completed in ${durationSec}s!`);
  console.log(`App bundle: ${appDir}`);

  if (options.runAfterBuild) {
    console.log(`\nLaunching application via 'open ${appDir}'...`);
    await runCommand("open", [appDir]);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  const runAfterBuild = process.argv.includes("--run");
  const forceIcon = process.argv.includes("--force-icon");
  await build({ runAfterBuild, forceIcon });
}
