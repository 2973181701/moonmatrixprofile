"""Create a local source + prebuilt demo archive using only Python's standard library."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
if not (root / "web/core.js").is_file():
    raise SystemExit("Run npm run build before packaging.")
destination = root.parent / "deliverables"
destination.mkdir(exist_ok=True)
archive = destination / "MoonMatrixProfile-0.1.0.zip"
directories = ["bridge", "cmd", "docs", "evidence", "examples", "scripts", "tests", "web", ".github"]
files = [p for p in root.iterdir() if p.is_file() and (
    p.suffix in {".mbt", ".mbti", ".mod", ".pkg", ".md", ".mjs", ".json", ".txt"}
    or p.name in {"LICENSE", ".gitignore"}
)]
for name in directories:
    files.extend(p for p in (root / name).rglob("*") if p.is_file() and "__pycache__" not in p.parts)
for name in ["desktop.jpg", "mobile.jpg"]:
    image = root / "output/playwright" / name
    if image.is_file():
        files.append(image)
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(set(files)):
        bundle.write(path, Path("moonmatrixprofile") / path.relative_to(root))
with zipfile.ZipFile(archive) as bundle:
    if bundle.testzip() is not None:
        raise SystemExit("Archive integrity check failed")
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
print(f"Packaged {len(set(files))} files: {archive}")
print(f"SHA-256: {digest}")
