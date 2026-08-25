# LiDAR Capture — Captura e Modelação 3D em iOS

Aplicação iOS para captura de dados tridimensionais com o sensor **LiDAR** do iPhone, acompanhada de um pipeline de análise em **Python** que caracteriza a precisão do sensor em função da distância.

Projeto de final de curso da Licenciatura em Engenharia Informática — Escola Superior de Tecnologia e Gestão do Instituto Politécnico de Bragança (ESTiG/IPB).

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-2396F3?style=flat&logo=swift&logoColor=white)
![ARKit](https://img.shields.io/badge/ARKit-000000?style=flat&logo=apple&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)

## Demonstração

<p align="center">
  <a href="https://youtu.be/zCv5jK-K-5s">
    <img src="https://img.youtube.com/vi/zCv5jK-K-5s/hqdefault.jpg" width="480" alt="Ver demonstração no YouTube">
  </a>
</p>

<p align="center"><b>▶ <a href="https://youtu.be/zCv5jK-K-5s">Ver a demonstração no YouTube</a></b> — 4 min, a aplicação a capturar em tempo real nos três modos.</p>

## Sobre o projeto

O objetivo foi estudar as capacidades do sensor LiDAR presente nos iPhones Pro para captura 3D, desenvolvendo uma aplicação nativa que explora diferentes técnicas de captura e um pipeline que quantifica o erro do sensor. O trabalho combina desenvolvimento mobile, computação gráfica 3D e análise de dados, e deu origem a um artigo submetido à conferência **TEEM 2026**.

## Funcionalidades

A aplicação oferece três modos de captura:

- **Modo Espaço** — reconstrução da malha (*mesh*) do ambiente em tempo real, exportável em `.obj`.
- **Modo Objeto** — captura da nuvem de pontos de um objeto isolado, delimitada por uma *bounding box* ajustável pelo utilizador; exportação em `.csv` e `.ply`.
- **Modo Objeto + Fotos** — combina a captura LiDAR com fotogrametria (conjunto de imagens gerido pelo `PhotoSetManager`) para reconstruções de maior detalhe.

Inclui ainda visualização em tempo real da captura, mapa de profundidade (*depth heatmap*) e ecrã de resultados.

## Tecnologias

**Aplicação iOS:** Swift · SwiftUI · ARKit · SceneKit

**Análise e modelação:** Python (NumPy, pandas, Matplotlib, SciPy) · CloudCompare · Meshroom (fotogrametria)

**Documentação:** LaTeX

## Resultados

**Modelo de ruído do sensor.** A partir de capturas a diferentes distâncias, ajustou-se um modelo que descreve o desvio-padrão do erro (σ) em função da distância (d):

<p align="center">
  <b>σ(d) = 0.044 · d<sup>1.91</sup></b> &nbsp;—&nbsp; R² = 0.97 &nbsp;·&nbsp; RMSE = 1.5 cm
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/a23e8eb2-5f97-44d5-8feb-6b064c9afbdd" width="560" alt="Modelo de ruído do sensor LiDAR">
</p>

O expoente próximo de 2 indica que o ruído cresce de forma quase quadrática com a distância ao sensor.

**Fotogrametria.** Foram testados vários objetos, com resultados dependentes da textura da superfície: objetos com textura rica foram reconstruídos com sucesso, enquanto superfícies lisas e sem textura falharam quase por completo — evidenciando a limitação da fotogrametria perante a ausência de detalhe visual.

## Galeria

<!-- Reordena ou muda as legendas (alt) à vontade -->
<p align="center">
  <img src="https://github.com/user-attachments/assets/3994cec0-910e-43c3-8828-dfe78d9f5198" width="240" alt="Aplicação em captura">
  &nbsp;
  <img src="https://github.com/user-attachments/assets/3a90b05d-e637-4517-8fbf-a41e4b443764" width="240" alt="Reconstrução 3D">
  &nbsp;
  <img src="https://github.com/user-attachments/assets/2e70fc9e-ebb3-4583-920f-6c9bcf0da673" width="240" alt="Reconstrução 3D — vista frontal">
</p>

## Estrutura do repositório

```
LiDAR-capture-ios/
├── LidarCapture/       # Aplicação iOS (Swift, SwiftUI, ARKit)
├── analise-python/     # Scripts de análise e modelação (Python)
├── report/             # Relatório do projeto (LaTeX)
└── README.md
```

## Como executar

**Aplicação iOS**

1. Requisitos: macOS com Xcode 16 e um iPhone com sensor LiDAR (iPhone 12 Pro ou posterior).
2. Abrir `LidarCapture/LidarCapture.xcodeproj` no Xcode.
3. Selecionar o dispositivo físico e correr (o LiDAR não existe no simulador).

**Pipeline de análise (Python)**

```
pip install numpy pandas matplotlib scipy
python analise-python/lidar_analysis2.py
```

## Autor

**Ruben Silva** — Licenciatura em Engenharia Informática, ESTiG/IPB

Orientação: Prof. Paulo Matos · Co-orientação: Prof. Pedro Filipe Oliveira
