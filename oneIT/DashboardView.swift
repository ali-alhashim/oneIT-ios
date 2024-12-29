import SwiftUI
import CoreLocation
import LocalAuthentication



import NetworkExtension
import Network

class VPNStatusChecker {
    static func isVPNConnected() async -> Bool {
        let vpnInterfaces = ["utun", "ppp", "ipsec", "tap", "tun"]
        
        let monitor = NWPathMonitor()
        let path = monitor.currentPath
        
        let isConnected = path.availableInterfaces.contains { interface in
            vpnInterfaces.contains { vpnInterface in
                interface.name.lowercased().contains(vpnInterface)
            }
        }
        
        return isConnected
    }
}


struct DashboardView: View {
    let name: String
    let badgeNumber: String
    let serverUrl: String
    
    @StateObject private var locationManager = LocationManager()
    @State private var lastLocation: CLLocation?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var navigateToTimesheet = false
    @State private var timesheetData: [TimesheetData] = []
    
    private let authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Profile Section
                        VStack(spacing: 15) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(name.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.blue)
                                )
                            
                            VStack(spacing: 8) {
                                Text("Welcome, \(name)!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Badge: \(badgeNumber)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Action Cards
                        VStack(spacing: 16) {
                            // Check-in Card
                            ActionCard(
                                title: "Check-in",
                                icon: "location.circle.fill",
                                color: .green,
                                action: requestCheckIn
                            )
                            
                            // Check-out Card
                            ActionCard(
                                title: "Check-out",
                                icon: "location.circle",
                                color: .orange,
                                action: requestCheckOut
                            )
                            
                            // Timesheet Card
                            ActionCard(
                                title: "View Timesheet",
                                icon: "calendar",
                                color: .blue,
                                action: openTimesheet
                            )
                        }
                        .padding(.horizontal)
                        
                        // Logout Button
                        Button(action: logoutRequest) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
                            }
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 30)
                }
                
                // Hidden Navigation Link
                NavigationLink(
                    destination: TimesheetView(timesheetData: timesheetData),
                    isActive: $navigateToTimesheet
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onReceive(locationManager.$lastLocation) { location in
                if let location = location {
                    lastLocation = location
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarBackButtonHidden(true)
    }
    
    //MARK: - auth bio
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            showAlert(title: "Biometrics Unavailable", message: error?.localizedDescription ?? "Your device does not support Face ID / Touch ID.")
            return false
        }
        
        let reason = "Authenticate to Check-In or Check-Out"
        
        // Perform authentication asynchronously
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        continuation.resume(returning: true)
                    } else {
                        showAlert(title: "Authentication Failed", message: authenticationError?.localizedDescription ?? "Failed to authenticate.")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Button Actions
    
    func requestCheckIn() {
        guard let location = lastLocation else {
            showAlert(title: "Location Not Available", message: "Please enable location services to check in.")
            return
        }
        checkIn(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    func requestCheckOut() {
        guard let location = lastLocation else {
            showAlert(title: "Location Not Available", message: "Please enable location services to check out.")
            return
        }
        checkOut(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    // MARK: - Timesheet Handling
    
    func openTimesheet() {
        guard let url = URL(string: "\(serverUrl)/api/timesheet") else {
            showAlert(title: "Error", message: "Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let sessionId = authService.getSessionId() {
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    showAlert(title: "Error", message: "Failed to fetch timesheet.")
                    return
                }
                
                do {
                    let decodedData = try JSONDecoder().decode([TimesheetData].self, from: data)
                    self.timesheetData = decodedData
                    self.navigateToTimesheet = true
                } catch {
                    print("Decoding Error: \(error)")
                    showAlert(title: "Error", message: "Failed to decode response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Logout Handling
    
    func logoutRequest() {
        guard let url = URL(string: "\(serverUrl)/api/logout") else {
            showAlert(title: "Error", message: "Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let sessionId = authService.getSessionId() {
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    showAlert(title: "Network Error", message: error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    showAlert(title: "Error", message: "Invalid server response")
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    showAlert(title: "Logged Out", message: "You have been logged out successfully.")
                    authService.clearSession()
                    navigateToLogin()
                case 401:
                    showAlert(title: "Session Expired", message: "Please log in again.")
                    authService.clearSession()
                    navigateToLogin()
                default:
                    let responseMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unexpected error occurred"
                    showAlert(title: "Error", message: responseMessage)
                }
            }
        }.resume()
    }
    
    func navigateToLogin() {
        UserDefaults.standard.removeObject(forKey: "JSESSIONID")
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController = UIHostingController(rootView: LoginView())
            scene.windows.first?.makeKeyAndVisible()
        }
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    // MARK: - API Calls
    
    func checkIn(latitude: Double, longitude: Double) {
        sendCheckRequest(endpoint: "/api/checkIn", latitude: latitude, longitude: longitude)
    }
    
    func checkOut(latitude: Double, longitude: Double) {
        sendCheckRequest(endpoint: "/api/checkOut", latitude: latitude, longitude: longitude)
    }
    
    func sendCheckRequest(endpoint: String, latitude: Double, longitude: Double) {
            Task {
                // 1. First check VPN status
                let isVPNConnected = await VPNStatusChecker.isVPNConnected()
                guard !isVPNConnected else {
                    showAlert(title: "Error", message: "VPN Not Allowed - Please disconnect")
                    return
                }
                
                // 2. Then perform biometric authentication
                let isAuthenticated = await authenticateWithBiometrics()
                guard isAuthenticated else {
                    return // Alert is already shown in authenticateWithBiometrics
                }
                
                // 3. If both checks pass, proceed with the check-in/out request
                await performCheckRequest(endpoint: endpoint, latitude: latitude, longitude: longitude)
            }
        }
    
    
    
    // MARK: - API Request Implementation
        private func performCheckRequest(endpoint: String, latitude: Double, longitude: Double) async {
            let payload: [String: Any] = [
                "badgeNumber": badgeNumber,
                "latitude": latitude,
                "longitude": longitude,
                "mobileModel": UIDevice.current.model,
                "mobileOS": UIDevice.current.systemVersion
            ]
            
            guard let url = URL(string: "\(serverUrl)\(endpoint)") else {
                showAlert(title: "Error", message: "Invalid URL configuration")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let sessionId = authService.getSessionId() {
                request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
            }
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                showAlert(title: "Error", message: "Failed to prepare request")
                return
            }
            
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieAcceptPolicy = .always
            configuration.httpShouldSetCookies = true
            let session = URLSession(configuration: configuration)
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    showAlert(title: "Error", message: "Invalid server response")
                    return
                }
                
                authService.saveSessionId(from: httpResponse, for: url)
                
                if let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = responseDict["message"] as? String {
                    
                    switch httpResponse.statusCode {
                    case 200:
                        showAlert(title: "Success", message: message)
                    case 401:
                        authService.clearSession()
                        showAlert(title: "Session Expired", message: message)
                    case 400:
                        showAlert(title: "Error", message: message)
                    case 500:
                        showAlert(title: "Server Error", message: "Please try again later")
                    default:
                        showAlert(title: "Error", message: "Unexpected error occurred")
                    }
                }
            } catch {
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
}

// MARK: - Supporting Views

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    @Published var lastLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
}
