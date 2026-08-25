"""
Conversor CSV → PLY para visualização no Blender
=================================================
Este script converte os dados CSV exportados pela app LiDAR
para o formato PLY que o Blender consegue importar.
 
COMO USAR:
1. Exporta o CSV da app no iPhone
2. Coloca o CSV na mesma pasta que este script
3. Corre: python csv_to_ply.py nome_do_ficheiro.csv
   Ou para usar todos os pontos (ignorar filtro de confiança):
   python csv_to_ply.py nome_do_ficheiro.csv --all-points
4. Abre o Blender → File → Import → Stanford PLY
 
COMO IMPORTAR NO BLENDER:
1. Abre o Blender
2. File → Import → Stanford (.ply)
3. Seleciona o ficheiro .ply gerado
4. A nuvem de pontos aparece na cena!
"""
 
import pandas as pd
import numpy as np
import struct
import sys
import os

# ─────────────────────────────────────────────
# CORES DO HEATMAP (igual à app iOS)
# Azul=perto, Ciano, Verde, Amarelo, Vermelho=longe
# ─────────────────────────────────────────────
def depth_to_colors_vectorized(depths, min_depth, max_depth):
    """
    Converte array de profundidades em cores RGB (numpy vectorizado).
    Equivalente à função depth_to_color() original mas para todos os pontos de uma vez.
    """
    range_d = max(max_depth - min_depth, 0.01)
    v = np.clip((depths - min_depth) / range_d, 0, 1)

    r = np.zeros(len(v))
    g = np.zeros(len(v))
    b = np.zeros(len(v))

    # Azul → Ciano (v: 0.00 a 0.25)
    mask = v < 0.25
    t = v[mask] / 0.25
    r[mask], g[mask], b[mask] = 0, t, 1

    # Ciano → Verde (v: 0.25 a 0.50)
    mask = (v >= 0.25) & (v < 0.5)
    t = (v[mask] - 0.25) / 0.25
    r[mask], g[mask], b[mask] = 0, 1, 1 - t

    # Verde → Amarelo (v: 0.50 a 0.75)
    mask = (v >= 0.5) & (v < 0.75)
    t = (v[mask] - 0.5) / 0.25
    r[mask], g[mask], b[mask] = t, 1, 0

    # Amarelo → Vermelho (v: 0.75 a 1.00)
    mask = v >= 0.75
    t = (v[mask] - 0.75) / 0.25
    r[mask], g[mask], b[mask] = 1, 1 - t, 0

    return (r * 255).astype(np.uint8), (g * 255).astype(np.uint8), (b * 255).astype(np.uint8)


