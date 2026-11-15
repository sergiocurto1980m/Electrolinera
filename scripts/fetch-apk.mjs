/*
 * Descarga el APK de la última release de GitHub y lo deja en dist/downloads.
 *
 * Se ejecuta solo en el build de Cloudflare Pages (`npm run build:pages`), no
 * en `npm run build` ni en el workflow de Android: así el APK descargado nunca
 * acaba dentro de los assets de la propia app.
 *
 * Si todavía no hay release, el script termina sin error y la web simplemente
 * oculta la descarga.
 */
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

const REPO = 'sergiocurto1980m/Electrolinera'
const BASE_URL = `https://github.com/${REPO}/releases/latest/download`
const DEST_DIR = join(process.cwd(), 'dist', 'downloads')
const FILES = ['electrolinera.apk', 'latest.json']
const RETRIES = 3
const RETRY_DELAY_MS = 2000

async function fetchWithRetry(url) {
  for (let attempt = 1; attempt <= RETRIES; attempt += 1) {
    const response = await fetch(url, { redirect: 'follow' })

    if (response.ok || response.status !== 404 || attempt === RETRIES) {
      return response
    }

    /* El CDN de GitHub puede tardar unos segundos en servir el asset nuevo. */
    await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS))
  }
}

async function download(name) {
  const response = await fetchWithRetry(`${BASE_URL}/${name}`)

  if (!response.ok) {
    console.warn(`[apk] ${name}: HTTP ${response.status}`)
    return false
  }

  const data = Buffer.from(await response.arrayBuffer())
  await writeFile(join(DEST_DIR, name), data)

  const size = (data.length / (1024 * 1024)).toFixed(1)
  console.log(`[apk] ${name} descargado (${size} MB)`)
  return true
}

await mkdir(DEST_DIR, { recursive: true })

let downloadables = 0

for (const file of FILES) {
  try {
    if (await download(file)) {
      downloadables += 1
    }
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : String(cause)
    console.warn(`[apk] No se pudo descargar ${file}: ${message}`)
  }
}

if (downloadables < FILES.length) {
  console.warn(
    '[apk] La descarga de la app quedará deshabilitada hasta la próxima release.',
  )
}
