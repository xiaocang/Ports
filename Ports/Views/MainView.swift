//
//  ContentView.swift
//  Ports
//
//  Created by Andreas Ganske on 05.05.21.
//

import SwiftUI
import ShellOut

struct IdentifiableError: Error, Identifiable {
    var id: UUID = UUID()
    var error: Error

    var localizedDescription: String { error.localizedDescription }
}

struct MainView<ViewModelType: MainViewModelType>: View {
    @ObservedObject var viewModel: ViewModelType
    @State var error: IdentifiableError?
    @State var hoveredProcess: Process?
    @State var searchText: String = ""

    var filteredProcesses: [Process] {
        let processes = viewModel.processList.processes
        guard !searchText.isEmpty else { return processes }
        let query = searchText.lowercased()
        return processes.compactMap { process -> Process? in
            // If name or pid matches, show all sockets
            if process.name.lowercased().contains(query) || String(process.pid).contains(query) {
                return process
            }
            // Otherwise, filter sockets that match
            let matchingSockets = process.sockets.filter { socket in
                String(socket.port).contains(query) || socket.address.lowercased().contains(query)
            }
            if matchingSockets.isEmpty {
                return nil
            }
            return Process(pid: process.pid, name: process.name, sockets: matchingSockets)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search by name, port, or address...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List(filteredProcesses, id: \.id) { item in
                ProcessView(item: item, hovered: $hoveredProcess, error: $error)
                    .onTapGesture {
                        viewModel.update()
                    }
            }
            .listStyle(.sidebar)
            .id(searchText)
            HStack {
                Spacer()
                Menu {
                    Button(localizedString("openWebsite")) {
                        NSWorkspace.shared.open(URL(string: "https://chaosspace.de/ports?utm_source=portsapp")!)
                    }
                    Button(localizedString("quit")) {
                        exit(0)
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
            }
        }
        .alert(item: $error, content: { error in
            Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

protocol MainViewModelType: ObservableObject {
    var processList: ProcessList { get }
    var lastUpdateFormatter: DateFormatter { get }

    func update()
}

class MainViewModel: ObservableObject, MainViewModelType {
    private let processManager: ProcessManager
    @Published var processList: ProcessList

    init(processManager: ProcessManager) {
        self.processManager = processManager
        self.processList = processManager.processList
        processManager.$processList.assign(to: &$processList)
    }

    var lastUpdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    func update() {
        self.processManager.update()
    }
}

class PreviewMainViewModel: MainViewModelType {

    let processList: ProcessList

    init() {
        let processA = Process(pid: 1,
                               name: "A longer process name",
                               sockets: [Socket(fd: "1u", type: .IPv4, address: "127.0.0.1", port: 1337),
                                         Socket(fd: "1u", type: .IPv6, address: "*", port: 8080)])
        let processB = Process(pid: 2,
                               name: "xcodecd",
                               sockets: [Socket(fd: "2u", type: .IPv4, address: "127.0.0.1", port: 8080)])

        processList = ProcessList(lastUpdated: Date(),
                                  processes: [processA, processB])
    }

    var lastUpdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    func update() {
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewModel: PreviewMainViewModel())
            .previewLayout(.fixed(width: 300, height: 600))
    }
}
