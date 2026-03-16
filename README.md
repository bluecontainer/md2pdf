# md2pdf

A Markdown-to-PDF converter with Mermaid diagram support, packaged as an MCP server in a Docker image. Works with Claude Code, VS Code Copilot, and any MCP-compatible client.

- Renders Mermaid diagrams (flowcharts, sequence, class, state, Gantt, pie, ER)
- Professional A4 landscape styling with custom CSS support
- Zero dependencies on the host — just Docker

## Quick start

### Claude Code

```bash
claude mcp add md2pdf -- docker run --rm -i -v /home:/home ghcr.io/bluecontainer/md2pdf:latest
```

Then ask Claude to "convert myfile.md to pdf".

### VS Code Copilot

Add to `.vscode/mcp.json` in your workspace:

```json
{
  "servers": {
    "md2pdf": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "-v", "/home:/home", "ghcr.io/bluecontainer/md2pdf:latest"]
    }
  }
}
```

### macOS

Replace `-v /home:/home` with `-v /Users:/Users`:

```bash
claude mcp add md2pdf -- docker run --rm -i -v /Users:/Users ghcr.io/bluecontainer/md2pdf:latest
```

## Custom CSS

Pass a custom stylesheet by adding the `css` parameter when calling the tool. The CSS file must be accessible within the mounted volume.

## CLI usage

You can also use the image directly from the command line:

```bash
docker run --rm -v /home:/home --entrypoint md-to-pdf \
  ghcr.io/bluecontainer/md2pdf:latest /absolute/path/to/file.md
```

## Building locally

```bash
git clone https://github.com/bluecontainer/md2pdf.git
cd md2pdf
docker build -t ghcr.io/bluecontainer/md2pdf:latest .
```
