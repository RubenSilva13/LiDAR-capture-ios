LiDAR Capture — Captura e Modelação 3D em iOS

Aplicação iOS para captura de dados tridimensionais com o sensor LiDAR do iPhone, acompanhada de um pipeline de análise em Python que caracteriza a precisão do sensor em função da distância.

Projeto de final de curso da Licenciatura em Engenharia Informática — Escola Superior de Tecnologia e Gestão do Instituto Politécnico de Bragança (ESTiG/IPB).

Demonstração

Mostrar Imagem

Vídeo (4 min) com a aplicação a capturar em tempo real nos três modos.

Sobre o projeto

O objetivo foi estudar as capacidades do sensor LiDAR presente nos iPhones Pro para captura 3D, desenvolvendo uma aplicação nativa que explora diferentes técnicas de captura e um pipeline que quantifica o erro do sensor. O trabalho combina desenvolvimento mobile, computação gráfica 3D e análise de dados, e deu origem a um artigo submetido à conferência TEEM 2026.

Funcionalidades

A aplicação oferece três modos de captura:

Modo Espaço — reconstrução da malha (mesh) do ambiente em tempo real, exportável em .obj.
Modo Objeto — captura da nuvem de pontos de um objeto isolado, delimitada por uma bounding box ajustável pelo utilizador; exportação em .csv e .ply.
Modo Objeto + Fotos — combina a captura LiDAR com fotogrametria (conjunto de imagens gerido pelo PhotoSetManager) para reconstruções de maior detalhe.

Inclui ainda visualização em tempo real da captura, mapa de profundidade (depth heatmap) e ecrã de resultados.

Tecnologias

Aplicação iOS

Swift · SwiftUI · ARKit · SceneKit

Análise e modelação

Python (NumPy, pandas, Matplotlib, SciPy)
CloudCompare — inspeção e processamento de nuvens de pontos
Meshroom — reconstrução por fotogrametria

Documentação

LaTeX
Resultados

Modelo de ruído do sensor. A partir de capturas a diferentes distâncias, ajustou-se um modelo que descreve o desvio-padrão do erro (σ) em função da distância (d):

<p align="center"> <b>σ(d) = 0.044 · d<sup>1.91</sup></b> &nbsp;&nbsp;—&nbsp;&nbsp; R² = 0.97 &nbsp;·&nbsp; RMSE = 1.5 cm </p>

O expoente próximo de 2 indica que o ruído cresce de forma quase quadrática com a distância ao sensor.

Fotogrametria. Foram testados cinco objetos, com resultados dependentes da textura da superfície: objetos com textura rica foram reconstruídos com sucesso total (ex.: vaso com planta, 61/61 imagens alinhadas), enquanto superfícies lisas e sem textura falharam quase por completo (ex.: chávena branca) — evidenciando a limitação da fotogrametria perante a ausência de detalhe visual.

Estrutura do repositório
LiDAR-capture-ios/
├── LidarCapture/       # Aplicação iOS (Swift, SwiftUI, ARKit)
├── report/             # Relatório do projeto (LaTeX)
├── csv_to_ply2.py      # Conversão de nuvens de pontos CSV → PLY
├── modelacao.py        # Ajuste do modelo de ruído σ(d)
├── grafico_modelo.py   # Geração dos gráficos do modelo
├── lidar_analysis2.py  # Análise dos dados do sensor
└── README.md
Como executar

Aplicação iOS

Requisitos: macOS com Xcode 16 e um iPhone com sensor LiDAR (iPhone 12 Pro ou posterior; desenvolvido em iPhone 14 Pro).
Abrir LidarCapture/LidarCapture.xcodeproj no Xcode.
Selecionar o dispositivo físico e correr.

O sensor LiDAR não está disponível no simulador — é necessário um dispositivo real.

Pipeline de análise (Python)

bash
pip install numpy pandas matplotlib scipy
python lidar_analysis2.py
Autor

Ruben Silva — Licenciatura em Engenharia Informática, ESTiG/IPB

Orientação: Prof. Paulo Matos · Co-orientação: Prof. Pedro Filipe Oliveira
