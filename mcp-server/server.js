import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { spawn } from "node:child_process";
import { access, constants } from "node:fs/promises";
import { dirname } from "node:path";

// When running inside the container, call md-to-pdf directly.
// When running on the host, shell out to docker.
const INSIDE_CONTAINER = process.env.MD2PDF_CONTAINER === "1";
const IMAGE = process.env.MD2PDF_IMAGE || "ghcr.io/bluecontainer/md2pdf:latest";

const server = new McpServer({
  name: "md2pdf",
  version: "1.0.0",
});

async function fileExists(path) {
  try {
    await access(path, constants.R_OK);
    return true;
  } catch {
    return false;
  }
}

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      timeout: 300_000,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("error", (err) => reject(new Error(`${cmd} error: ${err.message}`)));
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`${cmd} failed (exit ${code}):\n${stderr || stdout}`));
      } else {
        resolve({ stdout, stderr });
      }
    });
  });
}

server.tool(
  "convert_md_to_pdf",
  "Convert one or more Markdown files to PDF. Renders Mermaid diagrams, applies professional styling, and outputs PDFs alongside the source files.",
  {
    files: z
      .array(z.string())
      .min(1)
      .describe("Absolute paths to the Markdown files to convert"),
    orientation: z
      .enum(["portrait", "landscape"])
      .default("landscape")
      .describe("Page orientation (default: landscape)"),
    font_size: z
      .string()
      .optional()
      .describe("Base font size with unit, e.g. '9pt', '11pt', '14px' (default: 11pt)"),
    css: z
      .string()
      .optional()
      .describe("Optional absolute path to a custom CSS stylesheet"),
  },
  async ({ files, orientation, font_size, css }) => {
    // Validate that all files exist and are .md
    for (const f of files) {
      if (!f.startsWith("/")) {
        return { content: [{ type: "text", text: `Error: "${f}" is not an absolute path` }] };
      }
      if (!f.endsWith(".md")) {
        return { content: [{ type: "text", text: `Error: "${f}" is not a .md file` }] };
      }
      if (!(await fileExists(f))) {
        return { content: [{ type: "text", text: `Error: "${f}" does not exist` }] };
      }
    }

    if (css && !(await fileExists(css))) {
      return { content: [{ type: "text", text: `Error: CSS file "${css}" does not exist` }] };
    }

    let cmd, args;

    if (INSIDE_CONTAINER) {
      // Running inside the container — call md-to-pdf directly
      cmd = "md-to-pdf";
      args = [];
      if (css) {
        process.env.MD_TO_PDF_CSS = css;
      }
      process.env.MD_TO_PDF_ORIENTATION = orientation;
      if (font_size) process.env.MD_TO_PDF_FONT_SIZE = font_size;
      args.push(...files);
    } else {
      // Running on the host — shell out to docker
      const dirs = [...new Set(files.map((f) => dirname(f)))];
      if (css) dirs.push(dirname(css));

      cmd = "docker";
      args = ["run", "--rm"];
      for (const dir of dirs) {
        args.push("-v", `${dir}:${dir}`);
      }
      if (css) {
        args.push("-e", `MD_TO_PDF_CSS=${css}`);
      }
      args.push("-e", `MD_TO_PDF_ORIENTATION=${orientation}`);
      if (font_size) args.push("-e", `MD_TO_PDF_FONT_SIZE=${font_size}`);
      args.push(IMAGE);
      args.push(...files);
    }

    try {
      const { stdout, stderr } = await run(cmd, args);
      const output = [stdout, stderr].filter(Boolean).join("\n").trim();
      const pdfPaths = files.map((f) => f.replace(/\.md$/, ".pdf"));

      return {
        content: [
          {
            type: "text",
            text: [
              output,
              "",
              "Generated PDFs:",
              ...pdfPaths.map((p) => `  ${p}`),
            ].join("\n"),
          },
        ],
      };
    } catch (err) {
      return { content: [{ type: "text", text: `Conversion failed: ${err.message}` }] };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
