FROM node:20-bookworm-slim

# System deps: pandoc, weasyprint's native libs, chromium for puppeteer
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    python3-pip \
    python3-cffi \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libharfbuzz0b \
    libffi-dev \
    libgdk-pixbuf-2.0-0 \
    chromium \
    fonts-liberation \
    fonts-noto \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install weasyprint via pip
RUN pip3 install --no-cache-dir --break-system-packages weasyprint

# Tell puppeteer (used by mermaid-cli) to use system chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Install mermaid-cli globally
RUN npm install -g @mermaid-js/mermaid-cli

# Bundle the converter script and default stylesheet
COPY md-to-pdf.sh /usr/local/bin/md-to-pdf
COPY pdf-style.css /usr/local/share/md-to-pdf/pdf-style.css
COPY puppeteer-config.json /usr/local/share/md-to-pdf/puppeteer-config.json
RUN chmod +x /usr/local/bin/md-to-pdf

# Users can mount a custom stylesheet and point to it with MD_TO_PDF_CSS:
#   -v /path/to/style.css:/style.css -e MD_TO_PDF_CSS=/style.css

WORKDIR /data

ENTRYPOINT ["md-to-pdf"]
