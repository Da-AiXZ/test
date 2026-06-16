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
        TestResult(name: "⚡ 自备二进制执行", 
                   description: "v2: 嵌入C程序→复制到/tmp/→chmod→posix_spawn执行"),
        TestResult(name: "🧬 dlopen 动态库执行", 
                   description: "v6: 嵌入.dylib→dlopen→dlsym调用（运行在App进程内）"),
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
                    
                    ForEach(testResults.indices, id: \.self) { i in
                        TestResultCard(result: $testResults[i]) {
                            DispatchQueue.global(qos: .userInitiated).async {
                                runTestSync(i)
                            }
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
        case 5: detail = testSelfContainedBinary()
        case 6: detail = testDylibExecution()
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
        
        var cargv: [UnsafeMutablePointer<CChar>?] = argv.map { UnsafeMutablePointer<CChar>($0) }
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
        // system() is unavailable on iOS; use posix_spawn with /bin/sh
        let testCmd = "/bin/sh"
        let testArg = "-c"
        let shellCmd = "echo BAIZE_TEST_OK > /tmp/baize_system_test.txt"
        let args = [testCmd, testArg, shellCmd]
        
        var pid: pid_t = 0
        let argv = args.map { $0.withCString { strdup($0) } }
        defer { argv.forEach { free($0) } }
        
        var cargv: [UnsafeMutablePointer<CChar>?] = argv.map { UnsafeMutablePointer<CChar>($0) }
        cargv.append(nil)
        
        let ret = posix_spawn(&pid, testCmd, nil, nil, &cargv, nil)
        
        if ret == 0 {
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let exitCode = WEXITSTATUS(status)
            
            // Verify the file was created
            let outputPath = "/tmp/baize_system_test.txt"
            if let content = try? String(contentsOfFile: outputPath, encoding: .utf8) {
                try? FileManager.default.removeItem(atPath: outputPath)
                return (true, "✅ Shell 执行成功 (exit: \(exitCode)), 输出: \(content.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                return (false, "⚠️ 进程创建成功但未生成输出文件 (exit: \(exitCode))")
            }
        } else {
            let errorMsg = String(cString: strerror(ret))
            return (false, "❌ Shell 执行失败: \(errorMsg) (errno: \(ret))")
        }
    }
    
    // MARK: - Test 6: Self-Contained Binary
    
    func testSelfContainedBinary() -> (Bool, String) {
        var details: [String] = []
        
        // Step 1: Find binary in bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            return (false, "❌ 无法获取 Bundle resource path")
        }
        let embeddedBinary = bundlePath + "/baize_v2"
        
        if !FileManager.default.fileExists(atPath: embeddedBinary) {
            return (false, "❌ 二进制未嵌入 App: \(embeddedBinary)")
        }
        details.append("📦 找到嵌入二进制")
        
        // Step 2: Copy to /tmp/
        let tmpBinary = "/tmp/baize_v2"
        try? FileManager.default.removeItem(atPath: tmpBinary)
        
        do {
            try FileManager.default.copyItem(atPath: embeddedBinary, toPath: tmpBinary)
            details.append("📋 复制成功")
        } catch {
            return (false, "❌ 复制二进制失败: \(error.localizedDescription)")
        }
        
        // Step 3: chmod +x
        if chmod(tmpBinary, 0o755) != 0 {
            let err = String(cString: strerror(errno))
            return (false, "❌ chmod +x 失败: \(err)")
        }
        details.append("🔑 chmod 755 成功")
        
        // Step 4: posix_spawn (no pipe - v5 uses exit code only)
        let args = [tmpBinary]
        var pid: pid_t = 0
        
        let argv = args.map { $0.withCString { strdup($0) } }
        defer { argv.forEach { free($0) } }
        
        var cargv: [UnsafeMutablePointer<CChar>?] = argv.map { UnsafeMutablePointer<CChar>($0) }
        cargv.append(nil)
        
        let spawnRet = posix_spawn(&pid, tmpBinary, nil, nil, &cargv, nil)
        
        if spawnRet != 0 {
            let err = String(cString: strerror(spawnRet))
            return (false, "❌ posix_spawn 失败: \(err) (errno: \(spawnRet))")
        }
        
        // Step 5: Wait for process
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let rawExit = WEXITSTATUS(status)
        let fullStatus = status
        
        // Check HOW the process ended
        if WIFSIGNALED(status) {
            let sig = WTERMSIG(status)
            let sigName: String
            switch sig {
            case 9:  sigName = "SIGKILL"     // ⚠️ 被系统强制杀死
            case 6:  sigName = "SIGABRT"
            case 11: sigName = "SIGSEGV"
            case 4:  sigName = "SIGILL"
            case 5:  sigName = "SIGTRAP"
            default: sigName = "SIGNAL(\(sig))"
            }
            details.append("💀 子进程被信号杀死: \(sigName) (sig=\(sig), full_status=\(fullStatus))")
            details.append("   这表示 iOS 系统阻止了未签名二进制执行！")
        } else if WIFEXITED(status) {
            let exitCode = Int(rawExit)
            details.append("🟢 子进程正常退出 (PID: \(pid), exit=\(exitCode))")
            
            // Decode exit code (v5 bitmask)
            if exitCode == 0 {
                details.append("🔴 exit=0 → 所有测试都失败了")
            } else {
                details.append("--- 位掩码解码 ---")
                if exitCode & 1  != 0 { details.append("  ✅ bit0: /tmp/ 可写") }
                else                 { details.append("  ❌ bit0: /tmp/ 不可写") }
                if exitCode & 2  != 0 { details.append("  ✅ bit1: /var/mobile/Documents/ 可写") }
                else                 { details.append("  ❌ bit1: /var/mobile/Documents/ 不可写") }
                if exitCode & 4  != 0 { details.append("  ✅ bit2: /private/tmp/ 可写") }
                else                 { details.append("  ❌ bit2: /private/tmp/ 不可写") }
                if exitCode & 8  != 0 { details.append("  ✅ bit3: access(W_OK) 通过") }
                else                 { details.append("  ❌ bit3: access(W_OK) 失败") }
                if exitCode & 16 != 0 { details.append("  ✅ bit4: mkdir 成功") }
                else                 { details.append("  ❌ bit4: mkdir 失败") }
                if exitCode & 32 != 0 { details.append("  ✅ bit5: getcwd 成功") }
                else                 { details.append("  ❌ bit5: getcwd 失败") }
                if exitCode & 64 != 0 { details.append("  ✅ bit6: 程序运行到末尾") }
                else                 { details.append("  ❌ bit6: 程序未运行到末尾") }
            }
        } else {
            details.append("⚠️ 子进程状态异常: \(fullStatus)")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: tmpBinary)
        
        // For posix_spawn: "success" = process was NOT killed by signal
        let success = WIFEXITED(status) && WEXITSTATUS(status) != 0
        return (success, details.joined(separator: "\n"))
    }
    
    // MARK: - Test 7: dlopen Dynamic Library
    
    func testDylibExecution() -> (Bool, String) {
        var details: [String] = []
        
        // Step 1: Find dylib in bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            return (false, "❌ 无法获取 Bundle resource path")
        }
        let dylibPath = bundlePath + "/libbaize_v2.dylib"
        
        if !FileManager.default.fileExists(atPath: dylibPath) {
            return (false, "❌ .dylib 未嵌入 App: \(String(dylibPath.suffix(35)))")
        }
        details.append("📦 找到 .dylib: \(String(dylibPath.suffix(30)))")
        
        // Step 2: Copy to /tmp/
        let tmpDylib = "/tmp/libbaize_v2.dylib"
        try? FileManager.default.removeItem(atPath: tmpDylib)
        
        do {
            try FileManager.default.copyItem(atPath: dylibPath, toPath: tmpDylib)
            details.append("📋 复制到 /tmp/ 成功")
        } catch {
            return (false, "❌ 复制 .dylib 失败: \(error.localizedDescription)")
        }
        
        // Step 3: dlopen
        guard let handle = dlopen(tmpDylib, RTLD_NOW) else {
            let err = dlerror().map { String(cString: $0) } ?? "未知错误"
            try? FileManager.default.removeItem(atPath: tmpDylib)
            return (false, "❌ dlopen 失败: \(err)")
        }
        details.append("🔓 dlopen 成功")
        defer { dlclose(handle) }
        
        // Step 4: dlsym → baize_v2_test()
        guard let sym = dlsym(handle, "baize_v2_test") else {
            let err = dlerror().map { String(cString: $0) } ?? "符号未找到"
            return (false, "❌ dlsym('baize_v2_test') 失败: \(err)")
        }
        details.append("🔍 dlsym 成功 → 函数指针: \(sym)")
        
        // Step 5: Call the function
        typealias TestFunc = @convention(c) () -> Int32
        let testFunc = unsafeBitCast(sym, to: TestFunc.self)
        let result = testFunc()
        details.append("🟢 baize_v2_test() 返回: \(result)")
        
        // Step 6: Decode result (same bitmask as v5)
        if result == 0 {
            details.append("🔴 result=0 → 所有测试都失败了")
        } else {
            if result & 1  != 0 { details.append("  ✅ /tmp/ 可写") }
            else               { details.append("  ❌ /tmp/ 不可写") }
            if result & 2  != 0 { details.append("  ✅ /var/mobile/Documents/ 可写") }
            else               { details.append("  ❌ /var/mobile/Documents/ 不可写") }
            if result & 4  != 0 { details.append("  ✅ /private/tmp/ 可写") }
            else               { details.append("  ❌ /private/tmp/ 不可写") }
            if result & 8  != 0 { details.append("  ✅ access(W_OK) 通过") }
            else               { details.append("  ❌ access(W_OK) 失败") }
            if result & 16 != 0 { details.append("  ✅ mkdir 成功") }
            else               { details.append("  ❌ mkdir 失败") }
            if result & 32 != 0 { details.append("  ✅ getcwd 成功") }
            else               { details.append("  ❌ getcwd 失败") }
            if result & 64 != 0 { details.append("  ✅ 函数运行到末尾") }
            else               { details.append("  ❌ 函数未运行到末尾") }
        }
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: tmpDylib)
        
        let success = (result & 64) != 0
        return (success, details.joined(separator: "\n"))
    }
}

// MARK: - Test Result Card

struct TestResultCard: View {
    @Binding var result: TestResult
    var onRun: () -> Void
    
    var body: some View {
        let r = result
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(r.status.icon)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name)
                        .font(.headline)
                    Text(r.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onRun) {
                    Text(r.status == .running ? "运行中..." : "运行")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(r.status == .running ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(r.status == .running)
            }
            
            if !r.detail.isEmpty {
                Text(r.detail)
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

func WIFEXITED(_ status: Int32) -> Bool {
    return (status & 0x7F) == 0
}

func WIFSIGNALED(_ status: Int32) -> Bool {
    return ((status & 0x7F) + 1) >> 1 > 0
}

func WEXITSTATUS(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xFF
}

func WTERMSIG(_ status: Int32) -> Int32 {
    return status & 0x7F
}