# ─────────────────────────────────────────────
# CONVERTER CSV → PLY (binário)
# ─────────────────────────────────────────────
def csv_to_ply(csv_path, output_path=None, all_points=False):
    """
    Converte ficheiro CSV do LiDAR para formato PLY binário.
    
    O CSV deve ter as colunas:
    timestamp, x, y, depth_m, confidence, world_x, world_y, world_z
    
    all_points=True  → usa todos os pontos independentemente da confiança
    all_points=False → usa só pontos de confiança alta (2), com fallback para todos
    """
    
    print(f"A ler ficheiro: {csv_path}")
    
    # Lê o CSV
    df = pd.read_csv(csv_path)
    
    # Verifica se tem as colunas 3D
    has_3d = all(col in df.columns for col in ['world_x', 'world_y', 'world_z'])
    
    if has_3d:
        print("Ficheiro com coordenadas 3D — usando world_x, world_y, world_z")
        points = df[['world_x', 'world_y', 'world_z', 'depth_m', 'confidence']].copy()
        points.columns = ['x', 'y', 'z', 'depth_m', 'confidence']
    else:
        print("Ficheiro sem coordenadas 3D — usando x, y como 2D e depth como Z")
        points = df[['x', 'y', 'depth_m', 'confidence']].copy()
        points['z'] = points['depth_m']
        points['x'] = points['x'] / 1000.0
        points['y'] = points['y'] / 1000.0
    
    print(f"Total de pontos: {len(points):,}")

    # ─────────────────────────────────────────────
    # FILTRO DE CONFIANÇA
    # ─────────────────────────────────────────────
    if all_points:
        use_points = points
        print("Modo --all-points: a usar todos os pontos (confiança ignorada)")
    else:
        high_conf = points[points['confidence'] == 2]
        low_conf_count = len(points) - len(high_conf)
        print(f"Pontos com confiança alta: {len(high_conf):,}  |  descartados: {low_conf_count:,}")

        if len(high_conf) == 0:
            print("AVISO: Nenhum ponto com confiança alta — a usar todos os pontos.")
            print("       Usa --all-points para suprimir este aviso.")
            use_points = points
        else:
            use_points = high_conf

    print(f"Pontos a exportar: {len(use_points):,}")

    # ─────────────────────────────────────────────
    # Centrar na origem (0, 0, 0)
    # Evita que o objeto apareça longe no Blender
    # ─────────────────────────────────────────────
    x = use_points['x'].to_numpy(dtype=np.float32)
    y = use_points['y'].to_numpy(dtype=np.float32)
    z = use_points['z'].to_numpy(dtype=np.float32)
    depth = use_points['depth_m'].to_numpy(dtype=np.float32)

    cx, cy, cz = x.mean(), y.mean(), z.mean()
    x -= cx
    y -= cy
    z -= cz
    print(f"Centrado na origem — offset removido: ({cx:.4f}, {cy:.4f}, {cz:.4f})")

    # Gera cores (vectorizado)
    r, g, b = depth_to_colors_vectorized(depth, depth.min(), depth.max())

    # ─────────────────────────────────────────────
    # Eixos corretos para o Blender (ARKit → Blender)
    # x permanece, y←z, z←y
    # ─────────────────────────────────────────────
    # Define o nome do ficheiro de saída
    if output_path is None:
        base = os.path.splitext(csv_path)[0]
        output_path = base + ".ply"
    
    # Escreve o ficheiro PLY binário
    print(f"A guardar ficheiro PLY binário: {output_path}")
    n = len(x)

    with open(output_path, 'wb') as f:
        # Cabeçalho PLY (texto)
        header = (
            "ply\n"
            "format binary_little_endian 1.0\n"
            f"comment Gerado por csv_to_ply.py - Projeto LiDAR IPB 2025/2026\n"
            f"element vertex {n}\n"
            "property float x\n"
            "property float y\n"
            "property float z\n"
            "property uchar red\n"
            "property uchar green\n"
            "property uchar blue\n"
            "end_header\n"
        )
        f.write(header.encode('ascii'))

        # Dados binários: cada ponto = 3× float32 (12 bytes) + 3× uint8 (3 bytes) = 15 bytes
        # Eixos: x, z, y (conversão ARKit → Blender)
        data = np.zeros(n, dtype=[
            ('x', '<f4'), ('y', '<f4'), ('z', '<f4'),
            ('r', 'u1'),  ('g', 'u1'),  ('b', 'u1')
        ])
        data['x'] = x
        data['y'] = z   # eixo z do ARKit → y do Blender
        data['z'] = y   # eixo y do ARKit → z do Blender
        data['r'] = r
        data['g'] = g
        data['b'] = b
        f.write(data.tobytes())

    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"Ficheiro PLY guardado: {output_path} ({size_mb:.1f} MB)")
    print(f"\nCOMO IMPORTAR NO BLENDER\\CLOUDCOMPARE:")
    print(f"   1. Abre o Blender\\CloudCompare")
    print(f"   2. File → Import → Stanford (.ply)")
    print(f"   3. Seleciona: {output_path}")
    print(f"   4. A nuvem de pontos aparece na cena!")
    
    return output_path
 
if __name__ == "__main__":
    all_points = "--all-points" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]

    if args:
        csv_file = args[0]
    else:
        csv_file = "lidar_sample_data.csv"
        print(f"Nenhum ficheiro especificado — usando: {csv_file}")
        print(f"   Para usar o teu ficheiro: python csv_to_ply.py o_teu_ficheiro.csv\n")
    
    if not os.path.exists(csv_file):
        print(f"Ficheiro não encontrado: {csv_file}")
        print(f"Coloca o CSV na mesma pasta que este script!")
        sys.exit(1)
    
    csv_to_ply(csv_file, all_points=all_points)