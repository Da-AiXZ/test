import SwiftUI
import Foundation
import Darwin

// MARK: - Test Result Model

struct TestResult: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    var status: TestStatus = .pending
    var detail: String = ""
    
    enum TestStatus {
        case pending, running, passed, failed
        var icon: String {
            switch self {
            case .pending: return "⏳"
            case .running: return "🔄"
            case .passed:  return "✅"
            case .failed:  return "❌"
            }
        }
        var color: String {
            switch self {
            case .passed:  return "green"
            case .failed:  return "red"
            default:       return "gray"
            }
        }
    }
}

// MARK: - System Info

struct SystemInfo {
    var deviceModel: String = ""
    var osVersion: String = ""
    var appSandboxPath: String = ""
}

// MARK: - Content View

struct ContentView: View {
    @State private var systemInfo = SystemInfo()
    @State private var testResults: [TestResult] = [
        TestResult(name: "文件系统访问", 
                   description: "测试 no-sandbox 是否能访问 /var/mobile/"),
        TestResult(name: "进程创建", 
                   description: "测试 posix_spawn 是否能创建子进程"),
        TestResult(name: "动态库加载", 
                   description: "测试 dlopen 是否能加载动态库"),
        TestResult(name: "写入文件", 
                   description: "测试是否能在 /var/mobile/Documents/ 创建文件"),
        TestResult(name: "Shell执行", 
                   description: "测试能否用 system() 执行 shell 命令"),
    ]
    @State private var isRunningAll = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    systemInfoSection
                    
                    // Tests
                    Text("🔬 沙盒逃逸测试")
                        .font(.title2)
                        .bold()
                        .padding(.top, 8)
                    
                    ForEach($testResults) { $result in
                        TestResultCard(result: $result) {
                            runTest($result)
                        }
                    }
                    
