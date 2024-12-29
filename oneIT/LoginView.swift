import SwiftUI

struct LoginView: View {
    @State private var serverUrl = "http://localhost:8080"
    @State private var badgeNumber = "A"
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showTOTP = false
    
    private let authService = AuthService.shared
    private let defaults = UserDefaults.standard
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Your existing view code remains the same
                Text("Login")
                    .font(.largeTitle)
                    .padding()
                
                TextField("Server URL", text: $serverUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                TextField("Badge Number", text: $badgeNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: loginTapped) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Login")
                    }
                }
                .disabled(isLoading)
                .foregroundColor(.white)
                .frame(width: 200, height: 40)
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(8)
                .padding()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Login"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $showTOTP) {
                TOTPView(serverUrl: serverUrl, badgeNumber: badgeNumber)
            }
            .onAppear {
                // Clear any existing session when showing login
                authService.clearSession()
                
                if let savedBadge = defaults.string(forKey: "employeeBadge"),
                                   let savedUrl = defaults.string(forKey: "serverUrl") {
                                    badgeNumber = savedBadge
                                    serverUrl = savedUrl
                                }
            }
        }
        
      
        
    } //end view
    
    func loginTapped() {
        guard let url = URL(string: "\(serverUrl)/api/login") else {
            alertMessage = "Invalid server URL"
            showAlert = true
            return
        }

        isLoading = true

        let loginRequest = LoginRequest(
            badgeNumber: badgeNumber,
            password: password
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add existing session if available
        if let sessionId = authService.getSessionId() {
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }

        do {
            request.httpBody = try JSONEncoder().encode(loginRequest)
        } catch {
            alertMessage = "Error preparing request"
            showAlert = true
            isLoading = false
            return
        }

        // Create URLSession with cookie handling
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

                // Save session ID from response
                authService.saveSessionId(from: httpResponse, for: url)

                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        // Print raw response data for debugging
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Raw response: \(responseString)")
                        }

                        // Print cookies and headers for debugging
                        print("Response Headers: \(httpResponse.allHeaderFields)")
                        if let sessionId = authService.getSessionId() {
                            print("Saved Session ID: \(sessionId)")
                        }

                        // Decode the response
                        if let response = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                            if response.message == "Login successful" {
                                UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
                                UserDefaults.standard.set(badgeNumber, forKey: "badgeNumber")
                                showTOTP = true
                            } else {
                                alertMessage = "Unexpected response: \(response.message ?? "No message")"
                                showAlert = true
                            }
                        } else {
                            alertMessage = "Failed to decode response"
                            showAlert = true
                        }
                    }
                case 401:
                    alertMessage = "Invalid credentials"
                    showAlert = true
                case 500:
                    alertMessage = "Server error"
                    showAlert = true
                default:
                    alertMessage = "Unexpected error (Status: \(httpResponse.statusCode))"
                    showAlert = true
                }
            }
        }.resume()
    }
}
