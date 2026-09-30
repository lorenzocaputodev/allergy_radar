"""Prepara le immagini del README dagli screenshot di test_screens.

    flutter test test_screens/screens_test.dart --plain-name readme --update-goldens
    python tool/readme_images.py

Richiede Pillow. Schermate in WebP larghe 540 px, banner in PNG ottimizzato.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "test_screens" / "out"
SHOTS = ROOT / "assets" / "screenshots"
IMAGES = ROOT / "assets" / "images"


def main() -> None:
    SHOTS.mkdir(parents=True, exist_ok=True)
    IMAGES.mkdir(parents=True, exist_ok=True)
    for name in ("oggi", "diario", "andamento", "calendario"):
        img = Image.open(OUT / f"readme_{name}.png").convert("RGB")
        img = img.resize((540, round(img.height * 540 / img.width)), Image.LANCZOS)
        img.save(SHOTS / f"app_{name}.webp", "WEBP", quality=85, method=6)
    Image.open(OUT / "readme_banner.png").convert("RGB").save(IMAGES / "banner.png", optimize=True)
    for f in sorted([*SHOTS.iterdir(), *IMAGES.iterdir()]):
        print(f"{f.relative_to(ROOT)}  {f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
