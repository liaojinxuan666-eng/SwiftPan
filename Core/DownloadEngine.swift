import Foundation
import Combine

final class DownloadEngine: NSObject, ObservableObject {
    static let shared = DownloadEngine()

    // 进度字典：file.id -> Progress
    @Published var progressMap: [String: Double] = [:]
    
    private let maxConcurrentChunks = 8 // 并发分片数，建议 8-16
    private var currentSession: URLSession?
    
    private override init() {
        super.init()
    }

    /// 开始多线程分段下载
    func startDownload(file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        // 如果已经存在任务，就不重复下载
        guard progressMap[file.id] == nil else { return }
        progressMap[file.id] = 0.0
        
        // 1. 先探测文件大小 (HEAD 请求)
        var request = URLRequest(url: file.downloadURL)
        request.httpMethod = "HEAD"
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.currentSession = session
        
        session.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  let contentLengthStr = httpResponse.allHeaderFields["Content-Length"] as? String,
                  let totalSize = Int64(contentLengthStr), totalSize > 0 else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "无法获取文件大小", code: -1))) }
                return
            }
            
            // 2. 计算每个分片的大小
            let chunkSize = totalSize / Int64(self.maxConcurrentChunks)
            let group = DispatchGroup()
            var errors: [Error] = []
            let lock = NSLock()
            
            // 临时文件夹存放分片
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(file.id)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            for i in 0..<self.maxConcurrentChunks {
                let start = Int64(i) * chunkSize
                let end = (i == self.maxConcurrentChunks - 1) ? totalSize - 1 : (start + chunkSize - 1)
                
                var chunkRequest = URLRequest(url: file.downloadURL)
                chunkRequest.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
                
                group.enter()
                session.dataTask(with: chunkRequest) { data, _, chunkError in
                    defer { group.leave() }
                    
                    if let chunkError = chunkError {
                        lock.lock(); errors.append(chunkError); lock.unlock()
                        return
                    }
                    
                    guard let data = data else { return }
                    
                    // 写入分片文件
                    let chunkPath = tempDir.appendingPathComponent("chunk_\(i)")
                    try? data.write(to: chunkPath)
                    
                    // 更新进度
                    DispatchQueue.main.async {
                        let currentProgress = (self.progressMap[file.id] ?? 0.0) + (Double(data.count) / Double(totalSize))
                        self.progressMap[file.id] = min(currentProgress, 1.0)
                    }
                }.resume()
            }
            
            // 3. 等待所有分片下载完成并合并
            group.notify(queue: .global()) {
                if !errors.isEmpty {
                    DispatchQueue.main.async { completion(.failure(errors.first!)) }
                    return
                }
                
                let finalDest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(file.name)
                
                do {
                    if FileManager.default.fileExists(atPath: finalDest.path) {
                        try FileManager.default.removeItem(at: finalDest)
                    }
                    
                    // 合并文件
                    FileManager.default.createFile(atPath: finalDest.path, contents: nil)
                    let fileHandle = try FileHandle(forWritingTo: finalDest)
                    
                    for i in 0..<self.maxConcurrentChunks {
                        let chunkPath = tempDir.appendingPathComponent("chunk_\(i)")
                        if let chunkData = try? Data(contentsOf: chunkPath) {
                            fileHandle.write(chunkData)
                        }
                    }
                    fileHandle.closeFile()
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: tempDir)
                    
                    DispatchQueue.main.async {
                        self.progressMap.removeValue(forKey: file.id)
                        completion(.success(finalDest))
                    }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        }.resume()
    }
}

extension DownloadEngine: URLSessionDelegate {
    // 后续如果想处理后台下载的证书校验，可以在这里扩展
}