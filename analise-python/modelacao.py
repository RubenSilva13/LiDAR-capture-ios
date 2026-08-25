"""
Modelacao do ruido do sensor LiDAR - iPhone 14 Pro
 
Grafico do modelo de ruido (painel unico) a partir de 15 capturas
(3 replicas por distancia). O ajuste e feito sobre todos os 15 pontos;
a visualizacao mostra a media e a dispersao (desvio padrao) das tres
replicas de cada distancia.
"""
 
import pandas as pd
import numpy as np
from scipy.optimize import curve_fit
import matplotlib
matplotlib.rcParams['font.family'] = 'DejaVu Sans'
import matplotlib.pyplot as plt
 
# --- Ajusta os nomes aos teus ficheiros reais ---
ficheiros_distancias = [
    ('lidar_2.5m1.csv', 2.5),
    ('lidar_2.5m2.csv', 2.5),
    ('lidar_2.5m3.csv', 2.5),
    ('lidar_2.0m1.csv', 2.0),
    ('lidar_2.0m2.csv', 2.0),
    ('lidar_2.0m3.csv', 2.0),
    ('lidar_1.5m1.csv', 1.5),
    ('lidar_1.5m2.csv', 1.5),
    ('lidar_1.5m3.csv', 1.5),
    ('lidar_1.0m1.csv', 1.0),
    ('lidar_1.0m2.csv', 1.0),
    ('lidar_1.0m3.csv', 1.0),
    ('lidar_0.5m1.csv', 0.5),
    ('lidar_0.5m2.csv', 0.5),
    ('lidar_0.5m3.csv', 0.5),
]
 
# --- sigma por captura ---
dists_todas, sigmas_todas = [], []
for ficheiro, d in ficheiros_distancias:
    df = pd.read_csv(ficheiro)
    margem = d * 0.30
    df_f = df[(df['depth_m'] >= d - margem) & (df['depth_m'] <= d + margem)]
    dists_todas.append(d)
    sigmas_todas.append(df_f['depth_m'].std())
 
dists_todas = np.array(dists_todas)
sigmas_todas = np.array(sigmas_todas)
 
# --- ajuste sobre TODOS os 15 pontos ---
def modelo_potencia(d, a, b):
    return a * np.power(d, b)
 
popt, _ = curve_fit(modelo_potencia, dists_todas, sigmas_todas, p0=[0.05, 1.5])
a, b = popt
 
sigmas_prev = modelo_potencia(dists_todas, a, b)
residuos = sigmas_todas - sigmas_prev
r2 = 1 - np.sum(residuos ** 2) / np.sum((sigmas_todas - np.mean(sigmas_todas)) ** 2)
rmse = np.sqrt(np.mean(residuos ** 2))
 
print(f"sigma(d) = {a:.4f} x d^{b:.4f}")
print(f"R2 = {r2:.4f}   RMSE = {rmse * 100:.1f} cm")
 
# --- media e dispersao por distancia (para o grafico) ---
distancias  = np.unique(dists_todas)
sigma_media = np.array([sigmas_todas[dists_todas == d].mean() for d in distancias])
sigma_std   = np.array([sigmas_todas[dists_todas == d].std()  for d in distancias])
 
print("\nResumo por distancia (media das 3 replicas):")
for d, sm in zip(distancias, sigma_media):
    print(f"  d={d:.1f}m: sigma_medio={sm:.4f}m")
 
# --- grafico (painel unico) ---
d_curva = np.linspace(0.3, 3.0, 200)
sigma_curva = modelo_potencia(d_curva, a, b)
 
fig, ax = plt.subplots(figsize=(7, 5))
ax.errorbar(distancias, sigma_media, yerr=sigma_std, fmt='o', color='steelblue',
            markersize=8, capsize=4, zorder=5,
            label='sigma real (mean +/- sd, n=3)')
ax.plot(d_curva, sigma_curva, color='tomato', linewidth=2,
        label=f'sigma(d) = {a:.4f} x d^{b:.4f}')
ax.set_xlabel('Distancia (m)')
ax.set_ylabel('Desvio padrao (m)')
ax.set_title('Modelo de ruído do sensor LiDAR - iPhone 14 Pro')
ax.legend()
ax.grid(True, alpha=0.3)
ax.set_xlim(0, 3.0)
ax.set_ylim(0, 0.30)
ax.annotate(f'a = {a:.4f}\nb = {b:.4f}\nR2 = {r2:.3f}',
            xy=(1.55, 0.04), fontsize=10,
            bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', alpha=0.8))
 
plt.tight_layout()
plt.savefig('modelo_ruido_lidar_novo.png', dpi=150, bbox_inches='tight')
print("\nGrafico guardado: modelo_ruido_lidar_novo.png")
plt.show()