import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CapturaView()
                .tabItem { Label("Captura", systemImage: "camera.fill") }
            AnaliseView()
                .tabItem { Label("Análise", systemImage: "chart.bar.fill") }
            NuvemView()
                .tabItem { Label("Nuvem", systemImage: "cube.fill") }
            ResultadosView()
                .tabItem { Label("Resultados", systemImage: "list.bullet") }
            InfoView()
                .tabItem { Label("Info", systemImage: "info.circle.fill") }
        }
    }
}
