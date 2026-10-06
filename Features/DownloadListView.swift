import SwiftUI

struct DownloadListView: View {
    @StateObject private var engine = DownloadEngine.shared
    
    private let mockFiles: [CloudFile] = [
        CloudFile(id: "1", name: "测试视频.mp4", size: 1_000_000_000, downloadURL: URL(string: "https://speed.hetzner.de/100MB.bin")!),
        CloudFile(id: "2", name: "压缩包.zip", size: 500_000_000, downloadURL: URL(string: "https://speed.hetzner.de/100MB.bin")!)
    ]
    
    var body: some View {
        NavigationStack {
            List(mockFiles) { file in
                VStack(alignment: .leading, spacing: 8) {
                    Text(file.name).font(.headline)
                    
                    HStack {
                        Text(file.formattedSize).font(.subheadline).foregroundColor(.gray)
                        Spacer()
                        
                        if let progress = engine.progressMap[file.id] {
                            HStack(spacing: 8) {
                                ProgressView(value: progress)
                                    .frame(width: 80)
                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        } else {
                            Button("下载") {
                                engine.startDownload(file: file) { result in
                                    switch result {
                                    case .success(let url):
                                        print("✅ 下载成功，保存到: \(url.path)")
                                    case .failure(let error):
                                        print("❌ 下载失败: \(error.localizedDescription)")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("迅盘 SwiftPan")
        }
    }
}