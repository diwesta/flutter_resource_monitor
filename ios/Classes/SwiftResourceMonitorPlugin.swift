import Flutter
import UIKit

public class SwiftResourceMonitorPlugin: NSObject, FlutterPlugin {
    public typealias MemoryUsage = (used: UInt64, total: UInt64)
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "resource_monitor", binaryMessenger: registrar.messenger())
        let instance = SwiftResourceMonitorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            if call.method == "getResourceUsage" {
                var dict: [String: Any] = [:]
                dict["cpuInUseByApp"] = try safeCpuInUseByApp()
                dict["memoryInUseByApp"] = try safeMemoryInUseByApp()
                result(dict)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "iOS could not recognize flutter call for: \(call.method)", details: nil))
            }
        } catch {
            result(FlutterError(code: "RESOURCE_MONITOR_ERROR", message: "Failed to retrieve resource usage: \(error.localizedDescription)", details: nil))
        }
    }
    
    // Safely fetch CPU usage
    public func safeCpuInUseByApp() throws -> Double {
        do {
            return try cpuInUseByApp()
        } catch {
            print("Error fetching CPU usage: \(error.localizedDescription)")
            return 0.0
        }
    }
    
    // Safely fetch Memory usage
    public func safeMemoryInUseByApp() throws -> Double {
        do {
            return try memoryInUseByApp()
        } catch {
            print("Error fetching Memory usage: \(error.localizedDescription)")
            return 0.0
        }
    }
    
    // CPU usage in use by app as a percentage (0-100)
    public func cpuInUseByApp() throws -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        guard threadsResult == KERN_SUCCESS, let threadsList = threadsList else {
            throw NSError(domain: "CPUUsageError", code: Int(threadsResult), userInfo: [NSLocalizedDescriptionKey: "Failed to fetch threads"])
        }
        
        for index in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            guard infoResult == KERN_SUCCESS else {
                continue
            }
            
            let threadBasicInfo = threadInfo
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }
    
    // Memory usage in use by app as a percentage (0-100)
    func memoryInUseByApp() throws -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            throw NSError(domain: "MemoryUsageError", code: Int(kerr), userInfo: [NSLocalizedDescriptionKey: "Failed to fetch memory info"])
        }
        
        let usedMemory = Double(taskInfo.resident_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let memoryUsagePercentage = (usedMemory / totalMemory) * 100.0
        return memoryUsagePercentage
    }
}
