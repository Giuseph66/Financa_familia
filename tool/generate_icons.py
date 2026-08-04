#!/usr/bin/env python3
"""Gera todos os ícones do app a partir da geometria do sinete.

O sinete é a margem vertical de um livro de contas cruzada por duas
entradas de comprimentos diferentes — o mesmo desenho de
`lib/design_system/components/brand_lockup.dart`. Desenhar por
geometria em vez de reamostrar um PNG mantém as bordas limpas em
qualquer tamanho e deixa o ícone reprodutível.

Uso:  python3 tool/generate_icons.py
"""

from __future__ import annotations

import json
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- cores
BG = (10, 10, 12, 255)  # canvas  #0A0A0C
INK = (143, 182, 216, 255)  # brandInk #8FB6D8
# Segunda entrada: brandInk a 50% sobre o canvas, achatado em cor sólida
# para o ícone não depender de alpha em fundo desconhecido.
INK_DIM = (77, 96, 114, 255)  # #4D6072

# ------------------------------------------------- geometria normalizada
# Fracções do lado do canvas, medidas do desenho de referência.
CORNER = 0.2246
STROKE = 0.0664
BAR_V = (0.2559, 0.2461, 0.0664, 0.5010)  # x, y, w, h
BAR_TOP = (0.4512, 0.3877, 0.2930, 0.0664)
BAR_BOTTOM = (0.4512, 0.5615, 0.1787, 0.0664)

# Caixa que envolve os três traços, para poder reposicionar o grupo.
GROUP_L = BAR_V[0]
GROUP_T = BAR_V[1]
GROUP_R = BAR_TOP[0] + BAR_TOP[2]
GROUP_B = BAR_V[1] + BAR_V[3]

SS = 4  # supersampling: desenha grande e reduz, para borda sem serrilhado


def _stadium(draw: ImageDraw.ImageDraw, box, color) -> None:
    """Retângulo de pontas totalmente arredondadas."""
    x, y, w, h = box
    draw.rounded_rectangle([x, y, x + w, y + h], radius=min(w, h) / 2, fill=color)


def render(
    size: int,
    *,
    background: bool = True,
    scale: float = 1.0,
    monochrome: tuple[int, int, int, int] | None = None,
) -> Image.Image:
    """Desenha o ícone.

    `scale` encolhe o grupo de traços dentro do quadro — usado na camada
    de primeiro plano do ícone adaptativo do Android e no maskable da
    web, que são recortados nas bordas.
    """
    canvas = size * SS
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if background:
        draw.rounded_rectangle(
            [0, 0, canvas - 1, canvas - 1],
            radius=CORNER * canvas,
            fill=BG,
        )

    # Reposiciona o grupo: encolhe em torno do próprio centro.
    gcx = (GROUP_L + GROUP_R) / 2
    gcy = (GROUP_T + GROUP_B) / 2

    def place(box):
        x, y, w, h = box
        return (
            (gcx + (x - gcx) * scale) * canvas,
            (gcy + (y - gcy) * scale) * canvas,
            w * scale * canvas,
            h * scale * canvas,
        )

    bright = monochrome or INK
    dim = monochrome or INK_DIM

    _stadium(draw, place(BAR_V), bright)
    _stadium(draw, place(BAR_TOP), bright)
    _stadium(draw, place(BAR_BOTTOM), dim)

    return img.resize((size, size), Image.LANCZOS)


def write(img: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}  {img.width}x{img.height}")


def flatten(img: Image.Image) -> Image.Image:
    """Achata sobre o canvas. iOS rejeita ícone com canal alpha."""
    out = Image.new("RGB", img.size, BG[:3])
    out.paste(img, mask=img.split()[3])
    return out


def main() -> None:
    print("mestre")
    write(render(1024), ROOT / "assets/brand/app_icon.png")
    write(
        render(1024, background=False, scale=0.58),
        ROOT / "assets/brand/app_icon_foreground.png",
    )

    # ------------------------------------------------------------ Android
    print("android — launcher")
    for folder, px in [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]:
        write(
            render(px),
            ROOT / f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png",
        )

    # Ícone adaptativo: quadro de 108dp com só os 72dp centrais
    # garantidos. O primeiro plano vai reduzido para o recorte do
    # fabricante (círculo, squircle, gota) nunca cortar o sinete.
    print("android — adaptativo")
    for folder, px in [
        ("mdpi", 108),
        ("hdpi", 162),
        ("xhdpi", 216),
        ("xxhdpi", 324),
        ("xxxhdpi", 432),
    ]:
        base = ROOT / f"android/app/src/main/res/mipmap-{folder}"
        write(render(px, background=False, scale=0.58), base / "ic_launcher_foreground.png")
        # Ícone temático do Android 13: uma cor só, o sistema recolore.
        write(
            render(px, background=False, scale=0.58, monochrome=(255, 255, 255, 255)),
            base / "ic_launcher_monochrome.png",
        )

    # ---------------------------------------------------------------- iOS
    print("ios")
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())
    for entry in contents.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        pt = float(entry["size"].split("x")[0])
        factor = int(entry["scale"].rstrip("x"))
        px = round(pt * factor)
        # Sem alpha e sem cantos próprios: o iOS aplica a máscara dele.
        write(flatten(render(px, background=True)), appicon / filename)

    # ---------------------------------------------------------------- web
    print("web")
    write(render(32), ROOT / "web/favicon.png")
    write(render(192), ROOT / "web/icons/Icon-192.png")
    write(render(512), ROOT / "web/icons/Icon-512.png")
    # Maskable é sangrado e recortado: fundo inteiro e sinete na zona
    # segura de 80%.
    for px in (192, 512):
        img = Image.new("RGBA", (px, px), BG)
        img.alpha_composite(render(px, background=False, scale=0.62))
        write(img, ROOT / f"web/icons/Icon-maskable-{px}.png")

    print("\nok")


if __name__ == "__main__":
    main()
