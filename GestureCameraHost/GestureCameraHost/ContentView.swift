import SwiftUI
import SystemExtensions

struct ContentView: View {
    // Keep a strong reference to prevent deallocation
    @State private var extensionDelegate = ExtensionActivationDelegate()

    var body: some View {
        VStack(spacing: 20) {
            Text("Gesture Camera Feasibility Check")
                .font(.headline)
            
            Button("Activate") {
                requestExtensionActivation()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 300, height: 200)
    }

    func requestExtensionActivation() {
        let extensionBundleID = "com.rajshreevermapersonalteam.GestureCameraHost"
        
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionBundleID, queue: .main)
        request.delegate = extensionDelegate
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

class ExtensionActivationDelegate: NSObject, OSSystemExtensionRequestDelegate {
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtension, withExtension replacement: OSSystemExtension) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        print("System extension requires user approval in System Settings.")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if result == .completed {
            print("System extension activated successfully.")
        } else {
            print("Activation finished with result: \(result.rawValue)")
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        print("Activation failed: \(error.localizedDescription)")
    }
}
