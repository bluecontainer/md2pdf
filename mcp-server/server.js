import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "node:child_process";
import { access, constants } from "node:fs/promises";
import { resolve, dirname, basename } from "node:path";

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

function runDocker(args) {
  return new Promise((resolve, reject) => {
    execFile("docker", args, { timeout: 300_000 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`docker failed (exit ${error.code}): ${stderr || error.message}`));
      } else {
        resolve({ stdout, stderr });
      }
    });
  });
}

server.tool(
  "convert_md_to_pdf",
  "Convert one or more Markdown files to PDF. Renders Mermaid diagrams, applies professional styling, and outputs A4-landscape PDFs alongside the source files.",
  {
    files: z
      .array(z.string())
      .min(1)
      .describe("Absolute paths to the Markdown files to convert"),
    css: z
      .string()
      .optional()
      .describe("Optional absolute path to a custom CSS stylesheet"),
  },
  async ({ files, css }) => {
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

    // Collect all unique directories we need to mount
    const dirs = [...new Set(files.map((f) => dirname(f)))];
    if (css) dirs.push(dirname(css));

    // Build docker run args
    // Mount each unique directory into the container at the same path
    const args = ["run", "--rm"];
    for (const dir of dirs) {
      args.push("-v", `${dir}:${dir}`);
    }

    if (css) {
      args.push("-e", `MD_TO_PDF_CSS=${css}`);
    }

    args.push("md2pdf");
    args.push(...files);

    try {
      const { stdout, stderr } = await runDocker(args);
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
