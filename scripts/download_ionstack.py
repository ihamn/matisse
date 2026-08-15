"""Download IonStack exploit source files from GitHub API"""
import os, json, urllib.request

BASE_API = "https://api.github.com/repos/NebuSec/CyberMeowfia/contents"
BASE_RAW = "https://raw.githubusercontent.com/NebuSec/CyberMeowfia/main"
LOCAL_ROOT = r"c:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358\IonStack"

def download_path(api_path, local_base):
    """Recursively download files from a GitHub API path"""
    url = f"{BASE_API}/{api_path}?ref=main"
    print(f"Fetching: {url}")
    
    req = urllib.request.Request(url, headers={"User-Agent": "python"})
    with urllib.request.urlopen(req) as resp:
        items = json.loads(resp.read())
    
    for item in items:
        name = item["name"]
        if item["type"] == "dir":
            # Recurse into subdirectory
            sub_path = f"{api_path}/{name}"
            sub_local = os.path.join(local_base, name)
            os.makedirs(sub_local, exist_ok=True)
            download_path(sub_path, sub_local)
        elif item["type"] == "file":
            # Download file
            download_url = item["download_url"]
            local_path = os.path.join(local_base, name)
            
            if os.path.exists(local_path):
                print(f"  SKIP (exists): {local_path}")
                continue
            
            print(f"  Downloading: {name} ({item['size']} bytes)")
            try:
                req2 = urllib.request.Request(download_url, headers={"User-Agent": "python"})
                with urllib.request.urlopen(req2) as resp2:
                    content = resp2.read()
                os.makedirs(os.path.dirname(local_path), exist_ok=True)
                with open(local_path, "wb") as f:
                    f.write(content)
                print(f"    -> {local_path}")
            except Exception as e:
                print(f"    ERROR: {e}")

# Download CVE-2026-43499 exploit
print("=" * 60)
print("Downloading CVE-2026-43499 exploit...")
print("=" * 60)

paths_43499 = [
    "IonStack/CVE-2026-43499/exploit/src",
    "IonStack/CVE-2026-43499/exploit/src/kernelsnitch",
    "IonStack/CVE-2026-43499/exploit/assets",
]

for p in paths_43499:
    local = os.path.join(LOCAL_ROOT, p)
    os.makedirs(local, exist_ok=True)
    download_path(p, local)

# Download Makefile
print("\nDownloading Makefile...")
url = f"{BASE_RAW}/IonStack/CVE-2026-43499/exploit/Makefile"
req = urllib.request.Request(url, headers={"User-Agent": "python"})
with urllib.request.urlopen(req) as resp:
    content = resp.read()
local = os.path.join(LOCAL_ROOT, "IonStack", "CVE-2026-43499", "exploit")
os.makedirs(local, exist_ok=True)
with open(os.path.join(local, "Makefile"), "wb") as f:
    f.write(content)
print(f"  -> {os.path.join(local, 'Makefile')}")

# Download CVE-2026-10702 files
print("\n" + "=" * 60)
print("Downloading CVE-2026-10702 (Firefox exploit)...")
print("=" * 60)

cve10702_files = [
    "IonStack/CVE-2026-10702/exploit.html",
    "IonStack/CVE-2026-10702/index.html",
    "IonStack/CVE-2026-10702/ansi.js",
]

for f in cve10702_files:
    url = f"{BASE_RAW}/{f}"
    local_path = os.path.join(LOCAL_ROOT, f)
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    print(f"  Downloading: {os.path.basename(f)}")
    req = urllib.request.Request(url, headers={"User-Agent": "python"})
    with urllib.request.urlopen(req) as resp:
        content = resp.read()
    with open(local_path, "wb") as fout:
        fout.write(content)
    print(f"    -> {local_path} ({len(content)} bytes)")

# Download Readme
print("\nDownloading Readme...")
url = f"{BASE_RAW}/IonStack/Readme.md"
req = urllib.request.Request(url, headers={"User-Agent": "python"})
with urllib.request.urlopen(req) as resp:
    content = resp.read()
local_path = os.path.join(LOCAL_ROOT, "IonStack", "Readme.md")
os.makedirs(os.path.dirname(local_path), exist_ok=True)
with open(local_path, "wb") as f:
    f.write(content)
print(f"  -> {local_path}")

print("\nDone! All files downloaded.")