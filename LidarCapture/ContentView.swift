import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CaptureViewModel()

    var body: some View {
        TabView {
            ScannerView()
                .environmentObject(vm)
                .tabItem {
                    Label("Captura", systemImage: "camera.fill")
                }

            AnaliseView()
                .environmentObject(vm)
                .tabItem {
                    Label("Análise", systemImage: "chart.bar.fill")
                }

            NuvemView()
                .environmentObject(vm)
                .tabItem {
                    Label("Nuvem", systemImage: "cube.fill")
                }

            ResultadosView()
                .tabItem {
                    Label("Resultados", systemImage: "list.bullet")
                }

            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
        }
    }
}
