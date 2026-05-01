const STORAGE_HOST = 'stvincentcv.z7.web.core.windows.net';

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  // Rewrite the URL hostname to Azure Storage web endpoint
  const url = new URL(request.url);
  url.hostname = STORAGE_HOST;
  url.protocol = 'https:';

  // Send the request to Azure Storage with the correct Host header.
  // Without this rewrite, Cloudflare sends Host: vincentlelaverda.com
  // which Azure Storage rejects with InvalidUri 400.
  const response = await fetch(url.toString(), {
    method:  request.method,
    headers: { 'Host': STORAGE_HOST },
  });

  return response;
}