                    // Run All Button
                    Button(action: runAllTests) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("运行全部测试")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunningAll ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRunningAll)
                    .padding(.top, 8)
                    
                    // Info
                    infoSection
                }
                .padding()
            }
            .navigationTitle("白泽 - 可行性测试")
            .onAppear {
                collectSystemInfo()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - System Info Section
    
    var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📱 设备信息")
                .font(.headline)
            Text("设备: \(systemInfo.deviceModel)")
            Text("系统: iOS \(systemInfo.osVersion)")
            Text("沙盒路径: \(systemInfo.appSandboxPath)")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Info Section
    
    var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📋 说明")
                .font(.headline)
            Text("""
            这个 App 测试你的 iPad 是否具备运行本地 AI 编程助手的能力。
            
            必须全部 ✅ 才能运行白泽。
            
            网络连接失败不影响测试——这些测试都是本地的。
            
            测试完成后请截图发给我。
            """)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - System Info Collection
    
    func collectSystemInfo() {
        systemInfo.deviceModel = UIDevice.current.model
        systemInfo.osVersion = UIDevice.current.systemVersion
        
        // Get app sandbox path
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        systemInfo.appSandboxPath = paths.first?.path ?? "Unknown"
    }
    
    // MARK: - Run All Tests
    
    func runAllTests() {
        isRunningAll = true
        
        // Reset all results
        for i in testResults.indices {
            testResults[i].status = .pending
            testResults[i].detail = ""
        }
        
        // Run sequentially
        DispatchQueue.global(qos: .userInitiated).async {
            for i in testResults.indices {
                DispatchQueue.main.async {
                    testResults[i].status = .running
                }
                runTestSync(i)
            }
            DispatchQueue.main.async {
                isRunningAll = false
            }
        }
    }
    
    // MARK: - Run Single Test
    
    func runTest(_ result: TestResult) {
        // Find the index
        guard let idx = testResults.firstIndex(where: { $0.id == result.id }) else { return }
        testResults[idx].status = .running
        DispatchQueue.global(qos: .userInitiated).async {
            runTestSync(idx)
        }
    }
    
    func runTestSync(_ idx: Int) {
        var result = testResults[idx]
        let detail: (Bool, String)
        
        switch idx {
        case 0: detail = testFileSystemAccess()
        case 1: detail = testProcessSpawn()
        case 2: detail = testDynamicLibrary()
        case 3: detail = testFileWrite()
        case 4: detail = testSystemCall()
        default: detail = (false, "Unknown test")
        }
        
        result.status = detail.0 ? .passed : .failed
        result.detail = detail.1
        
        DispatchQueue.main.async {
            testResults[idx] = result
        }
    }
    
    // MARK: - Test 1: File System Access
    
    func testFileSystemAccess() -> (Bool, String) {
        let testPaths = [
            "/var/mobile/",
            "/var/mobile/Documents/",
            "/var/",
            "/tmp/",
        ]
        
        var details: [String] = []
        
        for path in testPaths {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: path) {
                let count = contents.count
                let preview = contents.prefix(5).joined(separator: ", ")
                details.append("✅ \(path) (\(count) 项): \(preview)...")
            } else {
                let exists = fm.fileExists(atPath: path)
                if exists {
                    details.append("⚠️ \(path): 存在但无法列出（可能无读取权限）")
                } else {
                    details.append("❌ \(path): 不存在或无权限")
                }
            }
        }
        
        // Check if at least /var/mobile/ is accessible
        let fm = FileManager.default
        let canAccessVar = (try? fm.contentsOfDirectory(atPath: "/var/mobile/")) != nil
        
        return (canAccessVar, details.joined(separator: "\n"))
    }
    
    // MARK: - Test 2: Process Spawn
    
    func testProcessSpawn() -> (Bool, String) {
        // Try posix_spawn with /bin/ls
        let command = "/bin/ls"
        let args = [command, "/var/mobile/"]
        
        var pid: pid_t = 0
        let argv = args.map { $0.withCString { strdup($0) } }
        defer { argv.forEach { free($0) } }
        
        var cargv = argv.map { UnsafeMutablePointer<CChar>?($0) }
        cargv.append(nil)
        
        let ret = posix_spawn(&pid, command, nil, nil, &cargv, nil)
        
        if ret == 0 {
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let exitCode = WEXITSTATUS(status)
            return (true, "✅ posix_spawn 成功 (PID: \(pid), 退出码: \(exitCode))")
        } else {
            let errorMsg = String(cString: strerror(ret))
            return (false, "❌ posix_spawn 失败: \(errorMsg) (errno: \(ret))")
        }
    }
    
    // MARK: - Test 3: Dynamic Library Loading
    
    func testDynamicLibrary() -> (Bool, String) {
        let libPaths = [
            "/usr/lib/libSystem.dylib",
            "/usr/lib/libobjc.A.dylib",
        ]
        
        var details: [String] = []
        var anySuccess = false
        
        for libPath in libPaths {
            if let handle = dlopen(libPath, RTLD_NOW) {
                details.append("✅ 成功加载: \(libPath)")
                dlclose(handle)
                anySuccess = true
            } else {
                if let err = dlerror() {
                    details.append("❌ 加载失败 \(libPath): \(String(cString: err))")
                } else {
                    details.append("❌ 加载失败 \(libPath): 未知错误")
                }
            }
        }
        
        return (anySuccess, details.joined(separator: "\n"))
    }
    
    // MARK: - Test 4: File Write
    
    func testFileWrite() -> (Bool, String) {
        let testDir = "/var/mobile/Documents/"
        let testFile = "/var/mobile/Documents/baize_test_\(Int(Date().timeIntervalSince1970)).txt"
        let testContent = "白泽测试 - file write OK"
        
        // First check if directory exists
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: testDir, isDirectory: &isDir) || !isDir.boolValue {
            return (false, "❌ 目录不存在或无权限: \(testDir)")
        }
        
        // Try to write
        do {
            try testContent.write(toFile: testFile, atomically: true, encoding: .utf8)
            
            // Verify
            if let readContent = try? String(contentsOfFile: testFile, encoding: .utf8),
               readContent == testContent {
                // Clean up
                try? fm.removeItem(atPath: testFile)
                return (true, "✅ 成功在 \(testDir) 创建并读取文件")
            } else {
                return (false, "❌ 文件写入成功但读取验证失败: \(testFile)")
            }
        } catch {
            return (false, "❌ 文件写入失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test 5: System Call
    
    func testSystemCall() -> (Bool, String) {
        // Use system() to execute a simple command
        let testCmd = "echo 'BAIZE_TEST_OK' > /tmp/baize_system_test.txt"
        let ret = system(testCmd)
        
        if ret == 0 {
            // Verify the file was created
            let outputPath = "/tmp/baize_system_test.txt"
            if let content = try? String(contentsOfFile: outputPath, encoding: .utf8) {
                // Clean up
                try? FileManager.default.removeItem(atPath: outputPath)
                return (true, "✅ system() 调用成功，输出: \(content.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                return (false, "⚠️ system() 返回成功但无法读取输出文件")
            }
        } else {
            return (false, "❌ system() 返回错误: \(ret)")
        }
    }
}

// MARK: - Test Result Card

struct TestResultCard: View {
    @Binding var result: TestResult
    var onRun: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.icon)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.headline)
                    Text(result.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onRun) {
                    Text(result.status == .running ? "运行中..." : "运行")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(result.status == .running ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(result.status == .running)
            }
            
            if !result.detail.isEmpty {
                Text(result.detail)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - C Function Declarations

func WEXITSTATUS(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xFF
}
