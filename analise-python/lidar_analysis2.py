"""
Analise de Dados LiDAR - iPhone 14 Pro
======================================
Este script processa os dados reais exportados pela aplicacao iOS
(ficheiro CSV com as colunas timestamp, x, y, depth_m, confidence, ...)
e produz:
  1. Estatisticas descritivas do sensor (profundidade, confianca);
  2. Analise de ruido por pixel ao longo dos frames;
  3. Graficos para o relatorio (painel com 8 graficos + graficos individuais).
 
O CSV de entrada e gerado pela app a partir do sensor LiDAR via ARKit.
"""
 
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.colors import LinearSegmentedColormap
import warnings
warnings.filterwarnings('ignore')
 
 
# ─────────────────────────────────────────────
# 1. ESTATÍSTICAS DESCRITIVAS
# ─────────────────────────────────────────────
def print_statistics(df):
    """
    Estatísticas básicas dos dados.
 
    Média = valor central típico
    Desvio padrão = quanto os valores variam (= estimativa do ruído)
    """
    print("\n" + "="*50)
    print("  ESTATÍSTICAS DOS DADOS LiDAR")
    print("="*50)
    print(f"  Total de pontos:     {len(df):>10,}")
    print(f"  Frames capturados:   {df['timestamp'].nunique():>10}")
    print(f"  Pontos por frame:    {len(df)//df['timestamp'].nunique():>10,}")
    print(f"\n  PROFUNDIDADE (metros):")
    print(f"  Mínima:              {df['depth_m'].min():>10.3f} m")
    print(f"  Máxima:              {df['depth_m'].max():>10.3f} m")
    print(f"  Média:               {df['depth_m'].mean():>10.3f} m")
    print(f"  Desvio padrão:       {df['depth_m'].std()} m  ← estimativa do ruído global")
    print(f"\n  CONFIANÇA:")
    for c, label in [(0,"Baixa"), (1,"Média"), (2,"Alta")]:
        pct = (df['confidence']==c).mean()*100
        print(f"  {label}:               {pct:.1f}%")
    print("="*50)
 
 
# ─────────────────────────────────────────────
# 2. ANÁLISE DE RUÍDO POR SUPERFÍCIE
# ─────────────────────────────────────────────
def analyze_noise(df):
    """
    Analisa o ruído por pixel ao longo do tempo.
 
    Ruído = variação das medições do mesmo ponto em frames diferentes.
    Se o sensor fosse perfeito, o mesmo pixel teria sempre o mesmo valor.
    O desvio padrão temporal diz-nos quão "trémulo" é o sensor.
    """
    # Agrupa por pixel (x,y) e calcula variação temporal
    noise = df.groupby(['x', 'y'])['depth_m'].agg(['mean', 'std', 'count'])
    noise.columns = ['depth_mean', 'depth_std', 'n_frames']
    noise = noise[noise['n_frames'] >= 5].reset_index()  # só pixels com dados suficientes
 
    print(f"\n  ANÁLISE DE RUÍDO (por pixel):")
    print(f"  Ruído médio global:  {noise['depth_std'].mean()*100:.2f} cm")
    print(f"  Ruído máximo:        {noise['depth_std'].max()*100:.2f} cm")
 
    # Ruído por zona de profundidade
    bins = [0, 1.0, 2.0, 3.0, 5.0]
    labels = ['<1m', '1-2m', '2-3m', '3-5m']
    noise['zone'] = pd.cut(noise['depth_mean'], bins=bins, labels=labels)
    print(f"\n  Ruído por distância:")
    for zone, grp in noise.groupby('zone'):
        print(f"  {zone}: {grp['depth_std'].mean()*100:.2f} cm  ← desvio padrão médio")
 
    return noise
 
 
