import SwiftUI

struct DownloadListView: View {
    @StateObject private var engine = DownloadEngine.shared
    
    // 模拟数据，后续接入真实 API 替换
    private let mockFiles: [CloudFile] = [
        CloudFile(id: "1", name: "测试视频.mp4", size: 1_000_000_000, downloadURL: URL(string: "https://example.com/file1")!),
        CloudFile(id: "2", name: "压缩包.zip", size: 500_000_000, downloadURL: URL(string: "https://example.com/file2")!)
    ]
    
    var body: some View {
        NavigationStack {
            List(mockFiles) { file in
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name).font(.headline)
                    HStack {
                        Text(file.formattedSize).font(.subheadline).foregroundColor(.gray)
                        Spacer()
                        Button("下载") {
                            engine.startDownload(file: file)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("迅盘 SwiftPan")
        }
    }
}