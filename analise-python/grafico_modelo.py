import pandas as pd
import numpy as np
from scipy.optimize import curve_fit
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'DejaVu Sans'
 
ficheiros_distancias = [
    ('lidar_20260516_143236_normal.csv', 2.5),
    ('lidar_20260516_143403_normal.csv', 2.0),
    ('lidar_20260516_143512_normal.csv', 1.5),
    ('lidar_20260516_143653_normal.csv', 1.0),
    ('lidar_20260516_143751_normal.csv', 0.5),
]
 
resultados = []
for ficheiro, dist_esperada in ficheiros_distancias:
    df = pd.read_csv(ficheiro)
    margem = dist_esperada * 0.30
    df_f = df[(df['depth_m'] >= dist_esperada - margem) &
              (df['depth_m'] <= dist_esperada + margem)]
    resultados.append((dist_esperada, df_f['depth_m'].mean(), df_f['depth_m'].std()))
 
distancias = np.array([r[0] for r in resultados])
medias     = np.array([r[1] for r in resultados])
sigmas     = np.array([r[2] for r in resultados])
 
def modelo_potencia(d, a, b):
    return a * np.power(d, b)
 
popt, _ = curve_fit(modelo_potencia, distancias, sigmas, p0=[0.05, 1.5])
a, b = popt
 
d_curva = np.linspace(0.3, 3.0, 200)
sigma_curva = modelo_potencia(d_curva, a, b)
 
fig, axes = plt.subplots(1, 2, figsize=(12, 5))
fig.suptitle('LiDAR Sensor Noise Modelling - iPhone 14 Pro', fontsize=13, fontweight='bold')
 
# --- Graph 1: noise model ---
ax1 = axes[0]
ax1.scatter(distancias, sigmas, color='steelblue', s=80, zorder=5, label='real sigma (data)')
ax1.plot(d_curva, sigma_curva, color='tomato', linewidth=2,
         label=f'sigma(d) = {a:.4f} x d^{b:.4f}')
ax1.set_xlabel('Distance (m)')
ax1.set_ylabel('Standard deviation sigma (m)')
ax1.set_title('Noise Model: sigma(d) = a x d^b')
ax1.legend()
ax1.grid(True, alpha=0.3)
ax1.set_xlim(0, 3.0)
ax1.set_ylim(0, 0.30)
 
# Formula annotation
ax1.annotate(f'a = {a:.4f}\nb = {b:.4f}',
             xy=(1.6, 0.05), fontsize=10,
             bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', alpha=0.8))
 
# --- Graph 2: measured mean vs real distance ---
ax2 = axes[1]
ax2.scatter(distancias, medias, color='steelblue', s=80, zorder=5, label='measured mean')
ax2.plot([0, 3], [0, 3], 'k--', linewidth=1.5, alpha=0.5, label='ideal line (y=x)')
ax2.set_xlabel('Real distance (m)')
ax2.set_ylabel('Mean measured distance (m)')
ax2.set_title('Measurement Accuracy: Real vs Measured')
ax2.legend()
ax2.grid(True, alpha=0.3)
ax2.set_xlim(0, 3.0)
ax2.set_ylim(0, 3.0)
 
plt.tight_layout()
plt.savefig('modelo_ruido_lidar.png', dpi=150, bbox_inches='tight')
print("Graph saved: modelo_ruido_lidar.png")
plt.show()