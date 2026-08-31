const defaultRoot = "/app/dist";

export function candidatesForPath(pathname: string): string[] {
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return [];
  }

  if (!decoded.startsWith("/") || decoded.includes("\\") || decoded.includes("\0")) {
    return [];
  }

  const segments = decoded.split("/").filter(Boolean);
  if (segments.some((segment) => segment === "." || segment === "..")) {
    return [];
  }

  const relative = segments.join("/");
  if (!relative) return ["index.html"];
  if (relative.endsWith(".html") || relative.split("/").at(-1)?.includes(".")) {
    return [relative];
  }
  return [`${relative}/index.html`, relative];
}

function responseHeaders(path: string): Headers {
  const headers = new Headers({
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });
  headers.set(
    "Cache-Control",
    path.startsWith("_astro/")
      ? "public, max-age=31536000, immutable"
      : path.endsWith(".html")
        ? "no-cache"
        : "public, max-age=3600",
  );
  return headers;
}

export async function serveStaticRequest(
  request: Request,
  root = process.env.STATIC_ROOT ?? defaultRoot,
): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { Allow: "GET, HEAD" },
    });
  }

  const candidates = candidatesForPath(new URL(request.url).pathname);
  if (candidates.length === 0) return new Response("Bad request", { status: 400 });

  for (const candidate of candidates) {
    const file = Bun.file(`${root}/${candidate}`);
    if (await file.exists()) {
      const headers = responseHeaders(candidate);
      if (file.type) headers.set("Content-Type", file.type);
      return new Response(request.method === "HEAD" ? null : file, { headers });
    }
  }

  const notFound = Bun.file(`${root}/404.html`);
  if (await notFound.exists()) {
    return new Response(request.method === "HEAD" ? null : notFound, {
      status: 404,
      headers: responseHeaders("404.html"),
    });
  }
  return new Response(request.method === "HEAD" ? null : "Not found", { status: 404 });
}

export function startStaticServer() {
  const requestedPort = Number.parseInt(process.env.PORT ?? "8080", 10);
  if (!Number.isInteger(requestedPort) || requestedPort < 1 || requestedPort > 65_535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  return Bun.serve({
    hostname: "0.0.0.0",
    port: requestedPort,
    fetch: (request) => serveStaticRequest(request),
  });
}

if (import.meta.main) {
  const server = startStaticServer();
  console.log(JSON.stringify({ service: "atelier-static", status: "listening", port: server.port }));
}
