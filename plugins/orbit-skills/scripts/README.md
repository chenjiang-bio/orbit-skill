# Orbit HTTP request wrapper

These wrappers send one documented Organoid Database JSON or multipart API request through `curl`. They are the only transport commands Orbit skills should invoke. They deliberately do not parse JSON, decide whether a business request succeeded, or retry: the invoking skill applies [`organoid-api-contract.md`](../references/organoid-api-contract.md).

## Sandboxed Agent execution

In a network-restricted Agent sandbox, request minimal external-execution authorization before the first wrapper call. The authorization scope is limited to this installed wrapper and documented `https://db-orbit.com/api/...` requests. It does not permit browser transport, ad-hoc curl/Python, arbitrary domains, inspecting or logging credentials, or local configuration reads. The wrapper may consume its inherited `ORBIT_REQUEST_API_KEY` only to construct the required Authorization header.

When the restriction is unknown or authorization is unavailable, preserve the wrapper status line. For only safe-to-retry calls, repeated TLS/Schannel transport failures plus successful browser access to `https://db-orbit.com` indicate a possible sandbox transport restriction; request the same minimal authorization. Do not alter TLS, proxy, certificate, curl, or wrapper settings. An ambiguous Analysis submission is never safe to replay merely because external execution later becomes available.

## Prerequisite

Install `curl`. The wrapper reports `error=curl_not_found` and exits `10` if it is unavailable.

## Authentication

Every request requires the process environment variable `ORBIT_REQUEST_API_KEY`. The wrapper sends it as the HTTP header `Authorization: Bearer <value>` and does not print it in the response or status line. A missing or blank value is rejected before curl starts with `error=missing_api_key`; a value containing CR or LF is rejected with `error=invalid_api_key`.

Set the variable in the host process before invoking the wrapper or starting the Agent host that will invoke it:

Linux/macOS:

```bash
export ORBIT_REQUEST_API_KEY='<api-key>'
```

Windows PowerShell:

```powershell
$env:ORBIT_REQUEST_API_KEY = '<api-key>'
```

`ORBIT_REQUEST_API_KEY` is read only from the process environment. It is not accepted from `scripts/orbit-request.local.env`; never pass the key as a wrapper argument or add it to that file, request metadata, wrapper logs, or committed files.

## Local base-URL override

The committed default is `https://db-orbit.com`. Resolution order is:

1. Process environment variable `ORBIT_BASE_URL`.
2. Optional local file `scripts/orbit-request.local.env` next to the wrapper.
3. The committed public default.

The public default requires no configuration. Developers using an internal deployment may create the ignored local file once, or set a process-level override. Ordinary users should not create this file.

```text
ORBIT_BASE_URL=http://192.168.1.20:8080
```

The local file accepts one non-comment setting only. It is ignored by Git, and the wrappers reject malformed content or a value containing a path, query string, or fragment.

For a one-process override, set `ORBIT_BASE_URL` in the process that invokes a wrapper; it accepts an origin only (`http://host`, `https://host`, optionally with a port) and is never written by either wrapper.

Linux/macOS:

```bash
ORBIT_BASE_URL='http://192.168.1.20:8080' bash scripts/orbit-request.sh --method GET --path /api/common/gene/suggest --query 'keyword=TP53&organism=Homo%20sapiens'
```

Windows PowerShell:

```powershell
$env:ORBIT_BASE_URL = 'http://192.168.1.20:8080'
```

Remove the environment override to use the local-file value or committed public default:

```powershell
Remove-Item Env:ORBIT_BASE_URL
```

- `scripts/orbit-request.local.env` is ignored, accepts only `ORBIT_BASE_URL`, and must never contain credentials, tokens, passwords, or sensitive internal endpoints.

Run the wrapper from any working directory by providing its installed plugin path. The examples below assume the current directory is the plugin root.

### Linux and macOS

```bash
bash scripts/orbit-request.sh \
  --method GET \
  --path /api/common/gene/suggest \
  --query 'keyword=TP53&organism=Homo%20sapiens'
```

For a JSON POST, first save the exact request body in a local file, then opt in explicitly to POST:

```bash
bash scripts/orbit-request.sh \
  --method POST \
  --path /api/browse/general/semantic/search \
  --allow-post \
  --body-file request.json
```

On Linux/macOS, use `--body-stdin` only when an existing command safely provides the exact UTF-8 JSON bytes on standard input.

For an explicitly authorized multipart POST, pass scalar fields and files separately. The wrapper validates file existence and lets curl create the multipart boundary:

