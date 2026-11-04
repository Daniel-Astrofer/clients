#!/usr/bin/env python3
"""
Otimizador e conversor de imagens de fundo para a tela de PIN (Ultra HD / 2160p).
Garante resolução ultra-alta (2x - 2160p) para que BoxFit.cover em telas
verticais de celular nunca fique borrado ou com baixa definição.
Converte para WebP (qualidade 90) com orientação EXIF corrigida.
"""

import os
import sys
import argparse
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:
    print("Erro: Pillow não está instalado. Instale com: pip install Pillow")
    sys.exit(1)

def optimize_images(input_dir: Path, output_dir: Path, target_min_dim: int = 2160, quality: int = 90, remove_source: bool = False):
    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    supported_extensions = ('.jpg', '.jpeg', '.png', '.bmp', '.tiff')
    files = sorted([f for f in input_dir.iterdir() if f.is_file() and f.suffix.lower() in supported_extensions])

    if not files:
        print(f"Nenhuma imagem para converter em {input_dir}")
        return []

    print(f"\n🚀 Otimizando {len(files)} imagens em Ultra HD (2160p)...")
    print(f"Diretório de entrada:  {input_dir}")
    print(f"Diretório de saída:    {output_dir}")
    print(f"Dimensão mínima cover: {target_min_dim} px (2x HD)")
    print(f"Formato de saída:      WebP (qualidade: {quality}%)\n" + "-" * 60)

    total_orig_size = 0
    total_opt_size = 0
    converted_files = []

    for i, file_path in enumerate(files, 1):
        orig_size = file_path.stat().st_size
        total_orig_size += orig_size

        try:
            with Image.open(file_path) as img:
                # Tratar transparência/RGBA para evitar problemas com JPEG/WebP
                if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
                    bg = Image.new('RGB', img.size, (0, 0, 0))
                    alpha = img.convert('RGBA').split()[-1]
                    bg.paste(img, mask=alpha)
                    img = bg
                else:
                    img = img.convert('RGB')

                # Ajustar orientação baseada em EXIF (câmeras de celular)
                img = ImageOps.exif_transpose(img)

                w, h = img.size
                # Para BoxFit.cover vertical em celular, a menor dimensão (ou altura da paisagem)
                # precisa ter pelo menos target_min_dim (ex: 2160px) para não perder nitidez.
                if h < w: # Paisagem
                    if h > target_min_dim:
                        target_h = target_min_dim
                        target_w = int(w * (target_h / h))
                        img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
                else: # Retrato
                    if w > target_min_dim:
                        target_w = target_min_dim
                        target_h = int(h * (target_w / w))
                        img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)

                out_name = f"{file_path.stem}.webp"
                out_path = output_dir / out_name

                # Salvar em WebP de alta fidelidade
                img.save(out_path, 'WEBP', quality=quality, method=6)

                opt_size = out_path.stat().st_size
                total_opt_size += opt_size
                converted_files.append(out_path)

                reduction = ((orig_size - opt_size) / orig_size) * 100 if orig_size > 0 else 0
                print(f"[{i:02d}/{len(files):02d}] {file_path.name}")
                print(f"      Dimensões: {img.size[0]}x{img.size[1]} | {orig_size / 1024:.1f} KB -> {opt_size / 1024:.1f} KB (-{reduction:.1f}%)")

                if remove_source and file_path != out_path:
                    file_path.unlink()

        except Exception as e:
            print(f"❌ Erro ao converter {file_path.name}: {e}")

    print("-" * 60)
    orig_mb = total_orig_size / (1024 * 1024)
    opt_mb = total_opt_size / (1024 * 1024)
    total_reduction = ((total_orig_size - total_opt_size) / total_orig_size) * 100 if total_orig_size > 0 else 0
    print(f"✨ Concluído com sucesso!")
    print(f"Tamanho total original:   {orig_mb:.2f} MB")
    print(f"Tamanho total otimizado:  {opt_mb:.2f} MB")
    print(f"Economia de dados:        -{total_reduction:.1f}%")
    return converted_files

def main():
    parser = argparse.ArgumentParser(description="Otimizador de imagens de fundo para PIN (Ultra HD)")
    parser.add_argument("--input", default="assets/pin", help="Diretório das imagens originais")
    parser.add_argument("--output", default="assets/pin", help="Diretório das imagens convertidas")
    parser.add_argument("--min-dim", type=int, default=2160, help="Dimensão mínima (2160 para 2x)")
    parser.add_argument("--quality", type=int, default=90, help="Qualidade WebP (padrão 90)")
    parser.add_argument("--remove-source", action="store_true", help="Remove os arquivos originais (.jpg/.png) após conversão")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    in_dir = project_root / args.input
    out_dir = project_root / args.output

    optimize_images(in_dir, out_dir, target_min_dim=args.min_dim, quality=args.quality, remove_source=args.remove_source)

if __name__ == "__main__":
    main()