# ─────────────────────────────────────────────
# 3. GERAR GRÁFICOS (painel com os 8 graficos)
# ─────────────────────────────────────────────
def plot_all(df, noise_df):
    """Gera um painel com 8 gráficos para o relatório."""
 
    heatmap_colors = ['#0000ff', '#00ffff', '#00ff00', '#ffff00', '#ff0000']
    heatmap_cmap = LinearSegmentedColormap.from_list('lidar', heatmap_colors)
 
    fig = plt.figure(figsize=(16, 12))
    fig.patch.set_facecolor('white')
    gs = gridspec.GridSpec(3, 3, figure=fig, hspace=0.4, wspace=0.35)
 
    title_color = "#111111"
    label_color = '#333333'
    grid_color  = '#cccccc'
 
    def style_ax(ax, title):
        ax.set_facecolor('white')
        ax.set_title(title, color=title_color, fontsize=10, pad=8)
        ax.tick_params(colors=label_color, labelsize=8)
        ax.xaxis.label.set_color(label_color)
        ax.yaxis.label.set_color(label_color)
        for spine in ax.spines.values():
            spine.set_edgecolor(grid_color)
        ax.grid(True, color=grid_color, linewidth=0.5, alpha=0.7)
 
    # ── Gráfico 1: Heatmap 2D de profundidade ──
    ax1 = fig.add_subplot(gs[0, 0])
    mid_ts = df['timestamp'].unique()[len(df['timestamp'].unique())//2]
    frame = df[df['timestamp'] == mid_ts]
 
    pivot = frame.pivot_table(index='y', columns='x',
                              values='depth_m', aggfunc='mean')
 
    heatmap = np.rot90(pivot.values, k=-1)
 
    im = ax1.imshow(
        heatmap,
        cmap=heatmap_cmap,
        aspect='auto',
        vmin=frame['depth_m'].quantile(0.02),
        vmax=frame['depth_m'].quantile(0.98),
        origin='upper'
    )
 
    plt.colorbar(im, ax=ax1, label='metros').ax.yaxis.label.set_color(label_color)
 
    style_ax(ax1, "Mapa de Profundidade (1 frame)")
    ax1.set_xlabel("Pixel X")
    ax1.set_ylabel("Pixel Y")
 
    # ── Gráfico 2: Histograma de profundidades ──
    ax2 = fig.add_subplot(gs[0, 1])
 
    ax2.hist(
        df['depth_m'],
        bins=60,
        color='#238636',
        edgecolor='none',
        alpha=0.85
    )
 
    ax2.axvline(
        df['depth_m'].mean(),
        color='#f85149',
        linestyle='--',
        linewidth=1.5,
        label=f"Média: {df['depth_m'].mean():.2f}m"
    )
 
    ax2.legend(
        labelcolor=label_color,
        fontsize=8,
        facecolor='white',
        edgecolor=grid_color
    )
 
    style_ax(ax2, "Distribuição de Profundidade")
    ax2.set_xlabel("Profundidade (m)")
    ax2.set_ylabel("Número de pontos")
 
    # ── Gráfico 3: Distribuição de confiança ──
    ax3 = fig.add_subplot(gs[0, 2])
 
    conf_counts = df['confidence'].value_counts().reindex([0, 1, 2], fill_value=0).sort_index()
 
    colors_conf = ['#f85149', '#d29922', '#3fb950']
 
    bars = ax3.bar(
        ['Baixa\n(0)', 'Média\n(1)', 'Alta\n(2)'],
        conf_counts.values,
        color=colors_conf,
        edgecolor='none'
    )
 
    for bar, val in zip(bars, conf_counts.values):
        ax3.text(
            bar.get_x() + bar.get_width()/2,
            bar.get_height() + 500,
            f'{val/len(df)*100:.1f}%',
            ha='center',
            color=title_color,
            fontsize=8
        )
 
    style_ax(ax3, "Distribuição de Confiança")
    ax3.set_ylabel("Número de pontos")
 
    # ── Gráfico 4: Evolução temporal ──
    ax4 = fig.add_subplot(gs[1, :2])
 
    temporal = df.groupby('timestamp')['depth_m'].agg(['mean', 'std'])
 
    ax4.plot(
        temporal.index,
        temporal['mean'],
        color='#1f77b4',
        linewidth=1.5,
        label='Média'
    )
 
    ax4.fill_between(
        temporal.index,
        temporal['mean'] - temporal['std'],
        temporal['mean'] + temporal['std'],
        alpha=0.2,
        color='#1f77b4',
        label='±1 desvio padrão'
    )
 
    ax4.legend(
        labelcolor=label_color,
        fontsize=8,
        facecolor='white',
        edgecolor=grid_color
    )
 
    style_ax(ax4, "Profundidade Média ao Longo do Tempo")
    ax4.set_xlabel("Tempo (s)")
    ax4.set_ylabel("Profundidade (m)")
 
    # ── Gráfico 5: Ruído vs Distância ──
    ax5 = fig.add_subplot(gs[1, 2])
 
    sample = noise_df.sample(min(3000, len(noise_df)), random_state=42)
 
    sc = ax5.scatter(
        sample['depth_mean'],
        sample['depth_std'] * 100,
        c=sample['depth_mean'],
        cmap=heatmap_cmap,
        s=2,
        alpha=0.5,
        vmin=0.1,
        vmax=5.0
    )
 
    z = np.polyfit(sample['depth_mean'],
                   sample['depth_std'] * 100, 1)
 
    p = np.poly1d(z)
 
    x_line = np.linspace(0.1, 5.0, 100)
 
    ax5.plot(
        x_line,
        p(x_line),
        color='#f85149',
        linewidth=1.5,
        linestyle='--',
        label='Tendência'
    )
 
    ax5.legend(
        labelcolor=label_color,
        fontsize=8,
        facecolor='white',
        edgecolor=grid_color
    )
 
    style_ax(ax5, "Ruído vs Distância")
    ax5.set_xlabel("Distância média (m)")
    ax5.set_ylabel("Desvio padrão (cm)")
 
    # ── Gráfico 6: Mapa de ruído espacial ──
    ax6 = fig.add_subplot(gs[2, 0])
 
    noise_pivot = noise_df.pivot_table(
        index='y',
        columns='x',
        values='depth_std',
        aggfunc='mean'
    )
 
    noise_map = np.rot90(noise_pivot.values * 100, k=-1)
 
    im6 = ax6.imshow(
        noise_map,
        cmap='hot',
        aspect='auto',
        origin='upper'
    )
 
    plt.colorbar(im6, ax=ax6, label='cm').ax.yaxis.label.set_color(label_color)
 
    style_ax(ax6, "Mapa Espacial de Ruído")
    ax6.set_xlabel("Pixel X")
    ax6.set_ylabel("Pixel Y")
 
    # ── Gráfico 7: Boxplot por zona ──
    ax7 = fig.add_subplot(gs[2, 1])
 
    zones = ['<1m', '1-2m', '2-3m', '3-5m']
 
    data_by_zone = []
 
    for zone in zones:
        z_data = noise_df[noise_df['zone'] == zone]['depth_std'] * 100
        z_vals = z_data.values
        data_by_zone.append(z_vals if len(z_vals) > 0 else [0])
 
    bp = ax7.boxplot(
        data_by_zone,
        labels=zones,
        patch_artist=True,
        medianprops={'color': '#f85149', 'linewidth': 2}
    )
 
    zone_colors = ['#1f6feb', '#388bfd', '#58a6ff', '#79c0ff']
 
    for patch, color in zip(bp['boxes'], zone_colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)
 
    style_ax(ax7, "Ruído por Zona de Distância")
    ax7.set_xlabel("Zona")
    ax7.set_ylabel("Desvio padrão (cm)")
 
    # ── Gráfico 8: Pontos por frame ──
    ax8 = fig.add_subplot(gs[2, 2])
 
    pts_per_frame = df.groupby('timestamp').size()
 
    ax8.bar(
        range(len(pts_per_frame)),
        pts_per_frame.values,
        color='#8957e5',
        edgecolor='none',
        alpha=0.85
    )
 
    ax8.axhline(
        pts_per_frame.mean(),
        color='#f85149',
        linestyle='--',
        linewidth=1.5,
        label=f'Média: {pts_per_frame.mean():.0f}'
    )
 
    ax8.legend(
        labelcolor=label_color,
        fontsize=8,
        facecolor='white',
        edgecolor=grid_color
    )
 
    style_ax(ax8, "Pontos Capturados por Frame")
    ax8.set_xlabel("Frame #")
    ax8.set_ylabel("Número de pontos")
 
    # ── Título geral ──
    fig.suptitle(
        "Análise do Sensor LiDAR — iOS ARKit",
        color=title_color,
        fontsize=16,
        fontweight='bold',
        y=0.98
    )
 
    plt.savefig(
        "lidar_analysis.png",
        dpi=150,
        bbox_inches='tight',
        facecolor='white'
    )
 
    print("\n✅ Gráfico guardado: lidar_analysis.png")
 
    plt.close()
 
 
# ─────────────────────────────────────────────
# 4. GRÁFICOS INDIVIDUAIS (para o relatorio)
# ─────────────────────────────────────────────
def plot_individual(df, noise_df):
    """
    Grava graficos individuais, um por ficheiro, para insercao no relatorio.
    Reutiliza o mesmo codigo de desenho do painel, mas cada grafico fica
    numa figura propria.
    """
    heatmap_colors = ['#0000ff', '#00ffff', '#00ff00', '#ffff00', '#ff0000']
    heatmap_cmap = LinearSegmentedColormap.from_list('lidar', heatmap_colors)
 
    title_color = "#111111"
    label_color = '#333333'
    grid_color  = '#cccccc'
 
    def style_ax(ax, title):
        ax.set_facecolor('white')
        ax.set_title(title, color=title_color, fontsize=12, pad=8)
        ax.tick_params(colors=label_color, labelsize=9)
        ax.xaxis.label.set_color(label_color)
        ax.yaxis.label.set_color(label_color)
        for spine in ax.spines.values():
            spine.set_edgecolor(grid_color)
        ax.grid(True, color=grid_color, linewidth=0.5, alpha=0.7)
 
    # ── Mapa de profundidade (1 frame) ──
    fig, ax = plt.subplots(figsize=(6, 5))
    fig.patch.set_facecolor('white')
    mid_ts = df['timestamp'].unique()[len(df['timestamp'].unique())//2]
    frame = df[df['timestamp'] == mid_ts]
    pivot = frame.pivot_table(index='y', columns='x', values='depth_m', aggfunc='mean')
    heatmap = np.rot90(pivot.values, k=-1)
    im = ax.imshow(heatmap, cmap=heatmap_cmap, aspect='auto',
                   vmin=frame['depth_m'].quantile(0.02),
                   vmax=frame['depth_m'].quantile(0.98), origin='upper')
    plt.colorbar(im, ax=ax, label='metros').ax.yaxis.label.set_color(label_color)
    style_ax(ax, "Mapa de Profundidade (1 frame)")
    ax.set_xlabel("Pixel X")
    ax.set_ylabel("Pixel Y")
    fig.savefig("grafico_profundidade_mapa.png", dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
 
    # ── Distribuição de profundidade ──
    fig, ax = plt.subplots(figsize=(6, 4))
    fig.patch.set_facecolor('white')
    ax.hist(df['depth_m'], bins=60, color='#238636', edgecolor='none', alpha=0.85)
    ax.axvline(df['depth_m'].mean(), color='#f85149', linestyle='--', linewidth=1.5,
               label=f"Média: {df['depth_m'].mean():.2f}m")
    ax.legend(labelcolor=label_color, fontsize=9, facecolor='white', edgecolor=grid_color)
    style_ax(ax, "Distribuição de Profundidade")
    ax.set_xlabel("Profundidade (m)")
    ax.set_ylabel("Número de pontos")
    fig.savefig("grafico_profundidade.png", dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
 
    # ── Distribuição de confiança ──
    fig, ax = plt.subplots(figsize=(6, 4))
    fig.patch.set_facecolor('white')
    conf_counts = df['confidence'].value_counts().reindex([0, 1, 2], fill_value=0).sort_index()
    bars = ax.bar(['Baixa\n(0)', 'Média\n(1)', 'Alta\n(2)'], conf_counts.values,
                  color=['#f85149', '#d29922', '#3fb950'], edgecolor='none')
    for bar, val in zip(bars, conf_counts.values):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 500,
                f'{val/len(df)*100:.1f}%', ha='center', color=title_color, fontsize=9)
    style_ax(ax, "Distribuição de Confiança")
    ax.set_ylabel("Número de pontos")
    fig.savefig("grafico_confianca.png", dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
 
    # ── Pontos por frame ──
    fig, ax = plt.subplots(figsize=(6, 4))
    fig.patch.set_facecolor('white')
    pts = df.groupby('timestamp').size()
    ax.bar(range(len(pts)), pts.values, color='#8957e5', edgecolor='none', alpha=0.85)
    ax.axhline(pts.mean(), color='#f85149', linestyle='--', linewidth=1.5,
               label=f'Média: {pts.mean():.0f}')
    ax.legend(labelcolor=label_color, fontsize=9, facecolor='white', edgecolor=grid_color)
    style_ax(ax, "Pontos Capturados por Frame")
    ax.set_xlabel("Frame #")
    ax.set_ylabel("Número de pontos")
    fig.savefig("grafico_pontos_frame.png", dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
 
    print("✅ Gráficos individuais guardados:")
    print("   grafico_profundidade_mapa.png")
    print("   grafico_profundidade.png")
    print("   grafico_confianca.png")
    print("   grafico_pontos_frame.png")
 
 
# ─────────────────────────────────────────────
# 5. EXPORTAR CSV (amostra para testes/consulta)
# ─────────────────────────────────────────────
def export_sample_csv(df):
    path = "lidar_sample_data.csv"
    df.to_csv(path, index=False)
    print(f"✅ CSV de exemplo guardado: lidar_sample_data.csv")
 
 
# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
if __name__ == "__main__":
    print("🔬 A iniciar análise LiDAR...\n")
 
    # Substitui pelo nome do CSV real exportado pela app.
    df = pd.read_csv("lidar_20260605_142413_highres.csv")
 
    print_statistics(df)
    noise_df = analyze_noise(df)
    plot_all(df, noise_df)
    plot_individual(df, noise_df)
    export_sample_csv(df)
 
    print("\n✅ Análise completa!")