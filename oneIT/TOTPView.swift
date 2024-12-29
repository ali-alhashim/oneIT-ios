import SwiftUI

// Request Model
struct VerificationRequest: Encodable {
    let totpCode: String
}

// Response Model
struct VerificationResponse: Decodable {
    let message: String
    let badgeNumber: String
    let name: String
}

struct TOTPView: View {
    let serverUrl: String
    let badgeNumber: String
    private let defaults = UserDefaults.standard
    
    @State private var totpCode = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var navigateToDashboard = false
    @State private var employeeName = ""
    @State private var employeeBadge = ""
    
    private let authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 25) {
                    Text("Enter Verification Code")
                        .font(.title2)
                        .padding(.top, 50)
                    
                    Text("Please enter the 6-digit code sent to your device.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextField("000000", text: $totpCode)
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: 200)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: totpCode) { newValue in
                            totpCode = newValue.filter { $0.isNumber }
                            if totpCode.count > 6 {
                                totpCode = String(totpCode.prefix(6))
                            }
                        }
                    
                    Button(action: verifyCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify Code")
                        }
                    }
                    .disabled(totpCode.count != 6 || isLoading)
                    .frame(width: 200, height: 44)
                    .background(totpCode.count == 6 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
                
                // iOS 15 Compatible Navigation
                NavigationLink(
                    destination: DashboardView(
                        name: employeeName,
                        badgeNumber: employeeBadge,
                        serverUrl: serverUrl
                    ),
                    isActive: $navigateToDashboard
                ) {
                    EmptyView()
                }
                .hidden()  // Hide NavigationLink from UI
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Verification Failed"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Verification Function
    func verifyCode() {
        print("verifyCode func called.....")
        guard let url = URL(string: "\(serverUrl)/api/verify-totp") else {
            alertMessage = "Invalid server URL"
            showAlert = true
            return
        }
        
        isLoading = true
        
        let verificationRequest = VerificationRequest(totpCode: totpCode)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Attach Session ID
        if let sessionId = authService.getSessionId() {
            print("Adding JSESSIONID to request: \(sessionId)")
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        } else {
            print("No session ID found")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(verificationRequest)
        } catch {
            alertMessage = "Error preparing request"
            showAlert = true
            isLoading = false
            return
        }
        
        // URLSession Configuration
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        let session = URLSession(configuration: configuration)
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    alertMessage = "Invalid server response"
                    showAlert = true
                    return
                }
                
                // Save Session ID if returned
                authService.saveSessionId(from: httpResponse, for: url)
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        if let rawResponse = String(data: data, encoding: .utf8) {
                            print("Raw Response: \(rawResponse)")
                        }
                        print("Response Headers: \(httpResponse.allHeaderFields)")
                        
                        do {
                            let decoder = JSONDecoder()
                            let jsonResponse = try decoder.decode(VerificationResponse.self, from: data)
                            
                            employeeBadge = jsonResponse.badgeNumber
                            employeeName = jsonResponse.name
                            
                            //save serverUrl
                            defaults.set(serverUrl, forKey: "serverUrl")
                            defaults.set(employeeBadge, forKey: "employeeBadge")
                            
                            navigateToDashboard = true
                            
                        } catch {
                            alertMessage = "Failed to decode response: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                case 401:
                    alertMessage = "Session expired. Please log in again."
                    authService.clearSession()
                    showAlert = true
                case 403:
                    alertMessage = "Invalid OTP code"
                    showAlert = true
                case 500:
                    alertMessage = "Server error. Please try again later."
                    showAlert = true
                default:
                    alertMessage = "Unexpected error (Status: \(httpResponse.statusCode))"
                    showAlert = true
                }
            }
        }.resume()
    }
}


