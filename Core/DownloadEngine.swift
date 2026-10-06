import Foundation

/// 多线程下载引擎骨架
/// 1. 使用 URLSession background configuration 实现后台保活
/// 2. 通过 HTTP Range 请求实现分段下载
final class DownloadEngine: NSObject, ObservableObject {
    static let shared = DownloadEngine()
    
    @Published var activeTasks: [URLSessionDownloadTask] = []
    
    private lazy var session: URLSession = {
        // 使用后台会话保活
        let config = URLSessionConfiguration.background(withIdentifier: "com.swiftpan.download")
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
    }
    
    /// 开始下载（分段逻辑后续再细化）
    func startDownload(file: CloudFile) {
        let task = session.downloadTask(with: file.downloadURL)
        task.resume()
        activeTasks.append(task)
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadEngine: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 下载完成，移动到沙盒目录
        print("下载完成: \(location)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print("进度: \(String(format: "%.2f", progress * 100))%")
    }
}