```bash
bash scripts/orbit-request.sh \
  --method POST \
  --path /api/analysis/quick/biomarker/predict \
  --allow-post \
  --multipart \
  --form-field 'mode=expression' \
  --form-field 'species=hsa' \
  --form-field 'condition=Colorectal Cancer' \
  --form-file 'matrix=matrix.tsv' \
  --form-file 'groups=groups.tsv'
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File scripts/orbit-request.ps1 `
  -Method GET `
  -Path /api/common/gene/suggest `
  -Query 'keyword=TP53&organism=Homo%20sapiens'
```

For a JSON POST:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/orbit-request.ps1 `
  -Method POST `
  -Path /api/browse/general/semantic/search `
  -AllowPost `
  -BodyFile request.json
```

On Windows, JSON POST bodies must use `-BodyFile`; `-BodyStdin` is rejected with `error=body_stdin_unsupported_on_windows`. Windows PowerShell 5.1 can transcode non-ASCII pipeline strings before the wrapper receives stdin, replacing characters or adding a byte-order mark and newline. Write the temporary request file explicitly as UTF-8 without BOM:

```powershell
$bodyPath = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($bodyPath, $json, $utf8NoBom)
try {
    powershell -ExecutionPolicy Bypass -File scripts/orbit-request.ps1 `
      -Method POST `
      -Path /api/browse/general/semantic/search `
      -AllowPost `
      -BodyFile $bodyPath
}
finally {
    Remove-Item -LiteralPath $bodyPath -Force -ErrorAction SilentlyContinue
}
```

The PowerShell wrapper invokes `curl.exe` explicitly, avoiding the PowerShell `curl` alias.

For multipart expression submission:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/orbit-request.ps1 `
  -Method POST `
  -Path /api/analysis/quick/biomarker/predict `
  -AllowPost `
  -Multipart `
  -FormField @('mode=expression', 'species=hsa', 'condition=Colorectal Cancer') `
  -FormFile @('matrix=matrix.tsv', 'groups=groups.tsv')
```

## Arguments

| Argument | Applies to | Meaning |
|---|---|---|
| `--method` / `-Method` | both | `GET` (default) or `POST`. |
| `--path` / `-Path` | both | Required relative `/api/...` path only. |
| `--query` / `-Query` | both | Optional already URL-encoded query string. Keep it separate from `path`. |
| `--timeout` / `-Timeout` | both | Positive seconds; default `30`. |
| `--allow-post` / `-AllowPost` | POST | Required explicit opt-in for every POST. |
| `--body-file` / `-BodyFile` | POST | JSON request body file. |
| `--body-stdin` | POSIX POST | Read exact UTF-8 JSON bytes from standard input. |
| `-BodyStdin` | PowerShell POST | Unsupported; exits `10` before curl starts. Use a UTF-8-without-BOM `-BodyFile`. |
| `--multipart` / `-Multipart` | POST | Select multipart mode; cannot be combined with JSON body options. |
| `--form-field` / `-FormField` | multipart POST | Repeatable `name=value` scalar part. |
| `--form-file` / `-FormFile` | multipart POST | Repeatable `name=path` file part; the path must identify a readable file. |

The wrapper rejects absolute URLs, non-`/api/` paths, embedded query strings, path traversal, arbitrary methods, GET bodies, multiple JSON body sources, mixed JSON/multipart requests, malformed form parts, and unreadable files. It accepts no caller-supplied custom headers, credentials, tokens, redirects, or arbitrary curl arguments; the only credential is the internally constructed Authorization header from `ORBIT_REQUEST_API_KEY`. Multipart requests require explicit POST opt-in; the calling Skill owns endpoint-specific required fields, file formats, size limits, and consent.

## Output and exit status

- **stdout**: the unmodified native response body.
- **stderr**: exactly one `orbit-request` status line with `httpStatus`, `curlExit`, `method`, `path`, and `timeout`; error lines also contain `error=...`.

| Exit code | Meaning |
|---:|---|
| `0` | curl completed and HTTP status was 2xx. Inspect JSON `code`; this alone is not business success. |
| `10` | Invalid local arguments, missing/invalid API key, or curl is unavailable. No request is sent. |
| `20` | curl transport, timeout, or wrapper failure. |
| `21` | curl completed but HTTP status was not 2xx. The response body, if returned, remains on stdout. |

## Retry ownership

A wrapper invocation performs **one attempt**. The skill may re-invoke it only under the shared policy: read-only GET and explicitly safe POST search calls may retry transport/timeouts, HTTP 5xx, or invalid JSON at most five times with 10-second waits. It must not automatically retry HTTP 4xx, non-zero API business codes, rate limits, uploads, exports, or analysis submissions.
